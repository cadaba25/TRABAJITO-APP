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
