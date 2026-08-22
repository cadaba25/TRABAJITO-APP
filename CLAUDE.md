# Trabajito — Guía para agentes (Claude Code)

Este archivo se carga automáticamente en cada sesión de Claude Code sobre este
repositorio. Es la puerta de entrada: define quién eres, qué existe realmente
en el proyecto, y las reglas que no se negocian. Los detalles largos viven en
`docs/`; aquí solo lo esencial y los enlaces.

> Si estás actuando como uno de los agentes especializados, tu instrucción de
> rol específica está en `.claude/agents/<tu-nombre>.md`. Este archivo aplica
> a TODOS los agentes por igual, incluida la sesión "genérica" del Tech Lead.

## 0. Antes de tocar nada

1. Lee `docs/agent-context/repo-snapshot.md` — es el resumen vivo de qué
   existe hoy. Si algo aquí lo contradice, confía en el snapshot (o mejor,
   verifica tú mismo con `git log`, `grep`, o abriendo el archivo).
2. Si vas a trabajar una tarea concreta, revisa si ya existe un archivo en
   `docs/agent-tasks/` para ella. Si no existe, créalo antes de escribir
   código (ver `docs/agent-tasks/README.md`).
3. Nunca asumas que una funcionalidad existe, está conectada, o funciona
   porque el nombre de un archivo lo sugiere. Este proyecto tiene módulos
   construidos pero **desconectados entre sí** (ver sección 2). Verifica.

## 1. Qué es Trabajito

App para conectar trabajadores independientes (freelance / oficios) con
personas o empresas que quieren contratarlos en Honduras, para trabajos
pequeños o grandes.

## 2. Estado REAL del stack (verificado 2026-08-20, no asumido)

Esto es lo que existe y corre hoy. El stack "objetivo" que describe el dueño
del proyecto (Spring Boot + PostgreSQL + JWT) **ya tiene un esqueleto
construido pero NO está conectado a la app**. Ver `docs/decisions.md`
ADR-0002 antes de asumir que la migración ya está en marcha.

| Capa | Lo que REALMENTE corre hoy | Notas |
|---|---|---|
| Frontend | Flutter/Dart, app móvil (Android confirmado; iOS sin `GoogleService-Info.plist`) | Único cliente que existe |
| Datos en vivo | **Firebase Firestore** — la app lee/escribe Firestore directamente desde Flutter | `pubspec.yaml` no tiene ningún paquete `http`/`dio`; cero llamadas a una API propia |
| Auth en vivo | **Firebase Authentication** | `AuthService` en Flutter envuelve `firebase_auth` |
| Backend propio | `backend/` — Java 17 + Spring Boot 3.3 + PostgreSQL + JWT, **funcional pero sin consumidor** | Desde la tarea 005 ya corre de verdad en un servidor (VM Ubuntu): arranca contra PostgreSQL real, crea las 11 tablas, y auth (registro/login/JWT) responde 200. **Ningún cliente lo consume todavía** |
| Cache | Redis — **no existe en el repo** | Estaba en el stack "objetivo" del dueño, no se ha empezado |
| Infra | `backend/docker-compose.yml` levanta `db` + `api` juntos, verificado en servidor | Flutter no se dockeriza (es app móvil). `JWT_SECRET` es variable requerida: sin `backend/.env`, compose falla a propósito |
| CI/CD | `.github/workflows/claude.yml` — dispara Claude Code Action con `@claude` en comentarios | **No es CI**: no corre `flutter analyze`, `flutter test` ni `mvn test` en cada PR. Ese pipeline no existe todavía |
| Tests | Flutter: 4 tests pasan. Backend: 34 tests pasan (`mvn test`) | **Ojo:** los tests unitarios usan Mockito y NO detectaron ninguno de los 4 fallos graves que sí encontró la prueba de integración real (tarea 006). "Los tests pasan" ≠ "funciona". Ver `backend/scripts/prueba-flujo-negocio.sh` |

**Regla de oro para todos los agentes:** si vas a tocar autenticación, perfil
de usuario, o cualquier dato de negocio, pregúntate primero "¿esto vive en
Firestore o en Postgres?" — hoy, casi todo vive en Firestore. El backend
Spring Boot es un objetivo a futuro, no la fuente de verdad actual.

## 3. Fuente de verdad — mapa de documentos

| Documento | Contenido |
|---|---|
| `docs/architecture.md` | Arquitectura actual vs. objetivo, límites entre módulos |
| `docs/database.md` | Colecciones de Firestore (reales) + esquema Postgres (diseñado, no en uso) |
| `docs/api.md` | Endpoints del backend Spring Boot (implementados, no consumidos aún) |
| `docs/decisions.md` | Registro de decisiones arquitectónicas (ADRs) |
| `docs/development.md` | Cómo correr el proyecto, checklist de "tarea terminada" |
| `docs/git-workflow.md` | Ramas, commits, PRs |
| `docs/ROADMAP.md` | Roadmap de producto (ya existía antes de este sistema; no duplicar) |
| `docs/agent-context/` | Snapshot vivo del repo + protocolo de coordinación |
| `docs/agent-tasks/` | Una tarea = un archivo. Se crea antes de programar |
| `docs/agent-reports/` | Cierre de cada tarea: qué se hizo, qué falta, qué se probó |

