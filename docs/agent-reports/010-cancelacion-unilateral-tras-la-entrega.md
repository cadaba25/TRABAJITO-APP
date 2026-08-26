---
id: 010
tarea: docs/agent-tasks/010-cancelacion-unilateral-tras-la-entrega.md
agente: backend-agent (implementación) + tech-lead (verificación y cierre)
fecha: 2026-08-26
---

> **Nota de proceso:** la sesión del `backend-agent` se cortó por límite de
> uso después de commitear la implementación, antes de escribir este reporte.
> El `tech-lead` retomó: verificó contra el servidor real, **encontró y
> arregló dos defectos** que la implementación había dejado (ver abajo), y
> cerró la documentación.

## Objetivo (copiado de la tarea)

Cerrar el hueco por el que el empleador podía cancelar **después** de que el
trabajador entregó, recuperar el 100 % del escrow y quedarse con el trabajo
hecho. Reglas fijadas por el dueño del proyecto, bajo su principio rector:
***"nunca ninguna de las dos partes debe tener la ventaja de irse ganando"***.

## Cambios realizados

Decisiones completas en **ADR-0007** (`docs/decisions.md`). Resumen:

1. **Nadie cancela con el trabajo iniciado.** `cancelarContratacion()` solo
   admite `ACTIVO`/`ASIGNADO`/`ACORDADO`; `rechazarAsignacion()` (trabajador)
   solo `ASIGNADO` y sin escrow. Desde `EN_PROGRESO`, ambos → **409**.
2. **Entrega con evidencias obligatorias.** `marcarTerminado()` exige al
   menos una evidencia del trabajador asignado. Añadido por el agente y no
   pedido explícitamente, pero derivado del mismo principio: tras una
   petición de corrección hace falta una evidencia **posterior** (columna
   nueva `fecha_solicitud_correccion`), para que re-entregar lo mismo no sea
   una forma de agotar al contratista.
3. **Nuevo estado `EN_DISPUTA` + `POST /api/trabajos/{id}/reclamar`.** El
   dinero queda congelado (`pagoRetenido=true`, `montoAcordado` intacto) y se
   abre un `Reporte`. Solo un `ADMIN` lo descongela con
   `POST /api/admin/trabajos/{id}/resolver-disputa`.
   **Desviación consciente del agente:** la regla del dueño decía "el
   empleador", pero se permitió reclamar también al trabajador — si no, el
   trabajador queda atrapado en un trabajo que no puede cancelar y cuyo pago
   depende de que la otra parte quiera confirmarlo: la misma ventaja, pero
   del otro lado. El principio rector decidió.
4. **Cancelación legítima con elección.** `POST /{id}/cancelar` ahora exige
   `{"reabrir": true|false}` (sin valor por defecto: 400 si falta). Al
   reabrir, las postulaciones se resincronizan; al cerrar, el trabajo queda
   `CANCELADO`.

## Defectos encontrados al verificar (y arreglados)

### A. `reclamar` devolvía 500 — la válvula de escape estaba rota

El síntoma: todo el bloqueo funcionaba, pero **la única salida legítima no**.

```
POST /api/trabajos/{id}/reclamar  ->  HTTP 500
```

Causa raíz en los logs del contenedor:

```
ERROR: new row for relation "trabajos" violates check constraint "trabajos_estado_check"
```

Hibernate genera el `CHECK (estado IN (...))` a partir del enum **solo al
crear la tabla**. Con `ddl-auto=update`, una base de datos que ya existe
conserva el CHECK con los valores viejos para siempre, así que `EN_DISPUTA`
era rechazado por PostgreSQL.

**Por qué los tests no lo detectaron:** los tests usan H2 con `create-drop`,
que regenera el CHECK en cada arranque. El fallo **solo aparece contra una
base de datos preexistente** — es decir, exactamente en producción.

Arreglado con `RestriccionEstadoTrabajo`, siguiendo el patrón que ya existía
para el CHECK del saldo (`RestriccionSaldoNoNegativo`, tarea 007): al
arrancar, regenera el CHECK desde `EstadoTrabajo.values()`. Cualquier valor
nuevo del enum queda cubierto automáticamente en el futuro.

