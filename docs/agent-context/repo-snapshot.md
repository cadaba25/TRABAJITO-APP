# Snapshot del repo — última actualización: 2026-08-30 (tarea 024)

> Formato intencionalmente breve. Para narrativa y razones, ver
> `docs/architecture.md` y `docs/decisions.md`.

**En producción / en uso real:** Flutter, **partido en dos desde el 2026-08-27**
(tarea 020): la autenticación y el perfil ya hablan con el backend propio; los
otros cinco servicios siguen en Firestore. **Firebase Authentication ya no se
usa.**
**Backend propio, verificado en un servidor y ya CON consumidor:** Spring Boot
+ PostgreSQL + JWT en `backend/` (ver `backend/README.md`). Sus módulos `auth` y
`usuarios` los usa la app de verdad; el resto sigue esperando la fase 2b.
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
cada PR. **Los refresh tokens YA EXISTEN** desde el 2026-08-26 (tarea 015,
ADR-0010): el JWT de acceso dura 15 min y la sesión la mantiene un refresh
token opaco, rotativo y revocable; `POST /api/auth/logout` la invalida de
verdad. El login además frena la fuerza bruta (429 por IP y por cuenta) sin
poder bloquear a un usuario legítimo, y el registro exige contraseñas de 10 a
72 caracteres. Ver `docs/agent-reports/015-login-exigente.md`.
**Desde el 2026-08-30 (tarea 024, ADR-0012) `POST /api/auth/logout` revoca la
FAMILIA entera** de refresh tokens de esa sesión, no solo la fila presentada
—también si el token que se le presenta ya estaba rotado, que es el caso de la
renovación en vuelo—, y existe **`POST /api/auth/logout-todos`** para cerrar
sesión en todos los dispositivos del usuario, incluido el que lo pide. Ese es
**el único endpoint de `/api/auth/**` que exige token de acceso** (regla
explícita en `SecurityConfig`, antes del `permitAll`). Cerrar sesión en un
dispositivo **no** cierra los demás: una familia = una sesión = un dispositivo.
El access token ya emitido sigue valiendo hasta 15 min después de cualquiera de
los dos logouts (decisión de ADR-0010, fijada ahora en un test). La app
**todavía no tiene botón** para "cerrar sesión en todos los dispositivos"
(tarea 025). Ver `docs/agent-reports/024-logout-debe-revocar-la-familia.md`.
**La migración a backend propio EMPEZÓ** el 2026-08-27 con la fase 1 (tarea
018: `pubspec.yaml` con `http` y `flutter_secure_storage`, `lib/services/api/`
con un `ApiClient` completo, y los 7 modelos con `desdeJson()`/`aJson()`
**además** de sus `desdeFirestore()`/`aFirestore()`). Ver
`docs/agent-reports/018-fase1-cimientos-cliente-http.md`.

**Y ese mismo día dejó de ser andamiaje: la fase 2a ya está hecha** (tarea 020).
**La app ya NO se autentica contra Firebase.** Registro, login, ver y editar el
perfil (con el CV del trabajador), listar trabajadores, el ranking, la baja de
cuenta y el cierre de sesión hablan con `/api/**`. Ningún archivo de `lib/`
importa `firebase_auth`; el paquete sigue en `pubspec.yaml` porque quitarlo es
la fase 3. Cerrar sesión ahora **revoca el refresh token en el servidor**, no
solo borra algo en local.

Lo que hay que saber para no meter la pata a partir de aquí:

- **`authStateChanges()` ya no existe.** Su sustituto es
  `lib/services/sesion_usuario.dart`: `sesionActual`, un
  `ValueNotifier<EstadoSesion>` con tres fases (`comprobando` / `sinSesion` /
  `conSesion`) que rellena `AuthService.restaurarSesion()` al arrancar.
  `PantallaInicial` lo escucha.
