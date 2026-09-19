---
id: 052   # renumerada 2026-09-16: chocaba con 032-rediseno-autenticacion-login-bienvenida.md, ya en develop
titulo: "Fase 2b-2 (mitad fácil): migrar cartera_service y calificacion_service de Firestore a la API"
estado: en-revision
agente: "flutter-agent"
creada: 2026-09-10
rama: "feature/052-cartera-calificacion-api"
---

## Objetivo

De los tres servicios que quedan en Firestore (`chat`, `cartera`,
`calificacion`), migrar los dos que **no** dependen del WebSocket:
`cartera_service.dart` y `calificacion_service.dart`. El backend ya tiene
todo lo necesario:

- `GET /api/cartera/tarjetas`, `POST /api/cartera/tarjetas`,
  `DELETE /api/cartera/tarjetas/{id}` — **nuevos**, del PR #8
  (`feature/tarjetas-y-websocket-jwt`, sobre `develop` pero **aún sin
  fusionar** — ver "Cómo trabajar sin el merge" abajo).
- `POST /api/cartera/recargar`, `GET /api/cartera/movimientos` — ya existían.
- `saldo` ya viene en `Usuario` (`GET /api/auth/yo`, y en `sesionActual`).
- `POST /api/calificaciones`, `GET /api/calificaciones/usuario/{id}?rol=X` —
  ya existían (tarea 019/ADR-0011). El servidor hace TODA la lógica que hoy
  hace el cliente a mano contra Firestore (transacción, actualizar
  reputación por rol, pasar el trabajo a `FINALIZADO` cuando ambas partes
  calificaron) — **el cliente nuevo debe ser MÁS simple que el actual, no
  igual**: solo llama al endpoint y listo, sin replicar la transacción.

## Sobre el PR #8 (nota 2026-09-16, ya no bloquea)

**El PR #8 (tarea 030, tarjetas + WebSocket JWT) ya se mergeó a `develop`**
(`fc29f60`, 2026-09-16) — lo que sigue quedó como registro histórico de por
qué esta rama partió de un commit intermedio, no como instrucción a seguir.
Antes de retomar esta tarea, rebasa sobre el `develop` actual (los 3
endpoints de tarjetas ya están ahí, junto con toda la cadena 027-050) en vez
de sobre `feature/tarjetas-y-websocket-jwt`, que ya está obsoleta.

<details>
<summary>Instrucciones originales (obsoletas, se dejan por contexto)</summary>

El PR #8 (tarjetas + WebSocket JWT) está abierto contra `develop` pero
pendiente de revisión humana. Esta tarea depende de sus 3 endpoints de
tarjetas. Dos opciones, elige la que puedas hacer funcionar rápido:

1. **Rebasa tu rama sobre `feature/tarjetas-y-websocket-jwt`** en vez de
   sobre `develop` (`git checkout -b feature/fase2b2-cartera-calificacion
   feature/tarjetas-y-websocket-jwt` si tu punto de partida no lo hizo ya).
   Cuando el #8 entre a `develop`, esta rama se rebasa limpia.
2. Si por lo que sea el branch no está disponible en tu worktree, los tres
   endpoints están documentados completos en `docs/api.md` → sección
   `/api/cartera` (los añadió esa misma tarea 030) — puedes programar contra
   el contrato documentado y probarlo contra el backend real más tarde.

</details>

**El contrato de tarjetas** (de `docs/api.md`, revísalo tú mismo por si
cambió): `TarjetaResponse { id, marca, ultimos4, titular, vencimiento }`.
`POST` recibe `{ numero, titular, vencimiento }` (el servidor calcula
`marca` y `ultimos4`, nunca guarda el número completo). Borrar una ajena o
inexistente → **403** si existe y es de otro, **404** si no existe (fue
corregido en revisión de security-agent — confírmalo contra el código real
del branch, no asumas).

## Qué migrar

### `CarteraService` (hoy `lib/services/cartera_service.dart`, Firestore)

Nuevo `lib/funcionalidades/cartera/datos/cartera_service.dart` (nace ya en
la estructura de ADR-0014, no se mueve luego):

- `streamSaldo` (Firestore) → **desaparece**. El saldo ya viene en
  `SesionUsuario.usuario?.saldo` (mismo patrón que el resto de datos de
  perfil desde la fase 2a: sin sondeo, se recarga con `PerfilService`). Si
  `CarteraScreen` necesita refrescar el saldo al entrar, usa
  `context.read<PerfilService>().recargarPerfil()` (ya existe) en vez de
  inventar un método nuevo.
- `streamTarjetas` → `Future<List<Tarjeta>> listarTarjetas()` — un solo
  `GET`, sin stream. Carga puntual + "deslizar para actualizar", el mismo
  patrón que `listarFeed`/`misPublicaciones` de la 026. **Sin sondeo.**
