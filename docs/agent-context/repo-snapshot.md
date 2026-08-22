# Snapshot del repo — última actualización: 2026-08-21

> Formato intencionalmente breve. Para narrativa y razones, ver
> `docs/architecture.md` y `docs/decisions.md`.

**En producción / en uso real:** Flutter + Firebase (Auth + Firestore).
**Construido, YA VERIFICADO EN UN SERVIDOR, pero sin consumidor:** backend
Spring Boot + PostgreSQL + JWT en `backend/` (ver `backend/README.md`).
Desde el 2026-08-20 (tarea 005) **ya corrió de verdad fuera de la máquina del
desarrollador**: `docker compose up -d` levanta `db` + `api` en la VM Ubuntu
de pruebas, Hibernate crea las 11 tablas en PostgreSQL 16 real, y
registro/login/`GET /api/auth/yo` con JWT responden 200 (sin token, 401). Ver
`docs/agent-reports/005-backend-en-servidor-ubuntu.md`.
Desde el 2026-08-21 (tarea 006) **los flujos de negocio también se ejercitaron
contra ese PostgreSQL real**: publicar → postularse → aceptar → escrow →
iniciar → terminar → liberar pago → calificar funciona de punta a punta y el
dinero cuadra al céntimo **de forma secuencial**. Con concurrencia NO (ver el
bloque de fallos críticos más abajo). El chat/WebSocket **sigue sin probarse**.
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
  34/34 tests pasan** (22 desde la tarea 003 el 2026-08-19, ver
  `docs/agent-reports/003-tests-base-backend.md`; +12 en la tarea 008 el
  2026-08-21): 1 test de contexto (`@SpringBootTest` con H2 en memoria, no
  Postgres/Docker), 7 tests de `AuthService`, 15 de `TrabajoService`
  (máquina de estados + escrow) y 11 de `RegistroRolTest` (el registro
  público no puede crear ADMIN — deserialización JSON + Bean Validation),
  todos con Mockito puro salvo el de contexto. Docker Desktop + Maven ya
  están instalados en el entorno de este equipo, pero los tests actuales
  NO requieren Docker corriendo (decisión documentada en el reporte).
  Sigue sin haber tests de `PagoService` directo, controllers
  (`MockMvc` — **ni uno solo en todo el backend**), ni de la capa de
  seguridad (`JwtAuthFilter`, etc.) — ver "Pendientes" en los reportes de
  las tareas 003 y 008. **Esos tests no detectan los fallos de la tarea
  006**: son unitarios con Mockito, sin BD, sin transacciones y sin HTTP.
- Integración contra el servidor: `backend/scripts/prueba-flujo-negocio.sh`
  (nuevo, tarea 006). 102 comprobaciones de API + BD con `curl`/`psql` contra
  el backend en marcha; comprueba el dinero, no solo los códigos HTTP.
  Última ejecución (2026-08-21, tras la tarea 008): **86 OK, 19 fallos
  conocidos (bugs con tarea abierta), 0 inesperados**. Sale con código 1 solo
  si aparece un fallo NUEVO, así que ya sirve de test de regresión. No corre
  en CI (no hay CI).

**Fallos CRÍTICOS abiertos en el backend (2026-08-21, tarea 006, ver
`docs/agent-reports/006-flujos-negocio-contra-postgres.md`):** no son
hipótesis, se reprodujeron contra PostgreSQL real.
- **Se puede crear dinero de la nada** (tarea 007): dos `POST
  /api/trabajos/{id}/reservar-pago` simultáneos con saldo para uno solo
  devuelven ambos 200 → un empleador recargó L. 1000 y pagó L. 2000 a dos
  trabajadores. `PagoService` hace read-modify-write del saldo sin bloqueo, y
  `usuarios.saldo` deja de cuadrar con `SUM(movimientos_cartera.monto)`.
- ~~**Escalada de privilegios** (tarea 008): `POST /api/auth/registro` acepta
  `"rol":"ADMIN"`~~ → **ARREGLADO el 2026-08-21** (tarea 008, ADR-0005, ver
  `docs/agent-reports/008-registro-publico-permite-rol-admin.md`). El registro
  público solo puede crear `TRABAJADOR` o `EMPLEADOR` (enum `RolPublico` en el
  DTO); `"rol":"ADMIN"`, `"admin"`, `"ROLE_ADMIN"` o `"SUPERJEFE"` → **400 sin
  crear fila**, verificado contra el servidor. No existe otra vía para
  auto-asignarse rol (`PUT /api/usuarios/me` ignora el campo; solo hay dos
  escrituras de `rol` en todo el backend). El ADMIN se aprovisiona ahora con
  `ADMIN_INICIAL_CORREO`/`ADMIN_INICIAL_PASSWORD` (`AdminInicialSeeder`, que
  sustituye a `DataSeeder` y a su contraseña fija `Admin1234`) o con SQL —
  ver `backend/README.md` → "Cómo se crea un ADMIN". Por defecto el backend
  arranca **sin ningún ADMIN**.
- El empleador puede **cancelar tras la entrega** y recuperar el escrow
  entero (tarea 010, alta).
- 10 errores de cliente devuelven **HTTP 500** y el handler genérico **no
  loguea nada** (tarea 009, media). Eran 11: el `"rol":"SUPERJEFE"` del
  registro ya devuelve 400 desde la tarea 008.

**Ninguno afecta a la app en producción hoy** (Flutter usa Firebase, nadie
consume este backend), pero los que siguen abiertos (007, 009, 010) bloquean
la decisión de ADR-0002.

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
queda `todo`. Tareas `005-backend-en-servidor-ubuntu`,
`006-flujos-negocio-contra-postgres` y
`008-registro-publico-permite-rol-admin` quedaron `hecho`. Abiertas en `todo`
y sin empezar: `007-integridad-dinero-cartera-escrow` (crítica),
`009-errores-no-mapeados-devuelven-500`,
`010-cancelacion-unilateral-tras-la-entrega`,
`011-exposicion-del-servidor-de-pruebas` (hallazgo lateral de la 008: la VM
publica la API en `0.0.0.0:8080`).

**Estado de la BD del servidor de pruebas:** tras la tarea 006 contiene
usuarios con el saldo descuadrado a propósito (para dejar la evidencia) y
5 cuentas ADMIN de prueba auto-registradas, que la tarea 008 dejó con
`activo=false` (no se borraron, para no destruir la evidencia de los reportes
006 y 008; el SQL para revertirlo está en el reporte 008). Todas las cuentas
que crea el script de QA usan la misma contraseña conocida. No es una BD
limpia ni un entorno de confianza; tenlo en cuenta si vas a probar ahí.

**Infra (2026-08-20):** `backend/docker-compose.yml` ya levanta `db` **y**
`api` (el servicio `api` estaba comentado hasta la tarea 005). `JWT_SECRET`
es ahora una variable **requerida**: sin `backend/.env` cualquier comando de
compose falla a propósito, incluso `up -d db`. Sigue sin haber CI que corra
tests en cada PR (`.github/workflows/claude.yml` no es CI).