- **`streamUsuarioActual()` y `streamTrabajadores()` desaparecieron.** En su
  lugar: `recargarPerfil()` y `listarTrabajadores()`, con carga puntual y
  "deslizar para actualizar" (decisión del `tech-lead` para la fase 2). No hay
  sondeo en ningún sitio.
- **`habilidades`, `experiencia` y `estudios` llegan `null`** en login, registro
  y ranking, y como lista en `GET /api/auth/yo`, `GET /api/usuarios/{id}` y la
  respuesta de `PUT /api/usuarios/me`. `null` = "no viene en esta respuesta",
  NO "el usuario no tiene". Tratarlo como lista vacía y guardar **borra el CV
  del usuario**, y no da ningún error al hacerlo. Por eso existe
  `Usuario.cvCargado`, por eso `Usuario.aJson()` nunca manda el CV, y por eso
  tras el login se pide `GET /api/auth/yo`.
- **`fechaNacimiento` sale siempre en ISO** (`1995-03-15`) aunque entre en
  `dd/MM/aaaa`. Para enseñarla, `Usuario.fechaNacimientoLegible`.
- **El `uid` ya no es el de Firebase, es el UUID del backend.** Consecuencia
  directa y esperada: **las pantallas que siguen en Firestore no encuentran
  datos** de una cuenta creada contra el backend, y además `firestore.rules`
  exige `request.auth != null`, que ya no se cumple. No afecta a nadie hoy (los
  datos de Firebase son de prueba, ADR-0009) y se cierra en la fase 2b, pero
  quien pruebe la app entre medias debe saberlo.
- **Restablecer contraseña, cambiarla y verificar el correo ya no funcionan**:
  el backend no tiene esos endpoints (tarea 017, abierta). La app avisa con un
  mensaje honesto en vez de fingir que envía un correo. Es una pérdida real de
  funcionalidad frente a Firebase.
- **La baja de cuenta es lógica** (`activo = false`), no un borrado. El texto de
  la pantalla se corrigió para no prometer lo que no ocurre.
- **El registro exige contraseñas de 10 a 72 caracteres** y el servidor exige
  18 años; el formulario ya pide lo mismo (`ReglasCuenta` en
  `utils/constantes.dart`).

Siguen en Firestore los otros cinco servicios (`publicacion`, `postulacion`,
`chat`, `calificacion`, `cartera`) y sus pantallas: eso es la fase 2b. Ver
`docs/agent-reports/020-fase2a-auth-contra-el-backend.md`.

**Lo que corrigió la revisión de QA (tarea 022, 2026-08-29)** — tres fallos que
la 020 dejó vivos, los dos primeros reproducidos en el emulador contra el
backend real. Ver `docs/agent-reports/022-revision-qa-de-la-migracion.md`:

- **La renovación de token tiene ahora TRES candados, no dos.** El tercero
  (`ApiClient._esLaSesionActual`) comprueba que la sesión sigue siendo la misma
  al terminar el refresco. Sin él, cerrar sesión mientras había una renovación
  en vuelo **dejaba en el dispositivo una sesión utilizable**: el par recién
  emitido se guardaba y el `logout` de entonces no lo revocaba, porque el
  backend revocaba **solo el token presentado, no la familia**. Al siguiente
  arranque la app entraba sola. **La causa de fondo se cerró el 2026-08-30
  (tarea 024, ADR-0012): el `logout` del backend ya revoca la familia entera.**
  El candado 3 se queda igualmente —sin él la app guardaría tokens de una
  sesión cerrada y solo se enteraría al primer 401, y el caso "aquí ya hay otra
  sesión" el servidor no puede verlo—.
- **`EditarPerfilScreen` ya no edita un perfil que no venga de una lectura
  completa.** Si llega con `cvCargado == false` (lo que pasa al arrancar sin
  conexión, porque el perfil guardado es el del login), pide `GET /api/auth/yo`
  antes de enseñar el formulario; si no puede, lo dice y no deja guardar. Antes
  **borraba la presentación** del servidor mandando `""` y **descartaba en
  silencio** las habilidades escritas, diciendo "Perfil actualizado".
