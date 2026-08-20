---
id: 002
titulo: "Revisar el riesgo de escritura de 'saldo' en firestore.rules"
estado: hecho
agente: security-agent
creada: 2026-08-19
rama: "security/revisar-riesgo-saldo-firestore"
---

## Objetivo

`firestore.rules` permite a cualquier usuario autenticado escribir el campo
`saldo` (y otras métricas) de OTRO usuario, vía la función `soloMetricas()`.
El propio archivo trae un comentario admitiendo que es "solo para el
prototipo de cartera" y que en producción los movimientos de dinero deben
manejarse en un backend seguro. Nadie ha evaluado el alcance real del riesgo
ni decidido qué hacer al respecto.

## Contexto relevante

`docs/database.md` sección 1, subsección "Riesgo de seguridad ya
documentado en el propio `firestore.rules`". `firestore.rules` función
`soloMetricas()`. `lib/services/cartera_service.dart` (cómo se usa `saldo`
hoy desde Flutter).

## Módulos afectados y orden de trabajo

Es una tarea de análisis primero, no de implementación directa — el
resultado debe ser una recomendación (¿restringir más las reglas? ¿mover
`saldo` a un subcampo no escribible por terceros? ¿esperar a la migración al
backend con `MovimientoCartera` como ledger, ver ADR-0002?) documentada como
un ADR nuevo en `docs/decisions.md` antes de tocar `firestore.rules`. Si la
recomendación es cambiar las reglas ahora, coordinar con `flutter-agent`
porque puede romper el flujo actual de calificación/pago que depende de que
terceros puedan actualizar esas métricas.

## Criterios de aceptación

- [x] Se documenta el alcance real del riesgo (qué puede hacer un atacante
      autenticado hoy, con ejemplos concretos).
- [x] Se propone al menos una mitigación viable a corto plazo (sin esperar a
      la migración al backend) y se compara con "esperar a ADR-0002".
- [x] La recomendación final queda como ADR en `docs/decisions.md`.

## Notas del agente que la ejecuta

Análisis completo en `docs/decisions.md` ADR-0004 (no se repite aquí — ver
ese documento para el detalle línea por línea del código auditado).

**Resumen del hallazgo real:** el riesgo explotable de verdad no es que un
usuario infle su propio `saldo` (eso ya es posible hoy sin tocar reglas,
vía `CarteraService.recargarSaldo()`, porque la cartera es un prototipo sin
pasarela de pago real). El riesgo nuevo y grave que sí introduce
`soloMetricas()` es que **cualquier usuario autenticado puede, con un solo
write directo a Firestore (sin pasar por la app), reducir a 0 el `saldo` de
CUALQUIER otro usuario, o fijar sus campos de reputación
(`calificacionPromedio`, `totalCalificaciones`, `trabajosCompletados`,
`trabajosPublicados`, `pagosConfirmados`) a valores arbitrarios**, sin que
exista ninguna relación real (trabajo compartido) entre atacante y víctima.

**Qué se implementó ya (bajo riesgo, verificado por lectura exhaustiva de
todo el código que escribe estos campos):** `soloMetricas()` en
`firestore.rules` ahora exige que, si `saldo` está entre los campos
modificados, el nuevo valor sea `>=` al anterior. Se confirmó que ningún
flujo legítimo hoy (`aceptarTrabajo`, `reembolsar`, `cancelarContratacion`
en `lib/services/publicacion_service.dart`) necesita que un tercero reduzca
el saldo ajeno — todos son incrementos. Esto cierra el vector de sabotaje
más grave y de menor esfuerzo.

**Qué se dejó fuera, a propósito, y por qué:** no se acotaron los campos de
reputación ni se agregó verificación de relación real entre las partes,
porque `calificacionPromedio` legítimamente puede bajar (una calificación
de 1 estrella) y validar eso correctamente requiere reglas más complejas
que no se pueden verificar sin tests de emulador de Firestore (que no
existen en este repo). Siguiendo la instrucción explícita de la tarea de no
implementar en solitario un cambio que pueda romper el flujo de
calificación/pago, se creó `docs/agent-tasks/
004-endurecer-metricas-terceros-firestore.md` para ese trabajo, coordinado
con `flutter-agent`.

**Limitación explícita:** no se pudo validar el cambio de `firestore.rules`
con el emulador de Firebase (CLI no instalado, no hay `firebase.json` en el
repo) — verificado solo por lectura del código consumidor, no por
ejecución. Ver ADR-0004 y tarea 004.
