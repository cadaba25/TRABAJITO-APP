---
id: 002
titulo: "Revisar el riesgo de escritura de 'saldo' en firestore.rules"
estado: todo
agente: security-agent
creada: 2026-08-19
rama: ""
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

- [ ] Se documenta el alcance real del riesgo (qué puede hacer un atacante
      autenticado hoy, con ejemplos concretos).
- [ ] Se propone al menos una mitigación viable a corto plazo (sin esperar a
      la migración al backend) y se compara con "esperar a ADR-0002".
- [ ] La recomendación final queda como ADR en `docs/decisions.md`.

## Notas del agente que la ejecuta

(vacío — tarea aún no iniciada)