- **`LoginScreen` se protege del doble envío por la tecla "listo"** del teclado
  (`alTerminar` no pasaba por el botón, que sí se desactiva). Dos eventos en el
  mismo frame mandaban dos logins, o sea dos familias de refresh tokens con la
  primera viva y sin revocar.

Y lo que esa revisión comprobó **y estaba bien** (no repetir el trabajo): las
tres barreras del CV funcionan de punta a punta (registro de 5 pasos → cerrar
sesión → entrar → editar, con el CV intacto en la BD en los tres momentos, más
una cuarta barrera en el backend); los candados 1 y 2 de la renovación no se
pudieron romper; el doble/triple toque en los dos registros no duplica nada; el
perfil ajeno oculta correo, DNI, teléfonos, fecha de nacimiento, género, código
postal, RTN y saldo, y ninguna pantalla revienta con esos `null`; y el 429 del
login enseña un mensaje entendible con el tiempo de espera, sin dejar fuera al
dueño legítimo.

**Ramas:** `master` (protegida, = producción) ← `develop` (protegida,
integración) ← `feature|fix|chore|docs/*` (donde trabajan los agentes).

**Build:**
- Flutter: `flutter analyze` limpio (**62 issues**, todas warnings/info
  preexistentes, 0 errores). Bajó de 65 a 62 en la tarea 020, que de paso
  limpió un import muerto y el nombre de un parámetro; **nada de lo escrito en
  las tareas 018 y 020 añade una sola issue**. `flutter test` ARREGLADO
  (2026-08-19, tarea 001, ver `docs/agent-reports/001-fix-widget-test.md`),
  ampliado a 86 (tarea 018, **+82**), a 135 (2026-08-27, tarea 020: **+49**) y
  a **144 tests** (2026-08-29, tarea 022: **+9**). Reparto:
  `test/api/api_client_test.dart` (32: cabecera `Authorization`, traducción de
  los errores de ADR-0008, `Retry-After`, sin conexión, timeout, y **7 sobre
  la serialización del refresco de token**, 3 de ellos contra un backend de
  mentira que revoca la familia igual que el real),
  `test/api/sesion_y_pagina_test.dart` (16: sesión, almacén, página de Spring,
  URL base), `test/models/modelos_json_test.dart` (34: los 7 modelos con JSON
  **copiado del servidor real**),
  `test/services/auth_service_test.dart` (**30**, tarea 020: login con su 429 y
  su 400 por campo, registro, restaurar sesión al arrancar en sus cuatro
  desenlaces, logout que revoca de verdad, `PUT /me`, los tres sub-recursos del
  CV, ranking, perfil ajeno, baja de cuenta y la sesión que muere sola),
  `test/models/perfil_completo_json_test.dart` (**17**, tarea 020: `cvCargado`,
  ids de `Experiencia`/`Estudio`, fecha ISO → dd/MM/aaaa y los campos que el
  perfil ajeno oculta), `test/widget_test.dart` (comprobación mínima de
  `TrabajitApp`) y `test/pantalla_inicial_test.dart` (**5**, reescrito en la
  020: `PantallaInicial` decide entre `LoginScreen`/`InicioScreen`/
  `PantallaCarga` según `sesionActual`. **Ya no suplanta
  `FirebaseAuthPlatform`**: con la sesión en un `ValueNotifier` propio bastan
  tres líneas donde antes hacían falta tres clases falsas. Sigue usando
  `setupFirebaseCoreMocks()` porque `InicioScreen` abre el stream de chats de
  Firestore). La tarea 022 añadió **+9**: `test/api/renovacion_y_sesion_test.dart`
  (4: una renovación en vuelo ya no revive una sesión cerrada ni pisa una
  sesión nueva) y los **primeros tests de pantalla del proyecto**,
  `test/screens/editar_perfil_screen_test.dart` (4) y
  `test/screens/login_screen_test.dart` (1), que inyectan el cliente con
  `ApiClient.fijarInstancia()` y el estado con `sesionActual`.
  **Sigue sin haber tests del resto de pantallas —el registro de 5 pasos, que
  es donde más lógica de guardado hay, solo está probado a mano— ni de los 5
  servicios que quedan en Firestore** — no asumas cobertura donde no se ha
  verificado. Los
  tests de la capa HTTP y de `AuthService` usan `MockClient` de
  `package:http/testing.dart` y un almacén en memoria: **no abren ningún
  socket ni tocan el almacén seguro real**. Y eso último importa más ahora que
  antes: `flutter_secure_storage` **nunca se ha ejecutado de verdad** (no hay
  emulador en el entorno) y desde la tarea 020 es por donde pasa el login.
