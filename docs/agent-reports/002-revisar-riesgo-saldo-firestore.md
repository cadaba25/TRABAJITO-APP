---
id: 002
tarea: docs/agent-tasks/002-revisar-riesgo-saldo-firestore.md
agente: security-agent
fecha: 2026-08-19
---

## Objetivo (copiado de la tarea)

`firestore.rules` permite a cualquier usuario autenticado escribir el campo
`saldo` (y otras métricas) de OTRO usuario, vía la función `soloMetricas()`.
El propio archivo admite que es "solo para el prototipo de cartera". Nadie
había evaluado el alcance real del riesgo ni decidido qué hacer.

## Cambios realizados

1. Auditoría completa de todo el código que lee/escribe `saldo` y las demás
   métricas cubiertas por `soloMetricas()` (`calificacionPromedio`,
   `totalCalificaciones`, `trabajosCompletados`, `trabajosPublicados`,
   `pagosConfirmados`): `firestore.rules`, `lib/services/
   publicacion_service.dart`, `lib/services/calificacion_service.dart`,
   `lib/services/cartera_service.dart`, `lib/screens/cartera_screen.dart`,
   `lib/screens/detalle_trabajo_screen.dart`, `lib/models/usuario.dart`,
   `lib/services/auth_service.dart` (para descartar otros consumidores),
   más un grep de todo `lib/` para confirmar que no hay otros escritores.
2. Separé el riesgo teórico del explotable: la escritura del "dueño" sobre
   su propio `saldo` (sin restricción de campos) NO agrega capacidad nueva
   hoy porque `CarteraService.recargarSaldo()` ya permite auto-recargarse
   cualquier monto sin pasarela de pago real (la cartera es un prototipo
   admitido como tal en la propia UI). El riesgo nuevo y grave que sí
   introduce `soloMetricas()` es que un TERCERO sin relación real con la
   víctima puede reducir su `saldo` a 0, o fijar sus métricas de reputación
   a valores arbitrarios, con un solo write directo a Firestore (no
   requiere pasar por la app — la config del proyecto Firebase es pública
   por diseño, la protección depende 100% de las reglas).
3. Documenté el análisis completo, la mitigación implementada, lo que se
   dejó fuera y por qué, como ADR-0004 en `docs/decisions.md`.
4. Implementé la mitigación de bajo riesgo en `firestore.rules`:
   `soloMetricas()` ahora exige que, si `saldo` está entre los campos
   modificados, el nuevo valor sea `>=` al anterior (un tercero ya no puede
   reducir el saldo de otro usuario). Verificado por lectura exhaustiva
   (no por ejecución — ver "Tests ejecutados") que ningún flujo legítimo
   actual necesita que un tercero reduzca el saldo ajeno.
5. Dejé explícitamente fuera de esta tarea, con la justificación
   correspondiente, el endurecimiento de los campos de reputación y la
   verificación de relación real entre las partes, porque `calificacionPromedio`
   legítimamente puede bajar (una calificación de 1 estrella) y validar eso
   bien requiere reglas más complejas que no se pueden verificar sin tests
   de emulador de Firestore, que no existen en este repo. Creé
   `docs/agent-tasks/004-endurecer-metricas-terceros-firestore.md` para ese
   trabajo, a coordinar con `flutter-agent`.
6. Actualicé `docs/database.md` y `docs/agent-context/repo-snapshot.md`
   para que dejen de describir el riesgo como "sin resolver" sin matices —
   ahora reflejan que está mitigado parcialmente y qué queda abierto.

## Archivos modificados

- `firestore.rules` — endurecimiento acotado de `soloMetricas()` (ver
  sección siguiente, justificación de por qué se tocó en esta misma tarea).
- `docs/decisions.md` — nuevo ADR-0004.
- `docs/agent-tasks/002-revisar-riesgo-saldo-firestore.md` — estado
  `hecho`, notas del agente llenadas.
- `docs/agent-tasks/004-endurecer-metricas-terceros-firestore.md` — nueva
  tarea (trabajo diferido, fuera de alcance de esta tarea).
- `docs/agent-context/repo-snapshot.md` — actualizado el estado del riesgo.
- `docs/database.md` — actualizada la sección que documentaba el riesgo.
- `docs/agent-reports/002-revisar-riesgo-saldo-firestore.md` — este reporte.

