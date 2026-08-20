# Decisiones de arquitectura (ADR)

Registro corto de decisiones importantes. Formato: contexto → decisión →
consecuencias. Un ADR nuevo por decisión, nunca se edita uno viejo salvo para
marcarlo `Reemplazado por ADR-000X`. Cualquier agente puede proponer un ADR;
`tech-lead` lo confirma antes de que se actúe sobre él.

---

## ADR-0001 — Adoptar la rama `claude/blissful-meitner-wt9tek` como base de `master`

**Fecha:** 2026-08-19
**Estado:** Aceptado

**Contexto:** `master` tenía un solo commit ("App base"). Existía una rama
remota, `claude/blissful-meitner-wt9tek`, generada por la GitHub Action
`@claude` (`.github/workflows/claude.yml`) entre el 18-jun-2026 y el
16-jul-2026 — 32 commits nunca fusionados, con casi todo el MVP de Flutter
(registro completo, feed de trabajos, postulaciones, chat, calificaciones,
cartera/escrow) y un esqueleto completo de backend Spring Boot +
PostgreSQL + JWT. El dueño del proyecto no tenía presente esta rama.

**Decisión:** Fast-forward de `master` a esa rama (sin reescribir historia,
sin conflictos posibles porque `master` era ancestro directo). Confirmado
explícitamente por el usuario antes de ejecutarlo.

**Consecuencias:**
- El punto de partida real del proyecto es mucho más avanzado de lo que
  parecía. Todos los documentos de este sistema (`docs/*.md`,
  `.claude/agents/*.md`) se escribieron sobre este estado, no sobre "App
  base".
- Ese mes de trabajo se generó de forma autónoma, respondiendo a comentarios
  `@claude` en issues/PRs, sin un proceso de revisión humana documentado.
  No se ha hecho una auditoría de calidad/seguridad de esos 32 commits como
  parte de esta tarea — es candidato a una tarea temprana de `qa-agent` +
  `security-agent` (ver `docs/agent-tasks/`).
- `test/widget_test.dart` quedó roto (referencia una clase `MyApp` que ya no
  existe) — ver `docs/development.md`.

---

## ADR-0002 — Firebase vs. backend propio: decisión de migración NO tomada

**Fecha:** 2026-08-19
**Estado:** Abierto — no decidido

**Contexto:** El dueño del proyecto describió como stack objetivo Flutter +
Spring Boot + PostgreSQL + Redis + JWT + Docker. El repo real corre hoy
100% sobre Firebase (Auth + Firestore) desde el cliente Flutter, y por
separado tiene un esqueleto de backend Spring Boot completo pero
**desconectado** — ningún endpoint es consumido por la app.

**Decisión:** Ninguna todavía. Este documento existe para que ningún agente
asuma que la migración a Spring Boot está aprobada o en marcha. Migrar
significa, como mínimo: reescribir cada `*_service.dart` de Flutter para
hablar HTTP en vez del SDK de Firestore, decidir qué pasa con
`firestore.rules` y los datos ya existentes en Firestore, y resolver las
diferencias de modelado ya detectadas en `docs/database.md` (por ejemplo,
`saldo` embebido vs. ledger `MovimientoCartera`).

**Consecuencias mientras esté abierto:**
- `backend-agent` puede seguir completando el esqueleto (tests, pendientes
  listados en `backend/README.md`) porque no depende de esta decisión.
- Ningún agente debe empezar a cablear Flutter contra `/api/**` como tarea
  "de paso" dentro de otra tarea. Si se decide migrar, debe ser una tarea
  explícita planificada por `tech-lead` con el usuario, no una iniciativa
  espontánea de un agente.

---

## ADR-0003 — Sistema de agentes: 7 roles, no 10

**Fecha:** 2026-08-19
**Estado:** Aceptado

**Contexto:** La propuesta original consideraba hasta 10 agentes, incluyendo
Database, UI/UX y Code Review como roles independientes.

**Decisión:** Se combinan así (detalle y justificación completa en el
informe entregado al usuario, resumen aquí):
- **Database** se cubre desde `backend-agent` hasta que exista Flyway/Liquibase
  o el volumen de tablas lo justifique (condición explícita en
  `docs/architecture.md`, sección "Cuándo separar un Database Agent dedicado").
- **UI/UX** se cubre desde `flutter-agent` — es la única plataforma cliente
  que existe; un agente de UI/UX separado no tendría con quién coordinar
  consistencia "entre plataformas" porque solo hay una.
