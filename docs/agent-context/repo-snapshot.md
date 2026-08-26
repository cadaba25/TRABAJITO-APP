# Snapshot del repo — última actualización: 2026-08-26

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
  71/71 tests pasan** en la máquina de desarrollo (2026-08-26, tras la tarea
  009: +12 de `MapeoErroresHttpTest`, el **primer test de la capa HTTP** del
  backend — MockMvc + H2, sin Docker, un caso por cada error que antes salía
  como 500). Aparte,
  `IntegridadCarteraConcurrenteTest` (6 tests con Testcontainers) pasa **solo
  en el servidor Ubuntu** — en Windows, Docker Desktop responde 400 al
  cliente de Testcontainers. **Ojo:** si Testcontainers no encuentra Docker,
  esos 6 tests se SALTAN y Maven igual dice `BUILD SUCCESS`; mirar siempre el
  contador de *Skipped*. Reparto de los 71 (22 desde la tarea 003 el
  2026-08-19, ver `docs/agent-reports/003-tests-base-backend.md`; +12 en la
  008, +25 en la 010, +12 en la 009): 1 test de contexto (`@SpringBootTest`
  con H2 en memoria, no Postgres/Docker), 7 de `AuthService`, 40 de
  `TrabajoService` (máquina de estados + escrow + reglas de la 010), 11 de
  `RegistroRolTest` (el registro público no puede crear ADMIN —
  deserialización JSON + Bean Validation) y 12 de `MapeoErroresHttpTest`
  (MockMvc sobre H2, mapeo de errores HTTP); todos con Mockito puro salvo el
  de contexto y el de MockMvc. Docker Desktop + Maven ya
  están instalados en el entorno de este equipo, pero los tests actuales
  NO requieren Docker corriendo (decisión documentada en el reporte).
  Sigue sin haber tests de `PagoService` directo, de los controllers de
  negocio (el único `MockMvc` que existe es `MapeoErroresHttpTest`, y cubre
  el mapeo de errores, no los flujos), ni de la capa de
  seguridad (`JwtAuthFilter`, etc.) — ver "Pendientes" en los reportes de
  las tareas 003 y 008. **Esos tests no detectan los fallos de la tarea
  006**: son unitarios con Mockito, sin BD, sin transacciones y sin HTTP.
- Integración contra el servidor: `backend/scripts/prueba-flujo-negocio.sh`
  (nuevo, tarea 006). 155 comprobaciones de API + BD con `curl`/`psql` contra
  el backend en marcha; comprueba el dinero, no solo los códigos HTTP.
  Última ejecución (2026-08-26, tras la tarea 009): **155 OK, 0 fallos
  conocidos, 0 inesperados**, y el cuadre contable pasa para los 7 usuarios de
  prueba. **Ya no queda ningún fallo conocido marcado**: los de las tareas
  007, 008, 009 y 010 pasaron a ser tests de regresión. Sale con código 1 solo
  si aparece un fallo NUEVO. No corre en CI (no hay CI).

**Fallos CRÍTICOS que encontró la tarea 006 — los CUATRO ya cerrados
(último: 2026-08-26). Ver `docs/agent-reports/006-flujos-negocio-contra-postgres.md`:**
no eran hipótesis, se reprodujeron contra PostgreSQL real, y cada arreglo se
verificó también contra el servidor.
- ~~**Se puede crear dinero de la nada** (tarea 007): dos `POST
  /api/trabajos/{id}/reservar-pago` simultáneos con saldo para uno solo
  devuelven ambos 200~~ → **ARREGLADO el 2026-08-21** (tarea 007, ADR-0006,
  ver `docs/agent-reports/007-integridad-dinero-cartera-escrow.md`). Bloqueo
  pesimista con orden global de bloqueo, `@DynamicUpdate` en `Usuario`,
  `CHECK (saldo >= 0)` en la BD y validación de escala de montos. Verificado
  en el servidor: el mismo ataque ahora da 200 + 400, y el cuadre
  `saldo == SUM(movimientos_cartera.monto)` pasa para todos los usuarios.
  Cubierto por `IntegridadCarteraConcurrenteTest` (Testcontainers +
  PostgreSQL 16): **6/6 pasan con el arreglo y 6/6 fallan sin él**
  (comprobado el 2026-08-25). Ese test **solo corre en el servidor Ubuntu**:
  en Windows el proxy de API de Docker Desktop devuelve 400. Comando en el
  reporte 007.
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
- ~~El empleador puede **cancelar tras la entrega** y recuperar el escrow
  entero~~ → **ARREGLADO** (tarea 010, ADR-0007, ver
  `docs/agent-reports/010-cancelacion-unilateral-tras-la-entrega.md`):
  cancelar/rechazar responden 409 desde `EN_PROGRESO`, entregar exige
  evidencias y el reclamo a soporte congela el escrow hasta que lo resuelve
  un ADMIN.
- ~~10 errores de cliente devuelven **HTTP 500** y el handler genérico **no
  loguea nada**~~ → **ARREGLADO el 2026-08-26** (tarea 009, ADR-0008, ver
  `docs/agent-reports/009-errores-no-mapeados-devuelven-500.md`). Cada error
  devuelve su código (400/401/403/404/405/409/415) con el cuerpo
  `{timestamp,status,error,message,fields?}`, incluidos los 401/403 que emite
  la cadena de filtros de Spring Security (antes, sin token → 403 con cuerpo
  vacío). `@Valid` en los 15 `@RequestBody`. Todo error se loguea: 5xx con
  stacktrace (ERROR), 4xx en una línea (DEBUG), auth en INFO —verificado en
  `docker compose logs api` del servidor real, que antes salía vacío—. El
  login de una cuenta suspendida ya no se distingue de una contraseña mala
  (mismo 401, mismo mensaje; el motivo real va al log).

**Ninguno afectaba a la app en producción** (Flutter usa Firebase, nadie
consume este backend). Con 007-010 cerrados **no queda ningún fallo crítico
abierto de los que encontró la tarea 006**; sigue abierto el riesgo de
exposición del servidor de pruebas (tarea 011).

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
para el backlog de producto). Quedaron `hecho`:
`005-backend-en-servidor-ubuntu`, `006-flujos-negocio-contra-postgres`,
`007-integridad-dinero-cartera-escrow`,
`008-registro-publico-permite-rol-admin`,
`009-errores-no-mapeados-devuelven-500` (2026-08-26, pendiente de revisión de
`security-agent` porque toca `SecurityConfig`) y
`010-cancelacion-unilateral-tras-la-entrega`. Siguen en `todo`:
`004-endurecer-metricas-terceros-firestore` y
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
