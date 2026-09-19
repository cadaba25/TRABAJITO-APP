---
id: 030
tarea: docs/agent-tasks/030-backend-tarjetas-y-websocket-jwt.md
agente: "backend-agent"
fecha: 2026-09-10
---

## Objetivo (copiado de la tarea)

Dos huecos independientes del backend que bloquean la fase 2b-2 (migrar
`cartera_service` y `calificacion_service` de Firestore a la API) y la
migración del chat:

- **Parte A** — endpoint mínimo de tarjetas guardadas en `/api/cartera`.
- **Parte B** — validar el JWT en el `CONNECT` de STOMP/WebSocket (`/ws`),
  cerrando un `TODO` de seguridad abierto desde hace varias tareas.

## Cambios realizados

### Parte A — Tarjetas

- Entidad `Tarjeta` (tabla `tarjetas`), con FK **real** a `usuarios`
  (`fk_tarjetas_usuario`), siguiendo el patrón que introdujo la tarea 019
  para `Habilidad`/`Experiencia`/`Estudio` (no el resto del esquema, que usa
  UUID suelto). Campos: `marca`, `ultimos4`, `titular`, `vencimiento`
  (texto libre `MM/AA`, sin validar como fecha real) + `id`/`creado_en`
  heredados de `BaseEntity`. **Nunca** hay columna para el número completo
  ni el CVV.
- `TarjetaRepository`, `TarjetaService` y `TarjetaController` en
  `com.trabajito.modules.pagos` (junto a `PagoService`/`MovimientoCartera`,
  que ya vive en ese módulo).
- Endpoints bajo `/api/cartera/tarjetas`:
  - `GET` — lista solo las propias (id sale del JWT).
  - `POST` — recibe `{"numero","titular","vencimiento","marca"?}`. El
    servidor repite la validación que ya hacía el cliente (≥13 dígitos),
    calcula `ultimos4` y, si no viene `marca`, la deduce del número (mismo
    algoritmo que `Tarjeta.marcaDesdeNumero` en Flutter). El número completo
    nunca se persiste ni se devuelve.
  - `DELETE /{id}` — 200 si es propia; **404** (no 403) si es ajena o no
    existe, mismo código en los dos casos para no revelar cuál — así lo
    pedía la tarea explícitamente, aunque el resto del perfil
    (`PerfilService`, experiencia/estudios) usa 403 para lo mismo. Es una
    inconsistencia deliberada de la tarea, no un descuido; lo dejo anotado
    por si `security-agent` quiere unificar criterio más adelante.
  - Tope defensivo de 20 tarjetas por usuario (mismo patrón que `MAX_ESTUDIOS`
    etc. en `PerfilService`, no pedido explícitamente pero barato y
    consistente con el resto del código).
