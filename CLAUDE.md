# Trabajito — Guía para agentes (Claude Code)

Este archivo se carga automáticamente en cada sesión de Claude Code sobre este
repositorio. Es la puerta de entrada: define quién eres, qué existe realmente
en el proyecto, y las reglas que no se negocian. Los detalles largos viven en
`docs/`; aquí solo lo esencial y los enlaces.

> Si estás actuando como uno de los agentes especializados, tu instrucción de
> rol específica está en `.claude/agents/<tu-nombre>.md`. Este archivo aplica
> a TODOS los agentes por igual, incluida la sesión "genérica" del Tech Lead.

## 0. Antes de tocar nada

1. Lee `docs/agent-context/RETOMAR-AQUI.md` — **dónde estamos y qué sigue**,
   más las trampas conocidas que no se deducen leyendo el código. Es lo
   primero si abres una sesión nueva sin contexto.
2. Lee `docs/agent-context/repo-snapshot.md` — es el resumen vivo de qué
   existe hoy. Si algo aquí lo contradice, confía en el snapshot (o mejor,
   verifica tú mismo con `git log`, `grep`, o abriendo el archivo).
3. Si vas a trabajar una tarea concreta, revisa si ya existe un archivo en
   `docs/agent-tasks/` para ella. Si no existe, créalo antes de escribir
   código (ver `docs/agent-tasks/README.md`).
4. Nunca asumas que una funcionalidad existe, está conectada, o funciona
   porque el nombre de un archivo lo sugiere. Este proyecto tiene módulos
   construidos pero **desconectados entre sí** (ver sección 2). Verifica.

## 1. Qué es Trabajito

App para conectar trabajadores independientes (freelance / oficios) con
personas o empresas que quieren contratarlos en Honduras, para trabajos
pequeños o grandes.

## 2. Estado REAL del stack (verificado 2026-09-18, no asumido; refleja la cadena de PRs #21-#31 ya mergeada)

**La migración de ADR-0009 terminó en el cliente (2026-09-18):** la app habla
solo con el backend propio y Firebase/Firestore salieron de `lib/` y de
`pubspec.yaml` (ADR-0019). Lo que queda es borrar `firestore.rules` y el
proyecto Firebase (fase 3).

| Capa | Lo que REALMENTE corre hoy | Notas |
|---|---|---|
| Frontend | Flutter/Dart, app móvil (Android confirmado; iOS sin `GoogleService-Info.plist`) | Único cliente que existe. Estructura **por funcionalidad** desde la tarea 027 (ADR-0014): `lib/funcionalidades/`, `lib/nucleo/`, `lib/compartido/`. `lib/screens/`, `lib/services/` y `lib/utils/` ya no existen |
| Auth en vivo | **Backend propio, JWT.** Firebase Authentication **ya no se usa** | Access token 15 min + refresh opaco rotativo de 30 días (ADR-0010). Los **tres candados** de renovación están en `lib/nucleo/api/gestor_sesion.dart` — léete su docstring antes de tocarlo |
| Datos en vivo | **Backend propio para todo**: usuarios/perfil, trabajos, postulaciones, evidencias, chat (REST con sondeo, ADR-0018), cartera y calificaciones. Firestore ya no se usa (ADR-0019) | El pago del chat es un monto **total**, no por hora |
| Backend propio | `backend/` — Java 17 + Spring Boot 3.3 + PostgreSQL 16 + JWT, **funcional y CON consumidor** | Corre en la VM Ubuntu con `docker compose up -d`. `JWT_SECRET` es variable requerida: sin `backend/.env`, compose falla a propósito |
| Cache | Redis — **no existe, y se descartó a propósito** | El freno de fuerza bruta se resolvió en PostgreSQL. Razón en ADR-0010 |
| Tiempo real | WebSocket/STOMP en `/ws`, **construido y sin uso desde la app** | El CONNECT exige JWT (tarea 030) y el SUBSCRIBE solo admite `/topic/chats/{uuid}` a participantes (057). El chat va por REST con sondeo; STOMP es mejora futura y no se ha probado en vivo |
| CI/CD | `.github/workflows/claude.yml` | **No es CI**: nadie corre `flutter test` ni `mvn test` en un PR. Sigue sin existir ese pipeline, y con él el check del techo de 300 líneas (ADR-0014) |
| Tests | Flutter: **350 pasan**. Backend: **147 tests, 0 skipped con Docker** (verificado con JDK 24 y flags, no con JDK 17) | **Ojo:** los unitarios con Mockito NO detectaron ninguno de los 4 fallos graves que sí encontró la prueba de integración real (tarea 006). "Los tests pasan" ≠ "funciona". Ver `backend/scripts/prueba-flujo-negocio.sh` (222 comprobaciones) |

