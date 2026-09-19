# Reporte 053: el chat pasa a la API REST con sondeo

Rama `feature/053-chat-a-api` (desde `feature/052-cartera-calificacion-api`). Estado: en-revision. Sin push ni merge.

## Qué se hizo

- **`ChatService` nuevo** en `lib/funcionalidades/chat/datos/` (contra `/api/chats/**`, ADR-0018): `misChats()` (lista + `no-leidos` unidos, ordenada), `totalNoLeidos()`, `obtenerChat(id)`, `chatDeTrabajo(trabajoId)` (404 -> `null`), `mensajes(chatId, {desde})`, `enviarMensaje`, `marcarLeido` (best-effort), `proponerPago/aceptarPago/proponerTiempo/aceptarTiempo`. Lecturas lanzan `ExcepcionApi`; acciones devuelven `String?` como el resto de servicios migrados. Sin `asegurarChat`: el chat lo crea el backend al aceptar la postulación.
- **Modelos `Chat`/`Mensaje`** movidos a `funcionalidades/chat/datos/chat.dart`, solo `desdeJson` (campos `contenido`/`creadoEn`, `tipo` en MAYÚSCULAS, nulls -> `''`). `participantes` desaparece; `noLeidos` pasa de mapa a `int` que rellena el servicio (`conNoLeidos`). Nuevo `acuerdoCompleto`.
- **Sondeo**: `lib/compartido/sondeo/sondeo_periodico.dart` (`Timer.periodic`, sin solapes, pausado con la app en segundo plano y tic inmediato al volver, `detener()` en `dispose`). Chat abierto cada 3 s (`GET /{id}` + `mensajes?desde=` incremental, dedupe por id porque `desde` se trunca a microsegundos), lista de chats cada 5 s, badge de no leídos en `InicioScreen` cada 10 s.
- **Pantallas** movidas con `git mv` a `funcionalidades/chat/pantallas/` y partidas: `chat_screen.dart` (494 -> 183 líneas), `chats_tab.dart` (220), y `widgets/` `panel_negociacion`, `burbuja_mensaje`, `barra_envio`, `dialogos_negociacion`. Servicio recibido con `context.read<ChatService>()`; registrado en `proveedoresDeLaApp(chats:)`.
- **`DetalleTrabajoScreen`**: `_reservarPago` lee el acuerdo con `GET /api/chats/trabajo/{id}`, exige `pagoAcordado && tiempoAcordado` (y monto > 0 / tiempo no vacío) y manda `monto=pagoMonto`, `tiempo=tiempoValor`. "Abrir chat" ya no fabrica un `Chat` local con el id del trabajo: lo resuelve con `chatDeTrabajo` y, si es 404, avisa "El chat de este trabajo aún no está disponible".
- **Eliminado**: `lib/services/chat_service.dart`, `lib/services/firestore_colecciones.dart` (`lib/services/` desaparece), y `desdeFirestore()`/`aFirestore()` de `Usuario`, `Publicacion`, `Postulacion`, `Evidencia`. **`grep -r cloud_firestore lib test` = vacío.**
- `RutasApi`: rutas de chat añadidas. `pantalla_inicial_test.dart` ya no monta mocks de Firebase (no hacen falta).

## Cifras reales

- `flutter test`: **350 pasan, 0 fallan** (baseline 315; +35: 10 servicio, 14 pantallas chat/lista, 4 sondeo, 6 detalle reservar-pago/abrir chat, +1 neto en modelos tras reescribir 3 tests de `Chat`).
- `flutter analyze`: **8 issues, 0 errores**, todos preexistentes (baseline 11; los tres `withOpacity` del código movido se limpiaron al mover). Un warning ajeno (`bienvenida_registro_screen.dart`) sigue.
- Tests existentes modificados: `test/models/modelos_json_test.dart` (3 tests de `Chat` que afirmaban `participantes`/`noLeidos` como mapa, ya inexistentes: estaban desactualizados por el cambio, no el cambio mal) y `test/pantalla_inicial_test.dart` (quitados los mocks de Firebase y los comentarios obsoletos; los 5 tests siguen y pasan). Ninguno borrado ni desactivado.
- Tests nuevos en `test/funcionalidades/chat/` (servicio y pantallas), `test/compartido/sondeo_periodico_test.dart`, `test/funcionalidades/trabajos/reservar_pago_y_chat_test.dart`. Cubren: `desde` incremental sin duplicados, Timer cancelado en dispose, pausa/reanudación por ciclo de vida, envío, reglas del panel (empleador espera al trabajador; aceptar), fallo de primera carga con reintento, `reservar-pago` no se llama sin acuerdo completo ni sin chat, "Abrir chat" por id de trabajo.

## Tamaño (techo 300)

Todos los archivos nuevos < 300. `detalle_trabajo_screen.dart` sigue en ~1230 líneas: excepción preexistente y documentada (tarea 035); esta tarea solo cambió `_reservarPago` y `_botonChat` y actualizó su docstring. Partirlo queda pendiente.

## Lo que NO se verificó

- **Nada contra un servidor real ni un emulador.** Los JSON de los tests siguen el contrato del reporte 054 (`git show feature/054-backend-chat-demo:docs/agent-reports/054-backend-chat-contrato.md`), no un `curl` a la VM. Riesgos concretos: el formato exacto de `desde` con `Z` y microsegundos (el servidor lo parsea como Instant; el test comprueba que el cliente manda ISO UTC), y que el mensaje enviado aparezca en el siguiente `GET` (dedupe por id).
- No se ejecutó en dispositivo el comportamiento de segundo plano; se probó con transiciones simuladas de `AppLifecycleState`.
- No se comprobó la apariencia visual (mismo layout que antes; sin capturas).
- Unread badge: `total` de `GET /no-leidos` se toma tal cual del backend.

## Cosas a saber / pendientes

- **`reservar-pago` sigue sin validar el acuerdo en el servidor** (brecha 1 del reporte 054; tarea 055). El chequeo del cliente es la única barrera hoy: un cliente modificado puede retener otro monto.
- El texto "por hora" del chat vs. monto total retenido del trabajo es una ambigüedad de producto que ya existía; no se cambió.
- **`cloud_firestore` (y `firebase_core`/`firebase_auth`) siguen en `pubspec.yaml`, y `main.dart` sigue llamando a `Firebase.initializeApp()`**: ya no hay código que use Firestore, pero quitarlos afecta al build Android (`google-services`) y no lo hice sin que se decida. Deuda: quitar dependencias, `firebase_core_platform_interface` de dev, y `firestore.rules`.
- Comentarios "Firestore" antiguos siguen en tests de perfil (`descartarErroresDeFirestore`, ahora no-ops) y en `test/manual/generar_capturas_perfil_inicio.dart`; inofensivos, limpiar cuando se toquen.
- Un chat sin mensajes muestra "Escriban el primer mensaje" (se quitó el emoji).
- `pubspec.lock`/archivos generados de plataforma que `flutter pub get` regeneró se revirtieron; no van en el commit.
