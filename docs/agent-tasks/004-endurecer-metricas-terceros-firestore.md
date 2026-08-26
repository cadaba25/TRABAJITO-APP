---
id: 004
titulo: "Endurecer soloMetricas() en firestore.rules: relación real + límites de reputación"
estado: todo   # todo | en-progreso | en-revision | hecho | bloqueada
agente: security-agent   # coordinar con flutter-agent antes de tocar reglas
creada: 2026-08-19
rama: ""
---

## Objetivo

`docs/decisions.md` ADR-0004 implementó una mitigación parcial en
`firestore.rules`: un tercero ya no puede reducir el `saldo` de otro
usuario vía `soloMetricas()`. Quedó explícitamente fuera de esa tarea (por
riesgo de romper el flujo real de calificación/pago) lo siguiente, que esta
tarea debe cubrir:

1. Verificar que quien escribe métricas de un tercero (`calificacionPromedio`,
   `totalCalificaciones`, `trabajosCompletados`, `trabajosPublicados`,
   `pagosConfirmados`, `saldo`) tenga una relación real con el usuario
   objetivo (ej. ambos son parte de la misma `publicacion`, en el estado
   correcto) — hoy `soloMetricas()` no lo verifica, cualquier usuario
   autenticado puede escribir esos campos de cualquier otro usuario sin
   relación alguna.
2. Acotar `calificacionPromedio` a `[0, 5]` y correlacionar el incremento de
   `totalCalificaciones` con la calificación real que se está creando en la
   misma transacción (hoy un tercero puede fijar ambos campos a cualquier
   valor arbitrario, incluso sin crear una `calificacion` real).
3. Acotar `trabajosCompletados`, `trabajosPublicados` y `pagosConfirmados` a
   incrementos de exactamente 1 por escritura (hoy se puede fijar a
   cualquier valor en una sola llamada).
4. Evaluar mover `saldo` fuera del documento de `usuarios` a una subcolección
   propia (ej. `usuarios/{uid}/cartera/actual`) con reglas más estrictas y
   más fácil de auditar en aislamiento, en vez de compartir reglas con
   campos de reputación.

## Contexto relevante

`docs/decisions.md` ADR-0004 (análisis completo del riesgo y por qué se
difirió este trabajo). `firestore.rules` función `soloMetricas()`.
`lib/services/publicacion_service.dart` (`aceptarTrabajo`, `reembolsar`,
`cancelarContratacion`, `crearPublicacion`, `marcarCompletado`) y
`lib/services/calificacion_service.dart` (`calificar`) — son los únicos
consumidores reales hoy de las escrituras de terceros a `usuarios`.

## Módulos afectados y orden de trabajo

Toca `firestore.rules` (dominio de `flutter-agent`/`security-agent` según
`.claude/agents/`) y potencialmente el modelo de datos de `usuarios` en
Flutter si se decide mover `saldo` a subcolección (dominio `flutter-agent`).
Debe planificarse con `tech-lead` si se opta por el cambio de modelo de
datos (punto 4) porque afecta más de un módulo (reglas + modelo Dart +
todos los servicios que leen/escriben `saldo`).

**Prerrequisito antes de tocar reglas de nuevo:** este repo no tiene hoy
Firebase CLI instalado ni `firebase.json`/configuración de emulador, ni
tests de reglas (`@firebase/rules-unit-testing`). Instalar y configurar eso
es parte de esta tarea (o de una tarea previa de `devops-agent`) — no se
debe modificar `soloMetricas()` de nuevo "a ciegas" como ya se hizo una vez
en la tarea 002 (justificado ahí solo porque el cambio era mínimo y se
verificó por lectura exhaustiva de todo el código consumidor).

## Criterios de aceptación

- [ ] Existe un entorno de test de reglas (emulador de Firestore +
      `@firebase/rules-unit-testing` o equivalente) corriendo en este repo.
- [ ] `soloMetricas()` verifica relación real entre quien escribe y el
      usuario objetivo antes de permitir el write.
- [ ] `calificacionPromedio` está acotado a `[0, 5]`; `totalCalificaciones`,
      `trabajosCompletados`, `trabajosPublicados`, `pagosConfirmados` solo
      pueden incrementar de a 1 por escritura.
- [ ] Se evaluó (con decisión documentada, aunque sea "no ahora") mover
      `saldo` a una subcolección separada.
- [ ] Los flujos existentes de pago/calificación/asignación siguen
      funcionando (verificado con los tests de reglas nuevos, no solo
      leyendo el código).

## Notas del agente que la ejecuta

(vacío — tarea aún no iniciada)