**Reglas de oro, las tres:**

1. **"¿Esto vive en Firestore o en Postgres?"** — hoy la respuesta es siempre
   Postgres; Firestore ya no existe en la app. Si ves código que lo asume,
   es histórico o un bug.
2. **Verifica, no asumas.** Este proyecto tiene módulos construidos y
   desconectados, y documentación que se queda vieja (este mismo archivo
   describía Firebase como fuente de verdad tres semanas después de dejar de
   serlo). `git log`, `grep` y abrir el archivo.
3. **Los parámetros mal no dan error.** El feed pagina con `pagina`/`tamano`,
   no con `page`/`size`: mandar los equivocados no falla, se ignoran y
   devuelven siempre la página 0. Hay trampas así; comprueba el contrato real
   en `docs/api.md` y, si dudas, contra el servidor.

## 3. Fuente de verdad — mapa de documentos

| Documento | Contenido |
|---|---|
| `docs/architecture.md` | Arquitectura actual vs. objetivo, límites entre módulos |
| `docs/database.md` | Esquema PostgreSQL **en uso real** + las colecciones de Firestore, solo históricas |
| `docs/api.md` | Endpoints del backend Spring Boot, **consumidos por la app**. Ojo a los nombres de parámetro: ver regla de oro 3 |
| `docs/decisions.md` | Registro de decisiones arquitectónicas (ADRs) |
| `docs/development.md` | Cómo correr el proyecto, checklist de "tarea terminada" |
| `docs/git-workflow.md` | Ramas, commits, PRs |
| `docs/design-system-frontend.md` | Sistema de diseño frontend declarado por el dueño (paleta, tipografía, espaciado, iconografía Lucide, principios de UI). Copia espejo en `.claude/skills/trabajito-frontend-design/` (gitignorada, autocargada solo en esta máquina) — `docs/` manda si difieren |
| `docs/design-system-ux-patrones.md` | Patrones de UX por tipo de pantalla (trabajos, chat, negociación, wallet, calificaciones, perfil...) — checklist de producto, no tokens visuales. Copia espejo en `.claude/skills/trabajito-product-ui-ux/` (gitignorada) |
| `docs/ROADMAP.md` | Roadmap de producto (ya existía antes de este sistema; no duplicar) |
| `docs/agent-context/` | `RETOMAR-AQUI.md` (dónde estamos y qué sigue) + snapshot vivo + protocolo de coordinación |
| `docs/agent-tasks/` | Una tarea = un archivo. Se crea antes de programar |
| `docs/agent-reports/` | Cierre de cada tarea: qué se hizo, qué falta, qué se probó |

## 4. Agentes disponibles

Definidos en `.claude/agents/`. Invócalos con la herramienta Agent
(`subagent_type: <nombre>`).

| Agente | Dominio |
|---|---|
| `tech-lead` | Planificación, reparto de tareas, coherencia arquitectónica, resolución de conflictos entre agentes |
| `flutter-agent` | UI, navegación, estado, formularios, consumo de datos (API REST propia), tests Flutter |
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

14. **Un archivo, una razón para cambiar.** Ningún archivo Dart pasa de
    **300 líneas** sin justificarlo en el reporte de la tarea. No es un
    número sagrado: es un disparador de revisión. Ver ADR-0014.
15. **Las pantallas no contienen reglas de negocio ni llamadas HTTP
    directas.** Una pantalla hace layout y despacha eventos; los diálogos y
    las secciones grandes salen a su propio archivo. Los servicios se
    **reciben por inyección** (`provider`), no se construyen dentro
    (`final _s = MiService();` es exactamente lo que dejó sin test a 12 de
    las 14 pantallas).
16. **Flutter se organiza por funcionalidad, no por tipo**
    (`lib/funcionalidades/<lo-que-sea>/`), con `nucleo/` y `compartido/`
    para lo transversal. Código nuevo nace ahí; el viejo se mueve cuando hay
    que abrirlo por otra razón. Ver ADR-0014.

## 6. Flujo de trabajo (resumen — detalle en `docs/git-workflow.md`)

```
Usuario → tech-lead (planifica, crea tarea en docs/agent-tasks/)
        → agente especializado (implementa en su rama feature/*)
        → security-agent (si el cambio toca auth/datos/dinero)
        → qa-agent (tests, edge cases)
        → docs-agent (actualiza docs/ si algo cambió de forma visible)
        → PR contra develop → revisión humana → merge
```