## Decisiones tomadas

**Sí toqué `firestore.rules` en esta misma tarea**, algo que la tarea
condicionaba explícitamente a que el cambio fuera "de bajo riesgo y acotado
a `firestore.rules`" y que no pudiera romper el flujo de
calificación/pago/asignación que depende de que terceros actualicen esas
métricas. Evalué que el cambio implementado cumple esa condición porque:

- Es aditivo y de una sola dirección: solo agrega una restricción nueva
  (`saldo` de un tercero no puede bajar), no cambia ningún comportamiento
  que las reglas ya permitían de forma distinta.
- Leí los 5 sitios de código que escriben `saldo` de un tercero
  (`aceptarTrabajo`, `reembolsar`, `cancelarContratacion` en
  `publicacion_service.dart`; no hay más — confirmado con grep en todo
  `lib/`) y los 4 sitios que escriben `saldo` propio (self, vía la rama de
  "dueño" que no usa `soloMetricas()` y por tanto no se ve afectada por
  este cambio). En los tres flujos de terceros, `saldo` **siempre se
  incrementa**, nunca se reduce — el cambio no rompe ninguno.
- **Deliberadamente NO toqué** los campos de reputación en la misma
  función, precisamente porque ahí SÍ encontré un caso legítimo que rompe
  cualquier restricción simple de "solo incrementa" (`calificacionPromedio`
  baja con una calificación mala) — ahí sí seguí la instrucción de no
  implementar en solitario y lo dejé como tarea 004.

## Problemas encontrados

- No hay Firebase CLI instalado en este entorno ni `firebase.json` en el
  repo, así que no existe forma de correr el emulador de Firestore ni
  `firebase deploy --only firestore:rules --dry-run` para validar
  sintácticamente el cambio. Es una limitación real, documentada en el ADR
  y abajo en "Tests ejecutados" — no afirmo que el cambio "compila" sin
  haberlo verificado.
- `reembolsar()` en `publicacion_service.dart` no tiene ningún llamador
  encontrado en `lib/screens/` (grep de `reembolsar(` solo encuentra la
  definición y una coincidencia parcial de nombre en `cancelarContratacion`).
  Puede ser código no conectado a la UI todavía o una función pensada para
  un flujo de disputa que no se investigó más a fondo por estar fuera del
  alcance de esta tarea — lo dejo anotado por si es relevante para otra
  tarea.

## Tests ejecutados

Ninguno automatizado — no aplica un test de Flutter/backend a este cambio
(es un archivo de reglas de Firestore, sin infraestructura de test en este
repo). Verificación hecha por lectura exhaustiva del código consumidor
(detallada arriba), NO por ejecución. Explícitamente no se pudo:

- Validar la sintaxis de `firestore.rules` con `firebase` CLI (no
  instalado, sin `firebase.json`).
- Correr tests de reglas con el emulador de Firestore (no existen en este
  repo — es justamente el prerrequisito que deja pendiente la tarea 004).

Recomendación explícita para quien despliegue este cambio a un proyecto
Firebase real: validar primero con `firebase deploy --only firestore:rules
--dry-run` o el emulador antes de aplicarlo a producción.

## Pendientes

- Tarea `docs/agent-tasks/004-endurecer-metricas-terceros-firestore.md`:
  verificación de relación real entre quien escribe y el usuario objetivo,
  límites en campos de reputación, evaluar mover `saldo` a subcolección
  propia. Requiere primero instalar/configurar el emulador de Firestore +
  tests de reglas en este repo (no existen hoy).
- Investigar si `reembolsar()` en `publicacion_service.dart` está
  realmente sin usar (código muerto) o falta conectarlo a la UI — no se
  investigó por estar fuera de alcance.
- El riesgo de que el "dueño" pueda escribir su propio `saldo` sin límite
  (rama `request.auth.uid == uid` de `allow update`, sin restricción de
  campos) queda documentado en ADR-0004 como equivalente en la práctica a
  la falta de pasarela de pago real — no se actuó sobre él en esta tarea,
  pero debe revisarse junto con ADR-0002 (migración a backend) el día que
  `saldo` represente dinero real.