## 4. Agentes disponibles

Definidos en `.claude/agents/`. Invócalos con la herramienta Agent
(`subagent_type: <nombre>`).

| Agente | Dominio |
|---|---|
| `tech-lead` | Planificación, reparto de tareas, coherencia arquitectónica, resolución de conflictos entre agentes |
| `flutter-agent` | UI, navegación, estado, formularios, consumo de datos (Firestore hoy; API REST cuando exista), tests Flutter |
| `backend-agent` | Spring Boot, JPA/PostgreSQL, endpoints REST, WebSocket, migraciones, tests backend |
| `security-agent` | Auth, JWT, roles/permisos, reglas de Firestore, validación de inputs, revisión de cambios sensibles de otros agentes |
| `qa-agent` | Tests (Flutter + backend), casos borde, regresión, romper flujos a propósito |
| `devops-agent` | Docker, CI/CD (GitHub Actions), variables de entorno, despliegue |
| `docs-agent` | Mantener `docs/`, ADRs, docs de API, roadmap sincronizados con la realidad |

No hay agentes separados de "Database", "UI/UX" ni "Code Review" — el porqué
está explicado en `docs/decisions.md` (ADR-0001) y no es un accidente: son
combinaciones deliberadas para no fragmentar responsabilidades pequeñas.

## 5. Reglas globales (aplican a TODOS los agentes, sin excepción)

1. No asumas que una funcionalidad existe, está conectada o probada. Verifica.
2. Antes de modificar código, lee el código relacionado y su tarea en
   `docs/agent-tasks/`.
3. No modifiques archivos de otro dominio (Flutter no toca `backend/java`,
   Backend no toca `lib/`) salvo que sea imprescindible — y si lo haces,
   documenta el porqué en el reporte de la tarea.
4. No borres funcionalidad existente sin autorización explícita del usuario.
5. No agregues dependencias nuevas sin justificarlo en el reporte de tarea.
6. Nunca subas secretos, API keys, contraseñas ni tokens a Git. Revisa
   `git status`/`git diff` antes de cada commit. `backend/.env.example` es la
   plantilla; `.env` real nunca se commitea (ya está en `backend/.gitignore`).
7. Respeta las convenciones existentes: Dart/nombres en español (`Usuario`,
   `Trabajo`, `Postulacion`...), Java en `com.trabajito.modules.<módulo>`.
8. Cambios importantes requieren tests. Si tocas algo sin cobertura, añade la
   cobertura mínima antes de dar la tarea por terminada.
9. Cambios arquitectónicos importantes se documentan en `docs/decisions.md`
   ANTES de implementarse, no después.
10. Antes de dar una tarea por terminada:
    - Flutter: `flutter analyze` sin errores nuevos, `flutter test` pasa (o
      el archivo roto conocido — `test/widget_test.dart` — ya fue arreglado
      como parte de tu tarea si tu tarea lo tocaba).
    - Backend: el módulo compila (`mvn -q compile` o equivalente) y los
      tests relacionados pasan.
    - Si no puedes verificar (por ejemplo, sin `mvn`/`java` instalados en el
      entorno), dilo explícitamente en el reporte — no afirmes que "compila"
      sin haberlo corrido.
11. Ninguna tarea grande (que toque más de un módulo, cambie contratos de
    API, o cambie el modelo de datos) se implementa sin un plan previo del
    `tech-lead` que liste los módulos afectados. Ver `docs/agent-tasks/README.md`.
12. Git: nunca force-push. Nunca commitear directo a `master` ni a `develop`
    — siempre rama + Pull Request. Ver `docs/git-workflow.md`.
13. Si detectas un conflicto con el trabajo de otro agente (mismo archivo,
    misma tabla, mismo endpoint, tocado por una tarea distinta en
    `docs/agent-tasks/`), para y repórtalo al `tech-lead` en vez de resolverlo
    a tu criterio.

## 6. Flujo de trabajo (resumen — detalle en `docs/git-workflow.md`)

```
Usuario → tech-lead (planifica, crea tarea en docs/agent-tasks/)
        → agente especializado (implementa en su rama feature/*)
        → security-agent (si el cambio toca auth/datos/dinero)
        → qa-agent (tests, edge cases)
        → docs-agent (actualiza docs/ si algo cambió de forma visible)
        → PR contra develop → revisión humana → merge
```
