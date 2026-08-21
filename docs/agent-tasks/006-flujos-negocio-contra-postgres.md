---
id: 006
titulo: "Probar los flujos de negocio completos contra PostgreSQL real"
estado: en-progreso
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

- [ ] El flujo feliz completo (pasos 1–10) ejecutado de punta a punta contra
      el backend real corriendo en el servidor, con dos usuarios distintos
      (un empleador y un trabajador). Respuestas reales pegadas en el reporte.
- [ ] **El dinero cuadra**: verificar con números concretos que el saldo del
      empleador baja al reservar, que el del trabajador sube al liberarse, y
      que `GET /api/cartera/movimientos` refleja los movimientos. Un flujo
      que devuelve 200 pero deja el dinero mal es un fallo, no un éxito.
- [ ] Al menos 3 casos borde probados contra la BD real, priorizando dinero.
      Sugeridos (usa tu criterio, y añade los que se te ocurran):
      reservar pago con saldo insuficiente; aceptar dos veces la misma
      postulación; cancelar un trabajo con el escrow ya liberado; postularse
      dos veces al mismo trabajo; un tercero sin relación con el trabajo
      intentando aceptarlo/liberarlo (autorización).
- [ ] Cada fallo encontrado queda documentado con: request exacto, respuesta
      real, y qué se esperaba. **No los arregles en esta tarea** salvo que
      sean triviales y estén claramente dentro del backend — el objetivo es
      diagnosticar. Si hay fallos de fondo, créales tarea nueva.
- [ ] Si automatizas el flujo como script, déjalo versionado en el repo
      (por ejemplo `backend/scripts/`), no solo pegado en el reporte.

## Fuera de alcance

- Cambios en `lib/**` (Flutter). ADR-0002 sigue abierto.
- Refresh tokens, rate limiting, Flyway, Redis, FCM: son pendientes
  conocidos y cada uno merece su propia tarea.
- WebSocket/chat en tiempo real: probarlo bien requiere un cliente STOMP;
  si te sobra tiempo, anota qué haría falta, pero no es el objetivo.

## Notas del agente que la ejecuta

(vacío — tarea en progreso)
