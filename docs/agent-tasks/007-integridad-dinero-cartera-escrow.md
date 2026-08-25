---
id: 007
titulo: "Integridad del dinero: race condition en cartera/escrow y redondeo sub-centavo"
estado: hecho
agente: "backend-agent"
creada: 2026-08-21
rama: "fix/integridad-dinero-escrow"
---

## Objetivo

**Hoy el backend permite crear dinero de la nada.** Verificado contra
PostgreSQL real en el servidor (tarea 006, ver
`docs/agent-reports/006-flujos-negocio-contra-postgres.md`): un empleador que
recarga **L. 1000** puede terminar pagando **L. 2000** a dos trabajadores.
Además el libro de movimientos (`movimientos_cartera`) deja de cuadrar con
`usuarios.saldo`, así que ni siquiera queda auditoría de lo ocurrido.

Esto bloquea cualquier decisión sobre migrar la app a este backend
(ADR-0002): no se puede poner dinero real encima de esto.

Son dos defectos con la misma raíz —el dinero se calcula leyendo y
reescribiendo un campo sin ninguna protección— y conviene arreglarlos juntos
porque comparten el mismo test.

### Defecto A — lost update / doble gasto (crítico)

`PagoService.recargar/retener/liberar/reembolsar` hacen
`u.setSaldo(u.getSaldo() ± monto)` sobre una entidad leída en la misma
transacción, **sin bloqueo pesimista, sin `@Version` optimista y sin
`UPDATE ... SET saldo = saldo ± ?` atómico**. `TrabajoService.reservarPago` y
`TrabajoService.aceptar` comprueban las banderas `pagoRetenido`/`pagoLiberado`
en memoria, que tampoco protegen frente a dos transacciones simultáneas en
`READ COMMITTED` (el aislamiento por defecto de PostgreSQL).

Reproducciones reales (todas con `curl` contra el servidor, ver el reporte):

1. **Doble gasto entre dos trabajos.** Empleador con saldo 1000.00, dos
   trabajos en estado `ASIGNADO`, dos `POST /api/trabajos/{id}/reservar-pago`
   con `{"monto":1000}` lanzados en paralelo → **ambos 200**. Saldo final
   `0.00`, pero los **dos** trabajos quedan con `pago_retenido=t` y
   `monto_acordado=1000.00`. Al completar los dos flujos normalmente, los dos
   trabajadores cobran 1000 cada uno: entró L. 1000 al sistema y salieron
   L. 2000.
2. **Doble toque en el mismo trabajo.** 5 × `reservar-pago` en paralelo →
   `200 200 409 409 409`, pero quedan **2 filas `RETENCION` de -1000** y el
   saldo solo bajó 1000.
3. **Doble toque al liberar.** 5 × `POST /api/trabajos/{id}/aceptar` en
   paralelo → **los 5 devuelven 200**, se escriben **4 filas `LIBERACION`**
   (4000 en el libro) mientras el saldo del trabajador solo sube 1000, y
   `pagos_confirmados` del empleador se incrementa 2 veces.
4. **El libro deja de cuadrar.** `usuarios.saldo` vs
   `SUM(movimientos_cartera.monto)`: empleador +1000.00 de diferencia,
   trabajador -3000.00.

El guardia `if (t.isPagoLiberado()) return t;` **sí** funciona en secuencial
(segundo `aceptar` posterior → 200 idempotente sin mover dinero); el problema
es exclusivamente concurrente. Es la misma clase de bug que el histórico de
"botones que se quedaban cargando por multi-toque": el cliente hace doble
submit y el servidor lo cobra dos veces.

### Defecto B — redondeo sub-centavo crea dinero (medio)

`usuarios.saldo` y `movimientos_cartera.monto` son `numeric(12,2)`, pero
nada valida la escala del monto recibido.

```
POST /api/trabajos/{id}/reservar-pago  {"monto":0.005}   -> 200
saldo del empleador antes:  100.00
saldo del empleador despues:100.00      <- no se le cobro NADA (100 - 0.005 -> 100.00)
trabajos.monto_acordado:      0.01      <- pero se guardo redondeado hacia arriba
... completar el flujo ...
saldo del trabajador:        +0.01      <- cobra un centavo que nadie pago
```

Es poco dinero por operación pero no tiene tope: se repite en bucle. Y rompe
el mismo invariante contable del defecto A.

## Contexto relevante

- `docs/agent-reports/006-flujos-negocio-contra-postgres.md` — respuestas
  reales y contabilidad paso a paso.
