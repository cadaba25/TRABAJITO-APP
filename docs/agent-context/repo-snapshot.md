# Snapshot del repo — última actualización: 2026-08-20

> Formato intencionalmente breve. Para narrativa y razones, ver
> `docs/architecture.md` y `docs/decisions.md`.

**En producción / en uso real:** Flutter + Firebase (Auth + Firestore).
**Construido, YA VERIFICADO EN UN SERVIDOR, pero sin consumidor:** backend
Spring Boot + PostgreSQL + JWT en `backend/` (ver `backend/README.md`).
Desde el 2026-08-20 (tarea 005) **ya corrió de verdad fuera de la máquina del
desarrollador**: `docker compose up -d` levanta `db` + `api` en la VM Ubuntu
de pruebas, Hibernate crea las 11 tablas en PostgreSQL 16 real, y
registro/login/`GET /api/auth/yo` con JWT responden 200 (sin token, 401). Ver
`docs/agent-reports/005-backend-en-servidor-ubuntu.md`. **Ojo:** eso valida
arranque y auth, NO los flujos de negocio (trabajos, escrow, chat/WebSocket)
— esos siguen sin probarse contra Postgres.
**No iniciado:** Redis, migración real a Spring Boot, CI que corra tests en
cada PR, refresh tokens (el JWT del backend existe pero no se verificó su
política de expiración/refresh como parte de este análisis).

**Ramas:** `master` (protegida, = producción) ← `develop` (protegida,
integración) ← `feature|fix|chore|docs/*` (donde trabajan los agentes).

**Build:**
- Flutter: `flutter analyze` limpio (solo warnings/info menores
  preexistentes, ninguno bloqueante). `flutter test` ARREGLADO (2026-08-19,
  tarea 001, ver `docs/agent-reports/001-fix-widget-test.md`) — 4 tests
  pasan: `test/widget_test.dart` (comprobación mínima de `TrabajitApp`) y
  `test/pantalla_inicial_test.dart` (arranque real: `PantallaInicial`
  decide entre `LoginScreen`/`InicioScreen`/`PantallaCarga` según el
  estado de auth, mockeando `FirebaseAuthPlatform.instance`). Fuera de
  estos, sigue sin haber tests de pantallas, servicios o modelos — no
  asumas cobertura donde no se ha verificado.
- Backend: `mvn compile` → `BUILD SUCCESS`. `mvn test` → **BUILD SUCCESS,
  22/22 tests pasan** (verificado 2026-08-19, tarea 003, ver
  `docs/agent-reports/003-tests-base-backend.md`): 1 test de contexto
  (`@SpringBootTest` con H2 en memoria, no Postgres/Docker), 6 tests de
  `AuthService` y 15 de `TrabajoService` (máquina de estados + escrow),
  todos con Mockito puro salvo el de contexto. Docker Desktop + Maven ya
  están instalados en el entorno de este equipo, pero los tests actuales
  NO requieren Docker corriendo (decisión documentada en el reporte).
  Sigue sin haber tests de `PagoService` directo, controllers
  (`MockMvc`), ni de la capa de seguridad (`JwtAuthFilter`, etc.) — ver
  "Pendientes" en el reporte de la tarea 003.

**Riesgo de seguridad — mitigado parcialmente (2026-08-19, tarea 002, ver
`docs/agent-reports/002-revisar-riesgo-saldo-firestore.md` y ADR-0004):**
`firestore.rules` seguía permitiendo a cualquier usuario autenticado
escribir métricas de OTRO usuario (`saldo` y reputación) sin relación real
entre ambos. Ya no puede reducir el `saldo` ajeno (vector de sabotaje más
grave, cerrado). **Sigue sin resolver:** un tercero aún puede fijar
`calificacionPromedio`/`totalCalificaciones`/`trabajosCompletados`/
`trabajosPublicados`/`pagosConfirmados` de cualquier otro usuario a
cualquier valor, sin relación real — ver tarea
`docs/agent-tasks/004-endurecer-metricas-terceros-firestore.md`. Ver
`docs/database.md` sección 1.

**Tareas activas:** ver `docs/agent-tasks/` — si esta lista está vacía, no
hay tareas en curso, no que no haya nada por hacer (ver `docs/ROADMAP.md`
para el backlog de producto). Tarea `004-endurecer-metricas-terceros-firestore`
queda `todo`. Tarea `005-backend-en-servidor-ubuntu` quedó `hecho`.

**Infra (2026-08-20):** `backend/docker-compose.yml` ya levanta `db` **y**
`api` (el servicio `api` estaba comentado hasta la tarea 005). `JWT_SECRET`
es ahora una variable **requerida**: sin `backend/.env` cualquier comando de
compose falla a propósito, incluso `up -d db`. Sigue sin haber CI que corra
tests en cada PR (`.github/workflows/claude.yml` no es CI).