- Backend: `mvn compile` → `BUILD SUCCESS`. `mvn test` → **BUILD SUCCESS,
  111/111 tests pasan** en la máquina de desarrollo (2026-08-30, tras la tarea
  024: **+8** de `CierreDeSesionHttpTest` —MockMvc + H2: el `logout` revoca la
  familia, un dispositivo no arrastra a los demás, `logout-todos` con y sin
  token de acceso, idempotencia, y el access que sobrevive ≤15 min—, de los que
  **2 fallan si se deshace el arreglo** (comprobado, no supuesto). Antes eran
  103 (2026-08-27, tras la tarea
  019: **+18**, de 85 a 103 — `PerfilCompletoHttpTest` 10 con MockMvc+H2
  (perfil completo de ida y vuelta, CV por sub-recurso, 403 en el ajeno, edad
  mínima, privacidad del perfil público), `CalificacionServiceTest` 5
  (reputación por rol) y `PostulacionServiceTest` 3 (autopostulación → 409).
  Antes, la 015 había subido de 71 a 85). Esos 103 son los que **ejecuta**
  `mvn test -Dtest='!IntegridadCarteraConcurrenteTest'`; si en algún sitio ves
  "77", esa cifra sumaba los 6 de Testcontainers que ese comando excluye. En
  la tarea 009 habían entrado +12 de `MapeoErroresHttpTest`, el **primer test
  de la capa HTTP** del backend — MockMvc + H2, sin Docker, un caso por cada
  error que antes salía como 500. Aparte,
  `IntegridadCarteraConcurrenteTest` (6 tests con Testcontainers) pasa **solo
  en el servidor Ubuntu** — en Windows, Docker Desktop responde 400 al
  cliente de Testcontainers. **Ojo:** si Testcontainers no encuentra Docker,
  esos 6 tests se SALTAN y Maven igual dice `BUILD SUCCESS`; mirar siempre el
  contador de *Skipped*. Reparto de los 103 (22 desde la tarea 003 el
  2026-08-19, ver `docs/agent-reports/003-tests-base-backend.md`; +12 en la
  008, +25 en la 010, +12 en la 009, +14 en la 015): 1 test de contexto
  (`@SpringBootTest` con H2 en memoria, no Postgres/Docker), 11 de
  `AuthService` (incluidos los 4 del freno de fuerza bruta), 40 de
  `TrabajoService` (máquina de estados + escrow + reglas de la 010), 11 de
  `RegistroRolTest` (el registro público no puede crear ADMIN —
  deserialización JSON + Bean Validation), 12 de `MapeoErroresHttpTest`
  (MockMvc sobre H2, mapeo de errores HTTP), 10 de `LoginExigenteHttpTest`
  (MockMvc sobre H2: fuerza bruta, refresh, logout y política de contraseñas) y
  los 18 de la tarea 019 (10 de `PerfilCompletoHttpTest`, también MockMvc sobre
  H2, más 5 de `CalificacionServiceTest` y 3 de `PostulacionServiceTest`); todos
  con Mockito puro salvo el de contexto y los de MockMvc.
  Docker Desktop + Maven ya están instalados en el entorno de este equipo,
  pero los tests actuales NO requieren Docker corriendo.
  Sigue sin haber tests de `PagoService` directo, de los controllers de
  negocio (los `MockMvc` que existen son `MapeoErroresHttpTest` y
  `LoginExigenteHttpTest`, y cubren errores y login, no los flujos), ni de la capa de
  seguridad (`JwtAuthFilter`, etc.) — ver "Pendientes" en los reportes de
  las tareas 003 y 008. **Esos tests no detectan los fallos de la tarea
  006**: son unitarios con Mockito, sin BD, sin transacciones y sin HTTP.
- Integración contra el servidor: `backend/scripts/prueba-flujo-negocio.sh`
  (nuevo, tarea 006). **219** comprobaciones de API + BD con `curl`/`psql`
  contra el backend en marcha; comprueba el dinero, no solo los códigos HTTP.
  Última ejecución (2026-08-30, tras la tarea 024): **219 OK, 0 fallos
  conocidos, 0 inesperados**, y el cuadre contable pasa para los 7 usuarios de
  prueba. La 024 añadió 12 comprobaciones (cierre de sesión por familia,
  `logout-todos`, y que cerrar en un dispositivo no cierre el otro); ninguna
  gasta intentos fallidos del cupo por IP. La 019 añadió 32 comprobaciones (perfil completo, CV, privacidad del
  perfil ajeno y reputación por rol) y cambió a propósito una que ya existía:
  postularse al propio trabajo pasó de 400 a **409**. **Ya no queda ningún fallo conocido marcado**: los de las tareas
  007, 008, 009 y 010 pasaron a ser tests de regresión. La 015 añadió 20
  comprobaciones (freno de fuerza bruta, refresh, logout y política de
  contraseñas). Sale con código 1 solo si aparece un fallo NUEVO. No corre en
  CI (no hay CI). **Ojo al añadir logins fallidos**: el límite por IP (20 en
  15 min) lo comparte todo el script, porque todas sus peticiones salen de la
  misma IP.

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

**Cuando se encontraron, ninguno afectaba a la app** (nadie consumía este
backend). **Eso cambió el 2026-08-27**: desde la tarea 020 la app depende del
módulo `auth`, así que un fallo ahí ya no es teórico. Los cuatro estaban
cerrados antes de conectar nada, que era justo el orden correcto. Con 007-010 cerrados **no queda ningún fallo crítico
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
`security-agent` porque toca `SecurityConfig`; revisada y ampliada por la
015, del propio `security-agent`),
`010-cancelacion-unilateral-tras-la-entrega`,
`019-perfil-completo-y-reputacion-por-rol` (2026-08-27, ADR-0011: perfil
completo del trabajador, reputación por rol y autopostulación bloqueada;
**pendiente de revisión de `security-agent`**, porque cambia qué datos
personales devuelve `GET /api/usuarios/{id}`) y `015-login-exigente`
(2026-08-26, ADR-0010: freno de fuerza bruta, refresh tokens y política de
contraseñas; **pendiente de revisión humana**, no de otro agente: el
`security-agent` es quien la hizo). Siguen en `todo`:
`004-endurecer-metricas-terceros-firestore`,
`011-exposicion-del-servidor-de-pruebas` (hallazgo lateral de la 008: la VM
publica la API en `0.0.0.0:8080`), `012-doble-perfil-trabajador-contratista`,
`013-contratos-y-terminos-del-servicio`,
`014-migracion-de-firebase-al-backend` (épica; **fases 1 y 2a hechas**, ver
`018` y `020`; falta la 2b), `016-fuerza-bruta-distribuida-y-retencion`,
`017-cambio-y-recuperacion-de-contrasena` y
`023-perfil-viejo-sin-conexion-no-se-avisa` (hallazgo de la 022: la app enseña
el perfil viejo sin decir que lo es —`EstadoSesion.avisoSinConexion` no lo lee
ninguna pantalla— y `PerfilTab` no tiene "deslizar para actualizar", así que al
volver la conexión sigue viejo hasta reiniciar la app; la parte destructiva de
esto ya se arregló en la 022).
La `022-revision-qa-de-la-migracion` quedó **`hecho`** (2026-08-29) y la
`024-logout-debe-revocar-la-familia` también (2026-08-30, ADR-0012: el `logout`
del backend revoca la familia entera y hay `POST /api/auth/logout-todos`;
**pendiente de revisión humana**, no de otro agente: la hizo el
`security-agent`). Esa dejó una tarea nueva en `todo`:
`025-cerrar-sesion-en-todos-los-dispositivos` (el endpoint no tiene botón en la
app; además `DELETE /api/usuarios/me` no revoca las sesiones y el futuro cambio
de contraseña tendrá que hacerlo). Las dos últimas eran hallazgos de la
015 (la IP que ve el backend es la del gateway de Docker, y **no existe ningún
endpoint para cambiar o recuperar la contraseña**) y **la 017 subió de
prioridad con la tarea 020**: ahora que Firebase Auth no está, un usuario que
olvide su contraseña **no tiene forma de recuperarla dentro de la app**. Es una
pérdida de funcionalidad real frente a lo que había. También quedaron
`hecho` `018-fase1-cimientos-cliente-http` y
`020-fase2a-auth-contra-el-backend` (las dos del 2026-08-27 y las dos
**pendientes de revisión de `security-agent`**: tocan el almacenamiento del
token, el ciclo de sesión y qué se manda en `PUT /api/usuarios/me`). La 020
deja abierta la **fase 2b**: migrar los cinco servicios que siguen en
Firestore.