- **Code Review** no es un agente de Claude Code nuevo — se usa el skill ya
  instalado `code-review` (invocable como `/code-review`) más la revisión que
  ya hace `tech-lead` antes de aprobar un PR. Crear un agente aparte hubiera
  duplicado esa función.

**Consecuencias:** 7 agentes: `tech-lead`, `flutter-agent`, `backend-agent`,
`security-agent`, `qa-agent`, `devops-agent`, `docs-agent`. Si el proyecto
crece lo suficiente como para justificar separar alguno de los roles
combinados, debe documentarse como un nuevo ADR, no como un cambio silencioso.

---

## ADR-0004 — Riesgo de `soloMetricas()` en `firestore.rules`: mitigación parcial ahora, endurecimiento completo pendiente

**Fecha:** 2026-08-19
**Estado:** Aceptado (mitigación parcial implementada); endurecimiento
completo queda abierto como tarea nueva.

**Contexto:** `firestore.rules` define `soloMetricas()`, una función que
permite a CUALQUIER usuario autenticado escribir en el documento de OTRO
usuario los campos `calificacionPromedio`, `totalCalificaciones`,
`trabajosCompletados`, `trabajosPublicados`, `pagosConfirmados` y `saldo`,
sin verificar que exista una relación real (una publicación compartida)
entre quien escribe y el usuario objetivo, y sin restringir el valor ni la
dirección del cambio. El propio archivo ya admitía esto como "solo para el
prototipo de cartera".

Se auditó el código real que produce estos writes (`lib/services/
publicacion_service.dart`, `lib/services/calificacion_service.dart`,
`lib/services/cartera_service.dart`, `lib/screens/cartera_screen.dart`,
`lib/screens/detalle_trabajo_screen.dart`) para separar el riesgo teórico
del explotable:

1. **La regla de "dueño" (`request.auth.uid == uid`) ya es, por sí sola, un
   riesgo aparte y más amplio que `soloMetricas()`:** un usuario puede
   escribir CUALQUIER campo de su propio documento sin validación alguna
   (incluido `saldo`), porque `allow update` no restringe campos cuando
   `request.auth.uid == uid`. En la práctica esto **no agrega capacidad
   nueva** hoy: `CarteraService.recargarSaldo()` ya permite a cualquier
   usuario incrementar su propio `saldo` en cualquier monto sin pasarela de
   pago real (`lib/screens/cartera_screen.dart` lo etiqueta explícitamente
   como "Prototipo: los pagos son simulados"). Es decir, el dinero en `saldo`
   ya es de facto "moneda de prototipo, no dinero real" — el riesgo real de
   negocio aquí es de producto (no hay pasarela de pago), no principalmente
   de reglas de Firestore. Se deja anotado para cuando exista dinero real
   (ver Pendientes).

2. **El riesgo nuevo y explotable que sí introduce `soloMetricas()` es la
   escritura de terceros sin relación verificada**, concretamente:
   - Cualquier usuario autenticado puede, con una sola llamada directa al
     SDK/REST de Firestore (sin pasar por la app, usando su propio ID token
     — la config del proyecto Firebase es pública por diseño, la protección
     depende 100% de las reglas), poner el `saldo` de OTRO usuario cualquiera
     en `0` (o cualquier valor menor al actual): sabotaje/DoS directo contra
     la cartera de un tercero, sin relación de trabajo entre ambos.
   - El mismo mecanismo permite fijar `calificacionPromedio`,
     `totalCalificaciones`, `trabajosCompletados`, `trabajosPublicados` y
     `pagosConfirmados` de cualquier usuario a valores arbitrarios en una
     sola llamada (incluso los seis campos a la vez) — fraude de reputación
     (inflar la propia red de cómplices o difamar a un competidor a 0
     estrellas) sin que exista ninguna calificación o trabajo real de por
     medio. Esto es grave porque la reputación es la señal de confianza
     central del marketplace.
   - Se confirmó, leyendo todos los sitios donde el código real escribe
     `saldo` de un tercero (`aceptarTrabajo` → libera pago al trabajador,
     `reembolsar`/`cancelarContratacion` → reembolsa al empleador), que
     **ninguno de esos flujos legítimos reduce el saldo de otra persona** —
     todos son incrementos. `reembolsar()` no tiene ningún llamador desde
     `lib/screens/` (código muerto o pendiente de conectar a la UI;
     no se investigó más a fondo por estar fuera de alcance).