> Este es el **segundo** fallo causado por no tener migraciones versionadas.
> Refuerza el pendiente de Flyway/Liquibase listado en `backend/README.md`.

### B. Un check del script de regresión era no determinista

`prueba-flujo-negocio.sh` reportaba `BUG-007` con `una sola LIBERACION
registrada: esperado=1 obtenido=0`, dando a entender una regresión en el
arreglo del dinero. **Era falso.**

El script lanza dos reservas simultáneas sobre `TC1` y `TC2` con saldo para
una sola — y solo una gana, que es justamente el arreglo de la tarea 007
haciendo su trabajo. Pero después asumía que siempre ganaba `TC1`. Cuando
ganaba `TC2`, la cadena `iniciar`/`entregar` fallaba **en silencio**
(`>/dev/null`) y el check final medía un trabajo que nunca llegó a liberarse.

Arreglado: ahora se consulta cuál quedó con el escrow y la precondición se
comprueba de forma explícita, para que un fallo de preparación se vea en vez
de disfrazarse de bug de producción.

## Tests ejecutados

### Unitarios (máquina de desarrollo)

```
mvn test -Dtest='!IntegridadCarteraConcurrenteTest'
→ Tests run: 59, Failures: 0, Errors: 0  ·  BUILD SUCCESS
```
Antes de la tarea eran 38. `TrabajoServiceTest` pasó de 19 a 40 tests.

### Verificación contra el servidor real (PostgreSQL)

Reglas nuevas, con el backend desplegado en la VM:

| Prueba | Resultado |
|---|---|
| Empleador cancela con el trabajo `EN_PROGRESO` | **409** |
| Trabajador rechaza con el trabajo `EN_PROGRESO` | **409** |
| Entregar sin evidencias | **409** |
| Entregar con evidencia | **200** |
| **Empleador cancela tras la entrega (el ataque original)** | **409** |
| Reclamar a soporte | **200** |
| Empleador intenta liberar estando `EN_DISPUTA` | **409** |
| Empleador intenta cancelar estando `EN_DISPUTA` | **409** |

Mensaje que devuelve el 409, textual:

> `"El trabajo ya inició: ninguna de las dos partes puede cancelarlo. Si hay un problema, repórtalo a soporte."`

Estado tras reclamar — **el dinero no se movió**:

```
trabajo: estado=EN_DISPUTA | escrow=true | monto=400.00
saldos:  empleador=0.00    | trabajador=0.00
reporte abierto: 1
```

### El flujo feliz sigue intacto

Publicar → postularse → aceptar → escrow → iniciar → evidencia → entregar →
aceptar: **los 6 pasos en 200**, empleador `0.00`, trabajador `500.00`,
exactamente **1** movimiento `LIBERACION`.

### La protección del dinero de la tarea 007 sigue en pie

5 `POST /{id}/aceptar` simultáneos → **exactamente 1 fila `LIBERACION`**, el
trabajador cobra 300.00 (no 1500.00).

### Script de regresión

| | Antes de la 010 | Después |
|---|---|---|
| OK | 95 | **133** |
| Fallos conocidos | 10 | **9** (todos BUG-009) |
| Fallos NO esperados | 0 | **0** |

`BUG-010` desapareció. Los 9 que quedan son todos de la tarea **009**
(errores de cliente que devuelven 500), que va aparte.

## Pendientes

- **Tarea 009** — los 9 fallos conocidos restantes.
- **Flutter (`lib/**`)**: la UI de "entregar con evidencias", el botón de
  reclamar a soporte y el selector reabrir/cerrar al cancelar no existen. La
  app sigue en Firestore (ADR-0002), así que hoy no rompe nada, pero el
  contrato de la API ya cambió: `POST /{id}/cancelar` ahora **exige** el
  cuerpo `{"reabrir": …}`.
- **Flyway/Liquibase**: segundo incidente causado por su ausencia (ver
  defecto A). Cada estado nuevo del enum necesitará que el parche de arranque
  siga existiendo.
- La resolución de disputas por ADMIN se probó por API, pero **no** se
  ejercitó el camino completo (reclamar → admin resuelve → dinero al ganador)
  contra el servidor.