**El hallazgo de la 018 que BLOQUEABA la fase 2 — RESUELTO el 2026-08-27 (tarea
019, ADR-0011).** El backend ya guarda el perfil completo del trabajador: a
`usuarios` se le añadieron **14 columnas** (`telefono_emergencia`,
`fecha_nacimiento`, `genero`, `vive_en_honduras`, `codigo_postal`, `pais`,
`url_cv`, `registro_completo`, `cargo_contacto`, `descripcion_empresa` y las 4
de reputación por rol) y aparecieron **3 tablas** con clave ajena real a
`usuarios`: `habilidades`, `experiencias` y `estudios` —las primeras FK del
esquema, el resto sigue referenciando por UUID suelto—. `rtn`, `activo` y
`creadoEn` ya se exponen; `estado` y `fechaRegistro` **no necesitaban columna**
(son `activo` y `creadoEn`). Además: **dos reputaciones separadas por rol**
(`calificacionComoTrabajador` / `calificacionComoEmpleador`, con
`Calificacion.rolCalificado`; la media global se conserva), **la edad mínima de
18 años ya la exige el servidor** (antes solo la pantalla de Flutter), y
**postularse al propio trabajo responde 409** (ya se bloqueaba, pero con 400).
De paso se cerró un agujero de privacidad previo: `GET /api/usuarios/{id}`
devolvía el **saldo** de cualquiera; ahora hay vista de dueño y vista pública, y
la pública oculta correo, DNI, teléfonos, fecha de nacimiento, género, código
postal, RTN y saldo. Ver `docs/agent-reports/019-perfil-completo-y-reputacion-por-rol.md`.

