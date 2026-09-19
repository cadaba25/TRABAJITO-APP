# Retomar aquí — 2026-09-18

Nota de traspaso para arrancar una sesión nueva **sin releer ninguna
conversación anterior**. Solo dice **dónde estamos y qué sigue**.

Detalle de qué existe hoy: `repo-snapshot.md`. Porqué de cada decisión:
`docs/decisions.md` (en especial ADR-0018 y ADR-0019).

## Dónde estamos

**`develop` con las tareas 051-060 integradas.**
El objetivo era una demo de flujos completos, y el código ya está: la app ya no
habla con Firestore ni con Firebase.

- **Firestore/Firebase fuera de `lib/` y de `pubspec.yaml`** (ADR-0019, tarea
  060). Cartera y calificaciones migraron a la API (052), el chat también (053).
  `lib/screens/` y `lib/services/` ya no existen. Quedan `firestore.rules`,
  `firestore.indexes.json` y el proyecto Firebase: los borra la **fase 3**.
- **Chat por REST con sondeo** (ADR-0018). STOMP queda como mejora futura
  (tiempo real), sin cambiar los contratos REST. Contrato del chat:
  `docs/agent-reports/054-backend-chat-contrato.md` y `docs/api.md`.
- **WebSocket `/ws` autorizado**: el `CONNECT` exige JWT (tarea 030) y el
  `SUBSCRIBE` solo deja entrar a `/topic/chats/{uuid}` si eres participante de
  ese chat (tarea 057). No se filtra `SEND` a `/app/**` (no hay handlers).
- **`reservar-pago` valida el acuerdo del chat** en el servidor (055): sin
  acuerdo -> 409, monto o tiempo distintos -> 400. Cierra la costura que
  quedaba entre las dos mitades.
- **El pago del chat es un monto total, no una tarifa por hora** (decisión del
  dueño). La app dice "en total"; el texto de sistema del backend se corrigió
  en la tarea 059.

## Pull requests (#20 a #31 ya mergeados a `develop`, 2026-09-18)

Repositorio: `https://github.com/cadaba25/TRABAJITO-APP/pull/N`, N = 20 a 31.

**Orden de merge: #21, #22, #25, #26, #27, #23, #28, #29, #30, #31.**
El #20 es independiente. El #29 es el de textos de pago total en el backend; el
#30 retira Firebase; el #31 es el reporte QA (058).

## Qué se verificó de verdad y qué no

**Verificado (2026-09-18, ejecutado, no asumido):**
- `backend/scripts/prueba-flujo-negocio.sh`: **222 OK**, 0 fallos.
- Backend: **147 tests, 0 skipped**, con Docker corriendo (Testcontainers sí
  corrió: `IntegridadCarteraConcurrenteTest` 8/8).
- Flutter: **350 tests** pasan. `flutter analyze`: 8 issues, 0 errores.
- `flutter build apk --debug` compila.
- La app abre contra el backend real en `Pixel_6` (10.0.2.2): sesión abierta y
  feed con trabajos del backend.

**NO verificado:**
- **El flujo completo por la UI del emulador** (proponer/aceptar en el chat,
  reservar pago, evidencia, liberar, calificar, cartera). Se probó por API y con
  tests de widgets. No hay tests `integration_test`.
- El **sondeo del chat en vivo** (solo el contrato del endpoint).
- **STOMP en vivo** (solo tests unitarios del interceptor).
- **`mvn` con JDK 17**: todo el backend se corrió con JDK 24 y estos flags:
  `-Dmaven.compiler.proc=full -Dlombok.version=1.18.40
  -DargLine=-Dnet.bytebuddy.experimental=true`.

## Pendientes

- **Pasada manual del flujo completo en el emulador** (lo que convierte la demo
  en "flujos completos" demostrados).
- Cambiar y recuperar contraseña (017; regresión real frente a Firebase).
- "Cerrar sesión en todos los dispositivos": el endpoint existe, no hay botón.
- CI (nadie corre los tests en un PR; el techo de 300 líneas de ADR-0014 no lo
  vigila nadie).