- `agregarTarjeta(...)` → `POST`. Mismo contrato de parámetros de hoy
  (`numero`, `titular`, `vencimiento`); ya no calcules `marca` en el cliente
  si el servidor la devuelve (revisa `TarjetaResponse`; si el servidor no la
  manda, mantén `Tarjeta.marcaDesdeNumero` — solo para mostrar el icono, no
  es dato sensible).
- `eliminarTarjeta(uid, id)` → `DELETE`. El `uid` ya no hace falta pasarlo
  (el servidor lo saca del JWT): cambia la firma a `eliminarTarjeta(id)`, y
  actualiza los ~2-3 sitios que la llaman.
- `recargarSaldo` → ya existe `POST /api/cartera/recargar`: úsalo tal cual
  (probablemente ya hay un método parecido en algún sitio del cliente —
  revisa antes de duplicar; si no existe, créalo aquí).
- `movimientos` → nuevo método `Future<List<...>> movimientos()` contra
  `GET /api/cartera/movimientos`. Revisa si ya hay un modelo para el
  movimiento o si hay que crear uno pequeño en
  `lib/compartido/modelos/` (transversal si el chat también lo llegara a
  usar; si no, puede vivir en `funcionalidades/cartera/`).

### `CalificacionService` (hoy `lib/services/calificacion_service.dart`, Firestore)

Nuevo `lib/funcionalidades/calificaciones/datos/calificacion_service.dart`:

- `calificar(...)` → `POST /api/calificaciones`. **Borra la transacción
  Firestore entera** (cálculo de promedio, actualización de la
  publicación) — eso ya lo hace el servidor. El método cliente queda en
  ~10-15 líneas: mandar `{trabajoId, estrellas, comentario}`, mapear el 409
  ("ya calificaste") al mismo mensaje que hoy da la pantalla.
- `streamCalificaciones(uid)` → `Future<List<Calificacion>> listarDe(uid,
  {String? rol})` contra `GET /api/calificaciones/usuario/{id}?rol=X`. Sin
  stream, carga puntual. Revisa el modelo `Calificacion.desdeJson` — si no
  existe todavía (solo tenía `desdeFirestore`), créalo con el JSON real del
  servidor (pide un ejemplo con `curl` contra la VM si tienes acceso, o
  contra `docs/api.md` si documenta la forma exacta).

### Pantallas a tocar

`lib/screens/cartera_screen.dart` → mover a
`lib/funcionalidades/cartera/pantallas/cartera_screen.dart` (y partir si al
tocarlo pasa de 300 líneas — hoy tiene 269, cuidado con no pasarte).
`lib/screens/calificar_sheet.dart` → mover a
`lib/funcionalidades/calificaciones/pantallas/calificar_sheet.dart`.
Inyecta los nuevos servicios con `provider`
(`proveedoresDeLaApp()`) — **nada de `CarteraService()`/`CalificacionService()`
construidos dentro de un `State`**, mismo criterio que cerró la anomalía de
B-2. `detalle_trabajo_screen.dart` y donde sea que abran `CalificarSheet`
pasan a `context.read<CalificacionService>()`.

**`ChatService` NO se toca en esta tarea** (depende del WebSocket, fuera de
alcance — es la siguiente fase). Si `calificar_sheet` o `cartera_screen`
importan algo de chat, dilo y para: no debería, pero confírmalo.

## Restricciones

- `firestore_colecciones.dart` pierde las referencias a `tarjetas`/
  `calificaciones` que ya no se usan, pero **no se borra** (lo sigue usando
  `chat_service`). Coméntalo si acaba con líneas muertas.
- Sin sondeo en ningún sitio nuevo (regla ya establecida en fase 2a/2b-1).
- Techo de 300 líneas (ADR-0014).
- Tests: sigue el patrón de `trabajos_y_postulaciones_test.dart` (JSON
  copiado del servidor real cuando puedas obtenerlo; si no tienes acceso al
  backend real en tu entorno, usa el JSON documentado en `docs/api.md` y
  dilo explícitamente en el reporte — no inventes campos).
- `flutter analyze`/`flutter test` verdes tras cada pieza movida/migrada,
  no solo al final.

## Criterios de aceptación

- [ ] `CarteraService`/`CalificacionService` ya no importan
      `cloud_firestore` ni `firestore_colecciones.dart`.
- [ ] Sin streams nuevos; carga puntual + "deslizar para actualizar" donde
      aplique.
- [ ] DI con `provider`, cero `Servicio()` dentro de un `State` en las
      pantallas tocadas.
- [ ] `flutter analyze` no sube de la línea base que tengas al empezar;
      `flutter test` no baja.
- [ ] Reporte en `docs/agent-reports/052-*.md`: qué se migró, qué contrato
      real se usó (o si fue solo el documentado, sin confirmar contra el
      servidor), y qué queda pendiente (probar en emulador contra el
      backend real requiere que el PR #8 esté desplegado en la VM — dilo si
      no lo está).

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