**Decisión:**
- **Mitigación parcial implementada ya, en esta misma tarea, en
  `firestore.rules`:** `soloMetricas()` ahora exige que, si `saldo` está
  entre los campos modificados, el nuevo valor sea `>=` al anterior — un
  tercero ya no puede reducir el saldo de otro usuario. Es un cambio
  aditivo y acotado: no cambia ningún campo que las reglas ya validaban
  distinto, y —verificado leyendo el código— ningún flujo legítimo hoy
  necesita que un tercero reduzca el saldo ajeno, así que no debería romper
  pago/reembolso. **No se pudo validar con el emulador de Firestore
  (`firebase` CLI no está instalado en este entorno y no hay `firebase.json`
  en el repo)** — es una verificación pendiente antes de desplegar a
  producción real.
- **No se endurecen en esta tarea** los campos de reputación
  (`calificacionPromedio`, `totalCalificaciones`, `trabajosCompletados`,
  `trabajosPublicados`, `pagosConfirmados`) ni se agrega verificación de
  relación real (misma publicación) entre quien escribe y el usuario
  objetivo, porque:
  - `calificacionPromedio` es un promedio que **legítimamente puede bajar**
    (una calificación de 1 estrella baja el promedio) — no se puede acotar
    a "solo incrementa" sin romper el flujo real de calificación.
    Validar que el nuevo promedio corresponde matemáticamente a la
    calificación real que se está creando en la misma transacción requeriría
    reglas más complejas (cruzar el `match` de `calificaciones` con el de
    `usuarios`) que no se pueden verificar sin tests de emulador, que no
    existen en este repo.
  - Acotar `totalCalificaciones`/`trabajosCompletados`/`pagosConfirmados` a
    incrementos de exactamente 1 por escritura reduce el radio de daño por
    llamada pero no lo elimina (un atacante puede llamar N veces), y sigue
    sin resolver la falta de verificación de relación real.
  - El propio archivo de tarea (`docs/agent-tasks/
    002-revisar-riesgo-saldo-firestore.md`) instruye explícitamente no
    implementar en solitario cambios que puedan romper el flujo de
    calificación/pago/asignación que depende de escrituras de terceros — y
    ese es exactamente el caso aquí.
- **Se compara contra "esperar a ADR-0002" (backend Spring Boot):** esperar
  eliminaría el problema de raíz (mover `saldo` a un ledger server-side,
  `MovimientoCartera`, ya diseñado en Postgres), pero ADR-0002 sigue "Abierto
  — no decidido" y no tiene fecha. La mitigación de `saldo` de esta tarea es
  de bajo costo y no bloquea esa migración futura; el endurecimiento de
  reputación se deja como tarea explícita en vez de esperar indefinidamente.
- Se crea `docs/agent-tasks/004-endurecer-metricas-terceros-firestore.md`
  para el trabajo pendiente: (a) instalar/configurar el emulador de
  Firestore + tests de reglas (`@firebase/rules-unit-testing`) — no existe
  hoy en el repo, es un prerrequisito real, no opcional, para tocar más esta
  función con confianza; (b) diseñar la validación de relación real
  (publicación compartida) y los límites de reputación con esos tests como
  red de seguridad; (c) evaluar si conviene mover `saldo` a una subcolección
  separada (`usuarios/{uid}/cartera/actual`) con reglas propias, más fácil
  de auditar que un campo suelto en el documento de usuario.

**Consecuencias:**
- El vector de sabotaje más grave y de menor esfuerzo (vaciar el saldo de un
  tercero con un solo write) queda cerrado hoy, sin depender de ADR-0002.
- El fraude de reputación vía terceros y la falta de verificación de
  relación real siguen abiertos — cualquier agente que toque `usuarios` o
  `firestore.rules` debe saberlo (ver tarea 004).
- El riesgo de "dueño puede escribir su propio `saldo` sin límite" también
  sigue abierto, pero se evaluó como equivalente en la práctica a la falta
  de pasarela de pago real (riesgo de producto, no de reglas) — pasa a ser
  relevante recién cuando `saldo` represente dinero real, momento en el que
  debe resolverse junto con ADR-0002, no antes.
- No hay tests automatizados de `firestore.rules` en este repo todavía; el
  cambio de esta tarea se verificó por lectura exhaustiva del código
  consumidor, no por ejecución — ver limitación explícita arriba.