- Fase 3: borrar `firestore.rules`, `firestore.indexes.json` y el proyecto
  Firebase (con revisión de security-agent).
- DTOs propios para `ChatRoom`, `Mensaje` y `MovimientoCartera` (hoy el
  contrato expone parte de la entidad).
- Paginación de mensajes del chat.
- Ruido de Surefire: `Surefire is going to kill self fork JVM` (System.exit
  tarda 30 s). Los reportes salen completos y sin fallos, pero hay que
  investigarlo.
- Confirmar que el PR #8 (tarea 030) está desplegado en la VM.
- STOMP/tiempo real para el chat, como mejora posterior.
- Observación menor de QA: el `creadoEn` del `POST mensajes` trae nanosegundos y
  los GET microsegundos; usar siempre el del GET como cursor `desde`.

## Lo que hay que saber y no se deduce del código

- **El feed pagina con `pagina`/`tamano`, no `page`/`size`.** Mandar los
  equivocados **no da error**: se ignoran y devuelven siempre la página 0.
  `ApiClient.obtenerPagina` manda los equivocados; hoy no rompe nada porque
  `listarFeed` va por otro camino.
- **Traer mensajes NO los marca leídos**: el cliente debe llamar a
  `POST /api/chats/{id}/leido`.
- **`gestor_sesion.dart` tiene 314 líneas a propósito**, por encima del techo de
  ADR-0014. Partir `peticionConReintento` de `_renovar` separaría las dos mitades
  del **candado 2** y resucitaría un fallo real ya arreglado en la tarea 022.
- **`ddl-auto=update` NO altera constraints existentes.** Causó dos incidentes
  reales. El apaño son componentes de arranque (`RestriccionSaldoNoNegativo`,
  `RestriccionEstadoTrabajo`).
- **Testcontainers puede saltarse en silencio**: `BUILD SUCCESS` con `Skipped: N`
  parece verde y no probó nada. Míralo siempre; hace falta Docker.
- **Los `generated_plugin_registrant` de linux/macos/windows** que regenera
  `flutter pub get` pueden seguir listando plugins Firebase; se revierten y no
  van en commits (se regeneran en cada máquina).
- **`prueba-flujo-negocio.sh` requiere `jq`** y, desde la tarea 055, todo
  `reservar-pago` necesita antes un acuerdo de pago y tiempo en el chat.
- **Emulador: usar `Pixel_6`** (Android 13), no `Pixel_9` (Android 17 preview,
  da ANR). `flutter emulators --launch Pixel_6`.
- **Los tests unitarios con Mockito no detectaron ninguno de los 4 fallos graves
  de la tarea 006.** Para el backend, la prueba que vale es
  `backend/scripts/prueba-flujo-negocio.sh`.

## Método que ha funcionado

**Verificar por cuenta propia lo que reporta un agente.** La forma más barata y
contundente: **romper el código a propósito y ver si el test se pone rojo**. En
la 058, correr el script real cazó dos secciones desactualizadas que reportaban
una REGRESION falsa.

## Problemas abiertos, por gravedad

**Seguridad:** no existe cambiar ni recuperar contraseña (017) · nadie llega a
"cerrar sesión en todos los dispositivos" (025) · el límite por IP cuenta a todos
como uno detrás de Docker (016) · servidor de pruebas en `0.0.0.0` con
`CORS_ORIGINS=*` (011) · un token válido que caduca a mitad de una conexión
WebSocket no se revalida.

**Funcional:** el flujo económico completo nunca se ha ejecutado a mano en la
app · borrar una publicación y reabrir un trabajo cerrado no existen · las
reputaciones por rol llegan del backend y la app no las lee · disputas sin motivo
ni resolución en pantalla · evidencias sin fotos · doble rol (012) sin plan ·
contratos (013) **en pausa por decisión del dueño**.

**Proceso:** **no hay CI** · faltan tests de varias pantallas · el archivo
`detalle_trabajo_screen.dart` (1232 líneas, excepción aceptada en la 050) sigue
pendiente de partir en subwidgets.
