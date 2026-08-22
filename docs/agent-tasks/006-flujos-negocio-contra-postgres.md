---
id: 006
titulo: "Probar los flujos de negocio completos contra PostgreSQL real"
estado: hecho
agente: qa-agent
creada: 2026-08-21
rama: "test/flujos-negocio-contra-postgres"
---

## Objetivo

La tarea 005 dejó el backend corriendo en el servidor Ubuntu y validó que
**arranca y que la autenticación funciona** (registro/login/JWT → 200). Pero
**los flujos de negocio nunca se han ejercitado contra PostgreSQL real**:
publicar trabajo → postularse → aceptar postulación → reservar pago (escrow)
→ iniciar → terminar → aceptar y liberar el pago → calificar.

Esto importa ahora y no después porque es el insumo que falta para decidir
la migración de Flutter (ADR-0002). Si el escrow o la máquina de estados
fallan contra una BD real, es mucho más barato descubrirlo antes de
reescribir el cliente que después.

Los 22 tests que ya existen (tarea 003) son **unitarios con Mockito**: no
tocan base de datos. Prueban la lógica en aislamiento, no la integración
real (transacciones, constraints, concurrencia, serialización JSON).

## Contexto relevante

- `docs/agent-reports/005-backend-en-servidor-ubuntu.md` — cómo quedó el
  servidor y qué se probó exactamente.
- `docs/development.md` sección "Levantar el backend en un servidor".
- `docs/api.md` y `backend/README.md` — mapa de endpoints.
- `docs/agent-reports/003-tests-base-backend.md` — la decisión de estrategia
  de testing vigente (Mockito para lógica, H2 solo para contexto). Esta
  tarea es justo el caso que ahí se dejó abierto: "si en el futuro se
  necesita probar queries JPA reales, evaluar Testcontainers en ese momento".

### Endpoints que componen el flujo (verificados en el código)

| Paso | Endpoint |
|---|---|
| 1. Publicar | `POST /api/trabajos` |
| 2. Postularse | `POST /api/postulaciones` |
| 3. Ver postulantes | `GET /api/postulaciones?trabajoId=` |
| 4. Aceptar postulación | `POST /api/postulaciones/{id}/aceptar` |
| 5. Recargar cartera | `POST /api/cartera/recargar` |
| 6. Reservar pago (escrow) | `POST /api/trabajos/{id}/reservar-pago` |
| 7. Iniciar | `POST /api/trabajos/{id}/iniciar` |
| 8. Terminar | `POST /api/trabajos/{id}/terminar` |
| 9. Aceptar y liberar pago | `POST /api/trabajos/{id}/aceptar` |
| 10. Calificar | `POST /api/calificaciones` |
| — Ver movimientos | `GET /api/cartera/movimientos` |

## Criterios de aceptación

- [x] El flujo feliz completo (pasos 1–10) ejecutado de punta a punta contra
      el backend real corriendo en el servidor, con dos usuarios distintos
      (un empleador y un trabajador). Respuestas reales pegadas en el reporte.
- [x] **El dinero cuadra**: verificar con números concretos que el saldo del
      empleador baja al reservar, que el del trabajador sube al liberarse, y
      que `GET /api/cartera/movimientos` refleja los movimientos. Un flujo
      que devuelve 200 pero deja el dinero mal es un fallo, no un éxito.
- [x] Al menos 3 casos borde probados contra la BD real, priorizando dinero.
      Sugeridos (usa tu criterio, y añade los que se te ocurran):
      reservar pago con saldo insuficiente; aceptar dos veces la misma
      postulación; cancelar un trabajo con el escrow ya liberado; postularse
      dos veces al mismo trabajo; un tercero sin relación con el trabajo
      intentando aceptarlo/liberarlo (autorización).
- [x] Cada fallo encontrado queda documentado con: request exacto, respuesta
      real, y qué se esperaba. **No los arregles en esta tarea** salvo que
      sean triviales y estén claramente dentro del backend — el objetivo es
      diagnosticar. Si hay fallos de fondo, créales tarea nueva.
- [x] Si automatizas el flujo como script, déjalo versionado en el repo
      (por ejemplo `backend/scripts/`), no solo pegado en el reporte.

## Fuera de alcance

- Cambios en `lib/**` (Flutter). ADR-0002 sigue abierto.
- Refresh tokens, rate limiting, Flyway, Redis, FCM: son pendientes
  conocidos y cada uno merece su propia tarea.
- WebSocket/chat en tiempo real: probarlo bien requiere un cliente STOMP;
  si te sobra tiempo, anota qué haría falta, pero no es el objetivo.

## Notas del agente que la ejecuta

Hecha 2026-08-21. Reporte completo con respuestas reales y contabilidad:
`docs/agent-reports/006-flujos-negocio-contra-postgres.md`.

**Resultado corto:** el flujo feliz 1-10 funciona de punta a punta contra
PostgreSQL real y el dinero cuadra al céntimo **si las peticiones llegan de
una en una**. Con concurrencia o entradas raras se rompe. 4 fallos, ninguno
arreglado aquí (era tarea de diagnóstico), cada uno con tarea nueva:

- **007 (crítica)** — se puede crear dinero de la nada: un empleador recarga
  L. 1000 y acaba pagando L. 2000 a dos trabajadores (dos `reservar-pago`
  simultáneos, ambos 200). Lost update en `PagoService` + `movimientos_cartera`
  descuadrado respecto a `usuarios.saldo`. También: 5 toques simultáneos a
  `/aceptar` escriben 4 filas `LIBERACION`. Y `monto=0.005` le cobra 0.00 al
  empleador y le paga 0.01 al trabajador.
- **008 (crítica)** — `POST /api/auth/registro` acepta `"rol":"ADMIN"`. Con
  esa cuenta se entró a `/api/admin/estadisticas` (200) y se suspendió la
  cuenta de otro usuario (200).
- **010 (alta)** — el empleador puede cancelar cuando el trabajador ya
  entregó: recupera el escrow completo, el trabajador se queda sin nada.
- **009 (media)** — 11 errores de cliente devuelven 500 y el handler genérico
  no loguea nada (`docker compose logs api` vacío tras provocarlos).

Lo que quedó sólido: la máquina de estados secuencial, las 9 comprobaciones de
autorización probadas (todas 403), escrow con saldo insuficiente, reembolso
por cancelación temprana, y las calificaciones con su promedio.

Automatizado en `backend/scripts/prueba-flujo-negocio.sh` (102
comprobaciones; 80 OK, 22 marcadas como fallo conocido, 0 inesperadas). Sale
con código 1 solo si aparece un fallo NUEVO, así que sirve ya como test de
regresión.

No probado: WebSocket/chat (fuera de alcance), subida de archivos, el resto
del panel admin, expiración del JWT. Detalle en el reporte.