**Lo que SIGUE faltando para la fase 2b** (la 2a ya no lo necesitaba): no existe
entidad, tabla ni endpoint de **tarjetas** (`/api/cartera` solo tiene `recargar`
y `movimientos`); faltan los campos desnormalizados que las listas de Firestore
usaban (`tituloTrabajo`/`empleadorId` en `Postulacion`, `autorNombre` en
`Calificacion`) y un contador de **no leídos por chat** (el backend marca
`leido` mensaje a mensaje). **Y hace falta un listado de trabajadores de
verdad** (hallazgo de la 020): la única lista de personas que hay es
`GET /api/usuarios/ranking`, topada en 50, ordenada por trabajos completados y
sin CV, así que sirve de ranking pero no de directorio con búsqueda.

Los tres avisos de contrato de la 019 **ya están resueltos en el cliente**
(tarea 020) y se dejan escritos porque la fase 2b se los volverá a encontrar:
`fechaNacimiento` llega en **ISO** (entra en `dd/MM/yyyy` o ISO), las tres listas
del CV llegan **`null`** en login/registro/ranking (`null` = "no viene en esta
respuesta", no "no tiene"; el perfil entero está en `GET /api/auth/yo`), y el
perfil de otra persona ya no trae correo, DNI ni teléfonos. Detalle en
`docs/api.md` → "Perfil completo y reputación por rol".

**Estado de la BD del servidor de pruebas:** tras la tarea 006 contiene
usuarios con el saldo descuadrado a propósito (para dejar la evidencia) y
5 cuentas ADMIN de prueba auto-registradas, que la tarea 008 dejó con
`activo=false` (no se borraron, para no destruir la evidencia de los reportes
006 y 008; el SQL para revertirlo está en el reporte 008). Todas las cuentas
que crea el script de QA usan la misma contraseña conocida. No es una BD
limpia ni un entorno de confianza; tenlo en cuenta si vas a probar ahí.

**Nuevo en el servidor de pruebas (tarea 020):** cuentas `f020a`, `f020b` (con
CV completo: habilidades, experiencia y estudios) y `f020d`, esta última **dada
de baja a propósito** para comprobar que `DELETE /api/usuarios/me` desactiva y
que el login posterior responde 401. Se gastaron 2 intentos fallidos del cupo
por IP. **La VM dejó de responder por SSH** mientras se cerraba la tarea 020
(`kex_exchange_identification` y luego tiempo agotado en el saludo, tras nueve
reintentos); si te la encuentras caída, no es cosa tuya. El guion de
verificación de punta a punta quedó listo pero **sin ejecutar entero** en
`docs/agent-reports/scripts/020-verificar-auth-contra-el-backend.sh`.

**Nuevo en el servidor de pruebas (tarea 019):** las tablas `habilidades`,
`experiencias` y `estudios` (con FK a `usuarios`), 14 columnas nuevas en
`usuarios` y `rol_calificado` en `calificaciones`. Al arrancar, el componente
`RellenoPerfilYReputacion` clasificó las **20 calificaciones antiguas** (10 como
trabajador, 10 como contratista) y recalculó las medias por rol; es idempotente.
La 019 dejó ahí ~4 cuentas de prueba más (`qa.perfil.*`, `demo19*`).

**Nuevo en el servidor de pruebas (tarea 015):** las tablas `intentos_login` y
`refresh_tokens`. `intentos_login` se vació a mano durante las pruebas de la
015 (eran filas de esas mismas pruebas). Si haces logins fallidos ahí, ten en
cuenta que el cupo por IP (20 en 15 min) lo comparte todo lo que salga del
host, porque la API los ve a todos como `172.18.0.1` (ver tarea 016).
La tarea 018 dejó ahí 5 cuentas `f018*@trabajito.test` y 1 trabajo de prueba,
y gastó ~6 intentos fallidos de ese cupo.

**Cómo se apunta la app al backend (tarea 018):**
`--dart-define=TRABAJITO_API_URL=...` al compilar, o
`ApiClient.cambiarUrlBase()` en caliente (se guarda en el dispositivo y manda
sobre el dart-define). Sin nada configurado, el valor por defecto es
`http://10.0.2.2:8080` en Android (el alias del `localhost` del PC visto desde
el emulador) y `http://localhost:8080` en el resto. Las builds de **debug**
permiten HTTP sin TLS vía
`android/app/src/debug/res/xml/network_security_config.xml`; las de release
**no**, y no deben. Detalle en `docs/development.md` → "Apuntar la app al
backend (URL base)". **Esto ya SÍ se ha probado en un emulador de verdad**
(2026-08-29, tarea 022; antes, en la 018 y la 020, no había ninguno
disponible): APK de debug con `--dart-define=TRABAJITO_API_URL=http://10.0.2.2:8080`
en el **Pixel_6 (Android 13)** contra el backend de la VM, con el recorrido
completo de registro en 5 pasos, cierre de sesión, login, edición de perfil y
arranque en modo avión. **`flutter_secure_storage` funciona**: la sesión
sobrevive a `am force-stop` y a un arranque sin conexión. Usar el **Pixel_6**,
no el Pixel_9 (Android 17 preview: lentísimo, con bloqueos que no son de la
app).

**Flyway/Liquibase: propuesto, NO implementado (ADR-0011).** Ya son **tres** los
componentes de arranque que hacen de sistema de migraciones
(`RestriccionSaldoNoNegativo`, `RestriccionEstadoTrabajo` y, desde la 019,
`RellenoPerfilYReputacion`, que además toca *datos*, no solo constraints).
`ddl-auto=update` no altera constraints existentes **ni** puede añadir columnas
`NOT NULL` a una tabla con filas — por eso las columnas nuevas llevan
`` y no `nullable = false`. Nada de esto se ve en los tests: H2 usa
`create-drop`. Debería entrar como tarea propia antes de que la fase 2 ponga
datos reales de usuarios en esa base.

**Infra (2026-08-20):** `backend/docker-compose.yml` ya levanta `db` **y**
`api` (el servicio `api` estaba comentado hasta la tarea 005). `JWT_SECRET`
es ahora una variable **requerida**: sin `backend/.env` cualquier comando de
compose falla a propósito, incluso `up -d db`. Sigue sin haber CI que corra
tests en cada PR (`.github/workflows/claude.yml` no es CI).

**Nuevo en el servidor de pruebas (tarea 024, 2026-08-30):** la VM
`TrabajitoTestServer` estaba **apagada** al empezar la tarea (SSH: `Connection
refused`, el puerto 2222 ni siquiera escuchaba) y se arrancó con
`VBoxManage startvm ... --type headless` — sí está instalado en este equipo,
en `C:\Program Files\Oracle\VirtualBox\`. **Queda encendida y con la rama
`security/logout-revoca-familia` desplegada**, no `develop`. Cuentas nuevas:
`qa024.*@trabajito.test` (tres familias de refresh tokens, todas revocadas a
propósito) y las `qa.sesion.*` que crea el script de regresión. No se gastó
ningún intento fallido del cupo por IP. **Aviso para quien despliegue ahí:** la
IPv6 de esa VM no sale a internet (dirección ULA de la NAT de VirtualBox,
`curl -6` → 000, `curl -4` → 200), así que `docker compose build` puede morir
en `load metadata for eclipse-temurin:17-jre-alpine`; se arregla con un
`docker pull eclipse-temurin:17-jre-alpine` (a la tercera entró por IPv4) y
reintentando. **No hay `sudo` sin contraseña** en esa VM, así que no se puede
tocar `/etc/docker/daemon.json` ni `/etc/hosts`.

**Nuevo en el servidor de pruebas (tarea 022):** la cuenta
`qa022a@trabajito.test` (trabajadora, Tegucigalpa) con CV completo —3
habilidades, 1 experiencia, 1 estudio— y la presentación
`"Presentacion QA que no se debe borrar"`, puesta a propósito para detectar
borrados en futuras pruebas. Se gastaron **~7 intentos fallidos** del cupo por
IP (20 en 15 min) provocando el 429 del login a conciencia. No se borró ni
modificó nada preexistente.
