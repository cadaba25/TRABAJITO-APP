---
id: 010
titulo: "El empleador puede cancelar después de la entrega y recuperar el escrow"
estado: todo   # todo | en-progreso | en-revision | hecho | bloqueada
agente: "backend-agent"
creada: 2026-08-21
rama: ""
---

## Objetivo

`POST /api/trabajos/{id}/cancelar` **no valida el estado del trabajo**: solo
comprueba que el pago no esté ya liberado. El empleador puede cancelar cuando
el trabajador ya entregó (`ESPERANDO_CONFIRMACION`), recuperar el 100% del
pago en garantía y quedarse con el trabajo hecho. El trabajador no tiene
ningún recurso: no hay disputa, ni bloqueo, ni notificación.

Verificado contra el servidor real (tarea 006):

```
Empleador recarga 400 -> reserva 400 en escrow -> el trabajador inicia y
marca TERMINADO (estado = ESPERANDO_CONFIRMACION, entregado = true)

POST /api/trabajos/{id}/cancelar   (empleador)
-> HTTP 200
   {"estado":"ACTIVO","montoAcordado":0,"pagoRetenido":false,"pagoLiberado":false}

saldo del empleador : 400.00  (reembolso integro)
saldo del trabajador:   0.00
trabajos.trabajador_asignado_id : NULL   (se borra el vinculo)
```

`TrabajoService.reabrir()` además deja el trabajo `ACTIVO` y limpia
`entregado`/`montoAcordado`, así que la publicación vuelve al feed como si
nunca hubiera pasado nada — pero la postulación del trabajador **sigue en
estado `ACEPTADA`** en la tabla `postulaciones` (comprobado también tras una
cancelación en `ACORDADO`). El trabajo queda en un estado incoherente:
`ACTIVO` sin asignado, con una postulación `ACEPTADA` colgando.

El reembolso en sí funciona bien cuando la cancelación es legítima (antes de
empezar): reserva de 200 → saldo 0.00 → cancelar → saldo 200.00, con las
filas `RETENCION` y `REEMBOLSO` correctas. Cancelar dos veces no reembolsa dos
veces. Lo que falta es **cuándo** se permite cancelar.

Esto no es un fallo técnico sino un hueco de reglas de negocio, y por eso
necesita una decisión antes de código: ¿desde qué estado puede cancelar el
empleador? ¿qué pasa con el trabajo ya empezado? ¿hace falta un estado
`EN_DISPUTA`?

## Contexto relevante

- `backend/src/main/java/com/trabajito/modules/trabajos/TrabajoService.java`
  — `cancelarContratacion()` y `reabrir()`.
- `backend/src/main/java/com/trabajito/common/enums/EstadoTrabajo.java` — la
  máquina de estados documentada; `cancelar` la esquiva por completo (y el
  estado `CANCELADO` del enum **no se usa nunca**: `reabrir()` deja `ACTIVO`).
- `docs/architecture.md` y `docs/ROADMAP.md` — comprobar si ya hay algo
  decidido sobre disputas antes de inventar reglas nuevas.
- `docs/agent-reports/006-flujos-negocio-contra-postgres.md`

## Criterios de aceptación

- [ ] Decidido y escrito (ADR corto en `docs/decisions.md` o sección en
      `docs/architecture.md`) desde qué estados puede cancelar el empleador y
      qué pasa con el escrow en cada uno. Esta decisión es del `tech-lead` +
      usuario: afecta a lo que la app promete a los trabajadores.
- [ ] Cancelar en `ESPERANDO_CONFIRMACION` deja de devolver 200 con reembolso
      automático (409, o un flujo de disputa explícito).
- [ ] Al cancelar, las postulaciones asociadas quedan en un estado coherente
      (no una `ACEPTADA` sobre un trabajo `ACTIVO` sin asignado).
- [ ] Decidir si una cancelación debe dejar el trabajo en `CANCELADO` en lugar
      de reciclarlo a `ACTIVO` (hoy se pierde el historial del contrato roto:
      `montoAcordado` se pone a 0 y el asignado se borra).
- [ ] `bash backend/scripts/prueba-flujo-negocio.sh` deja de reportar
      `BUG-010`.

## Notas del agente que la ejecuta

Relacionado pero **fuera** de esta tarea: `rechazarAsignacion()` (el
trabajador rechaza) sí valida que no haya escrow y devuelve 409 con un mensaje
correcto. Es el modelo a seguir para el lado del empleador.
