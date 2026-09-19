# 059 - Chat: pago como monto total (backend)
Decision del dueño (2026-09-18): el pago es un monto TOTAL, no por hora.
- `ChatService`: mensajes "Propuesta de pago: L. X en total" y "Pago acordado: L. X en total" (antes "/ hora"); javadoc actualizado. `Propuesta.precio`: comentario "monto total". Sin cambios de campos ni JSON.
- `docs/api.md` y reporte 055: pregunta de producto marcada RESUELTA 2026-09-18.
- Tests: ninguno asertaba el texto "hora"; no requirieron cambio. `mvn test` (JDK temurin-24, flags indicados): surefire reporta 147 run, 0 fallos, 0 errores; el fork JVM emitio "Surefire is going to kill self fork JVM" al cierre (ruido de entorno, ya conocido).