- Documentado en `docs/api.md` (sección nueva "Tarjetas de la cartera"),
  `backend/README.md` (tabla de `/api/cartera`) y `docs/database.md` (entidad
  nueva, FK nueva, se resolvió el punto "no existe entidad ni tabla de
  tarjetas" de la lista de diferencias con Firestore).

### Parte B — JWT en el CONNECT de WebSocket

- `StompAuthChannelInterceptor` (nuevo, en `com.trabajito.security`): un
  `ChannelInterceptor` registrado en el canal de entrada
  (`configureClientInboundChannel` de `WebSocketConfig`) que, solo para el
  frame `CONNECT`, exige el token de acceso en el header STOMP **nativo**
  `Authorization: Bearer <token>` (o `token: <token>` como alternativa) y lo
  valida con `JwtService.esValido()` + `extraerUsuarioId()` — la misma
  validación que usa `JwtAuthFilter` para HTTP — y comprueba que el usuario
  exista y esté `activo`, igual que ese filtro. Si algo falla, lanza
  `StompAuthException` (nueva, `RuntimeException` simple), que Spring
  propaga como error del canal: el cliente recibe un frame STOMP `ERROR` y
  la conexión se cierra sin llegar al broker.
- `WebSocketConfig`: se quitó el `TODO`, se inyecta el interceptor y se
  registra en `configureClientInboundChannel`. El handshake HTTP a `/ws`
  sigue siendo público (`SecurityConfig` no se tocó — sigue permitiendo
  `/ws/**`, que es requisito de SockJS).
- El usuario validado queda como `Principal` de la sesión STOMP
  (`accessor.setUser(...)`, envuelto en un `UsernamePasswordAuthenticationToken`
  porque `UsuarioPrincipal` no implementa `java.security.Principal`), por si
  un futuro handler de mensajería (la tarea de migración del chat) lo
  necesita — no se usa todavía porque no hay `@MessageMapping` en este
  backend aparte de los `@RestController` existentes.
- **Fuera de alcance a propósito, tal como decía la tarea**: no se revalida
  un token que caduca a mitad de sesión (la conexión sigue abierta hasta que
  el cliente la cierre). Queda anotado en el Javadoc de la clase y en
  `docs/api.md`.

## Archivos modificados

- `backend/src/main/java/com/trabajito/modules/pagos/Tarjeta.java` (nuevo)
- `backend/src/main/java/com/trabajito/modules/pagos/TarjetaRepository.java` (nuevo)
- `backend/src/main/java/com/trabajito/modules/pagos/TarjetaService.java` (nuevo)
- `backend/src/main/java/com/trabajito/modules/pagos/TarjetaController.java` (nuevo)
- `backend/src/main/java/com/trabajito/modules/pagos/dto/TarjetaRequest.java` (nuevo)
- `backend/src/main/java/com/trabajito/modules/pagos/dto/TarjetaResponse.java` (nuevo)
- `backend/src/test/java/com/trabajito/modules/pagos/TarjetaHttpTest.java` (nuevo, 6 tests)
- `backend/src/main/java/com/trabajito/security/StompAuthChannelInterceptor.java` (nuevo)
- `backend/src/main/java/com/trabajito/security/StompAuthException.java` (nuevo)
- `backend/src/main/java/com/trabajito/config/WebSocketConfig.java` (editado: quita el TODO, registra el interceptor)
- `backend/src/test/java/com/trabajito/config/WebSocketAuthTest.java` (nuevo, 3 tests)
- `docs/api.md` (secciones "Tarjetas de la cartera" y "WebSocket `/ws`: el CONNECT ahora exige JWT")
- `backend/README.md` (tabla de `/api/cartera`, nota de tiempo real del chat, pendientes)
- `docs/database.md` (entidad `Tarjeta`, FK `fk_tarjetas_usuario`, se resuelve un punto de "diferencias a resolver antes de migrar")
- `docs/agent-tasks/030-backend-tarjetas-y-websocket-jwt.md` (creada, primer commit de la rama)

No se tocó `lib/**`, `SecurityConfig.java` ni ningún `Dockerfile`/`docker-compose.yml`.

## Decisiones tomadas

- **404 en vez de 403 para tarjetas ajenas**, siguiendo la letra de la tarea,
  aunque el resto del código de perfil (`PerfilService`) usa 403 para
  experiencia/estudios ajenos. No unifiqué criterio porque cambiar eso es
  fuera del alcance de esta tarea y tocaría un contrato ya cubierto por
  tests existentes (`PerfilCompletoHttpTest`).
- **El request de tarjeta recibe el número completo transitoriamente**
  (`TarjetaRequest.numero`), igual que hace hoy `CarteraService.agregarTarjeta`
  en Flutter/Firestore, en vez de exigir que el cliente ya mande solo
  `ultimos4`. Así el servidor puede repetir la validación (≥13 dígitos) y
  deducir la marca él mismo si el cliente no la manda, sin depender de que
  el cliente calcule bien; el número nunca se persiste ni sale en la
  respuesta (`TarjetaResponse` no tiene ese campo, y hay un test que lo
  comprueba: `agregarYListar` verifica `t.has("numero")` es `false`).
- **`TarjetaController` separado de `PagoController`**, aunque comparten
  prefijo `/api/cartera`: cada uno mapea su propio sub-recurso
  (`/api/cartera/tarjetas` vs `/recargar`/`/movimientos`), más fácil de leer
  que meter todo en un solo controller.
- **Cliente STOMP de test: `SockJsClient`, no `StandardWebSocketClient` a
  secas.** El primer intento usó `WebSocketStompClient` directo con
  `StandardWebSocketClient()`, y los tres tests "pasaban", pero con
  logging temporal confirmé que el `preSend` del interceptor **nunca se
  ejecutaba** — la conexión fallaba a nivel de transporte antes de llegar al
  STOMP `CONNECT`, así que los dos tests de "rechazado" eran falsos positivos
  (fallaban por cualquier motivo, no por el arreglo) y el de "aceptado"
  colgaba hasta el timeout. `WebSocketConfig` registra el endpoint con
  `.withSockJS()`, así que hace falta negociar ese protocolo:
  `SockJsClient` + `WebSocketTransport(new StandardWebSocketClient())`.
  Con ese cambio, los tres tests reflejan lo que dicen medir (ver la
  comprobación rojo/verde en la siguiente sección). Ambas clases ya estaban
  en el classpath (`spring-boot-starter-websocket`), no hubo que añadir
  ninguna dependencia.
- **Tope de 20 tarjetas por usuario** (`TarjetaService.MAX_TARJETAS`): no lo
  pedía la tarea, lo añadí por el mismo motivo que `PerfilService` limita
  experiencias/estudios (que esto no se use como almacén de texto arbitrario).
  Si se considera fuera de alcance, es trivial de quitar.

## Problemas encontrados

- El primer diseño del test de WebSocket daba **falsos positivos** (ver
  arriba) — lo detecté solo porque agregué logging temporal dentro del
  interceptor y noté que nunca se imprimía nada ni para el caso "sin token"
  ni para el "con token". Lo dejo documentado porque es una trampa fácil de
  repetir: un test de WebSocket que "pasa" verificando solo
  `handleTransportError` sin confirmar que el mensaje realmente llegó al
  servidor puede estar midiendo un fallo de transporte, no el
  comportamiento de la aplicación.
- `docs/api.md` y `backend/README.md` terminaron en el commit de la Parte A
  en vez de repartidos entre A y B, porque edité ambas secciones (tarjetas y
  WebSocket) en el mismo archivo antes del primer commit. El contenido es
  correcto para las dos partes; solo el reparto de commits no quedó tan
  limpio como pretendía el plan original ("commits separados, misma rama").
  No lo deshice para no reescribir historia con un rebase innecesario.
- `docs/database.md` (`## 2. PostgreSQL vía JPA (DISEÑADO, NO EN USO)`) sigue
  con un encabezado desactualizado — según `CLAUDE.md` (2026-09-09) el
  backend ya es la fuente de verdad real para usuarios/perfil, trabajos,
  postulaciones y evidencias, no un diseño sin usar. No lo corregí porque es
  una discrepancia preexistente y más amplia que esta tarea (dominio de
  `docs-agent`); solo añadí las filas/notas puntuales de `tarjetas` pedidas
  por los criterios de aceptación.

## Tests ejecutados

Entorno: Maven 3.9.16 + JDK 21 (JetBrains Runtime) disponibles localmente
(`mvn`/`java` sí funcionan en este worktree, a diferencia de lo que advierte
la plantilla de tarea por si no estuvieran). Todo corrido en modo offline
(`-o`) contra el repositorio Maven local ya poblado.

- `mvn -o compile` → **BUILD SUCCESS**, sin errores ni warnings nuevos.
- `mvn -o test -Dtest=TarjetaHttpTest` → **6/6 OK** (creación con
  últimos4/marca correctos y sin exponer `numero`; listado propio; listado
  no muestra tarjetas ajenas; número corto → 400; borrado propio → 200 y
  desaparece; borrado ajeno → 404; borrado inexistente → 404).
- `mvn -o test -Dtest=WebSocketAuthTest` → **3/3 OK** (sin token rechazado;
  con token válido aceptado; usuario `activo=false` rechazado).
  **Verificación rojo/verde explícita** (pedida por los criterios de
  aceptación): comenté temporalmente el registro del interceptor en
  `configureClientInboundChannel` (dejando el resto igual) y volví a correr
  — resultado: **2 de 3 fallan** (`sinTokenRechazado` y
  `usuarioInactivoRechazado`; el de token válido sigue pasando, como se
  espera si no hay validación). Restauré el registro del interceptor y
  confirmé que vuelve a dar **3/3 OK** antes de comitear.
- `mvn -o test` (suite completa) → **BUILD SUCCESS**, **128 tests, 0
  failures, 0 errors, 8 skipped**. Los 8 *skipped* son
  `IntegridadCarteraConcurrenteTest` (Testcontainers, `disabledWithoutDocker
  = true`): confirmado que es el mismo salto documentado en tareas
  anteriores para Windows sin Docker corriendo para ese cliente concreto, no
  algo nuevo de esta tarea. No hay ningún test fallando ni roto por los
  cambios de esta tarea; los 128 incluyen tests preexistentes de otras
  tareas ya en `develop` (p. ej. `CierreDeSesionHttpTest`, no mencionado en
  el snapshot que leí al empezar — el snapshot estaba desactualizado
  respecto a `develop`, tal como advierte la propia regla de oro 2 de
  `CLAUDE.md`).

No se desplegó nada en la VM de pruebas — no hace falta para esta tarea (sin
consumidor real todavía), tal como permite el propio criterio de aceptación.

## Pendientes

- Un token de acceso válido que caduca **a mitad de una sesión WebSocket ya
  abierta** no se revalida (queda abierta hasta que el cliente la cierre).
  Documentado como fuera de alcance en el Javadoc de
  `StompAuthChannelInterceptor` y en `docs/api.md`; queda para la tarea que
  migre el chat de Firestore, que sí necesitará handlers `@MessageMapping`
  reales.
- Los STOMP handlers de mensajería (`/app/chats/{chatId}/enviar`, etc.) no
  existen todavía — esta tarea era solo cerrar el agujero de autenticación
  del transporte, tal como pedía explícitamente el alcance.
- ~~La inconsistencia 403 vs 404 para recursos ajenos entre `PerfilService`
  (experiencia/estudios → 403) y `TarjetaService` (tarjetas → 404) queda sin
  resolver; anotada arriba por si se quiere unificar criterio en una tarea
  de `security-agent`.~~ **Resuelto en revisión de security-agent
  (2026-09-10, misma tarea 030, antes del PR):** el patrón dominante y real
  en todo el backend (`PerfilService`, `PostulacionService`, `ChatService`)
  es 404 solo si el id no existe y 403 si existe pero es de otro usuario.
  `TarjetaService.borrar` se corrigió a ese criterio (403 para tarjeta
  ajena, 404 solo para inexistente); se actualizó `TarjetaHttpTest`
  (`borrarAjenaDa404` → `borrarAjenaDa403`), el Javadoc de
  `TarjetaService`/`TarjetaController` y `docs/api.md`. Resto de la revisión
  de security-agent (WebSocket CONNECT, manejo de número/CVV, ownership de
  endpoints, secretos en logs): APTO sin más hallazgos — ver el mensaje de
  cierre de esa revisión para el detalle.
- El encabezado desactualizado de `docs/database.md` ("PostgreSQL vía JPA
  (DISEÑADO, NO EN USO)") no se corrigió; es una discrepancia con
  `CLAUDE.md` más amplia que el alcance de esta tarea.