- `backend/scripts/prueba-flujo-negocio.sh` — reproduce los 4 casos; las
  comprobaciones están marcadas `BUG-007` y hoy salen en amarillo.
- `backend/src/main/java/com/trabajito/modules/pagos/PagoService.java`
- `backend/src/main/java/com/trabajito/modules/trabajos/TrabajoService.java`
  (`reservarPago`, `aceptar`, `cancelarContratacion`)
- `docs/database.md` — tablas `usuarios` y `movimientos_cartera`.

## Criterios de aceptación

- [ ] Dos `reservar-pago` simultáneos de L. 1000 con saldo L. 1000 dejan uno
      en 200 y otro en 400 "Saldo insuficiente". Nunca los dos en 200.
- [ ] N `POST /api/trabajos/{id}/aceptar` simultáneos generan **exactamente
      una** fila `LIBERACION` y **un** incremento de `trabajos_completados` /
      `pagos_confirmados`.
- [ ] El invariante `usuarios.saldo == SUM(movimientos_cartera.monto)` se
      mantiene después de cualquier combinación de peticiones concurrentes.
      Consulta de verificación en el reporte de la tarea 006.
- [ ] `saldo` nunca puede quedar negativo (añadir el CHECK en la BD además de
      la validación en Java: la defensa en el código no basta si el bug es de
      concurrencia).
- [ ] Un monto con más de 2 decimales se rechaza con 400 (o se normaliza
      explícitamente ANTES de tocar saldo y `monto_acordado`, con la misma
      escala en los dos sitios).
- [ ] Test automatizado que falle **sin** el arreglo. Los tests con Mockito de
      la tarea 003 no pueden detectar esto (no hay BD ni transacciones); hace
      falta una prueba de integración real — es el caso que el reporte 003
      dejó anotado para "evaluar Testcontainers cuando haga falta". Ha hecho
      falta.
- [ ] `bash backend/scripts/prueba-flujo-negocio.sh` deja de reportar
      `BUG-007` (y ninguna comprobación pasa a FALLA).

## Notas del agente que la ejecuta

Pistas de implementación (no son órdenes, el diseño es de quien lo haga):

- Lo más directo y barato: `SELECT ... FOR UPDATE` sobre la fila de
  `usuarios` (`@Lock(LockModeType.PESSIMISTIC_WRITE)` en el repositorio) y
  sobre `trabajos` dentro de las transacciones que mueven dinero. Ojo con el
  orden de bloqueo para no crear deadlocks.
- Alternativa: `@Version` en `BaseEntity` (afecta a TODAS las entidades) y
  reintentos. Es un cambio más invasivo; conviene un ADR.
- Un `UPDATE usuarios SET saldo = saldo - :monto WHERE id = :id AND saldo >= :monto`
  con comprobación de filas afectadas resuelve el débito de forma atómica sin
  bloquear, pero hay que rehacer también el registro del movimiento (hoy el
  `saldoResultante` se calcula en Java).
- Sea cual sea la vía elegida, el `CHECK (saldo >= 0)` en la BD es la última
  línea de defensa y debería estar igual.

## Resultado (cerrado 2026-08-21)

Se eligió **bloqueo pesimista con orden global de bloqueo** (trabajos →
usuarios, y varios usuarios en orden ascendente de UUID), más `@DynamicUpdate`
en `Usuario`, `CHECK (saldo >= 0)` en la BD y validación de escala exacta de
los montos. Razonamiento completo y alternativas descartadas en **ADR-0006**;
evidencia en `docs/agent-reports/007-integridad-dinero-cartera-escrow.md`.

Verificado contra el servidor real: el ataque de dos `reservar-pago`
simultáneos con saldo para uno solo pasó de **200 + 200** (dinero creado de la
nada) a **200 + 400**, con un solo escrow retenido. El script de regresión
pasó de 86 OK / 19 fallos conocidos a **95 OK / 10 fallos conocidos / 0
inesperados**, y el cuadre contable (`saldo == SUM(movimientos_cartera.monto)`)
ahora pasa para los 7 usuarios de prueba (antes fallaba en todos).

**Criterio del test automatizado: cumplido el 2026-08-25.**
`IntegridadCarteraConcurrenteTest` pasa **6/6** con el arreglo y **falla 6/6
sin él** (verificado ejecutando el mismo test contra el código de `df53b51`),
con fallos del tipo `Expected size: 1 but was: 5` en las reservas y
liberaciones simultáneas. Requirió subir Testcontainers a **1.21.4**: la
versión 1.20.6 seguía negociando API 1.32 y los Docker Engine modernos exigen
1.44. Detalle en el reporte.
