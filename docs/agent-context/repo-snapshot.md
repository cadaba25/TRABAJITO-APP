# Snapshot del repo — última actualización: 2026-08-19

> Formato intencionalmente breve. Para narrativa y razones, ver
> `docs/architecture.md` y `docs/decisions.md`.

**En producción / en uso real:** Flutter + Firebase (Auth + Firestore).
**Construido pero desconectado:** backend Spring Boot + PostgreSQL + JWT en
`backend/` (esqueleto completo, ver `backend/README.md`).
**No iniciado:** Redis, migración real a Spring Boot, CI que corra tests en
cada PR, refresh tokens (el JWT del backend existe pero no se verificó su
política de expiración/refresh como parte de este análisis).

**Ramas:** `master` (protegida, = producción) ← `develop` (protegida,
integración) ← `feature|fix|chore|docs/*` (donde trabajan los agentes).

**Build:**
- Flutter: `flutter analyze` limpio (solo warnings menores). `flutter test`
  ROTO — `test/widget_test.dart` referencia una clase inexistente (`MyApp`).
- Backend: `mvn compile` → `BUILD SUCCESS` (verificado 2026-08-19, ver
  `docs/development.md`). Docker Desktop + Maven ya están instalados en el
  entorno de este equipo. No se corrió `mvn test` todavía — no asumas que
  hay tests pasando, solo que compila.

**Riesgo de seguridad conocido, sin resolver:** `firestore.rules` permite a
cualquier usuario autenticado escribir el campo `saldo` de otro usuario
(comentario propio del archivo lo admite como "solo para el prototipo").
Ver `docs/database.md` sección 1.

**Tareas activas:** ver `docs/agent-tasks/` — si esta lista está vacía, no
hay tareas en curso, no que no haya nada por hacer (ver `docs/ROADMAP.md`
para el backlog de producto).
