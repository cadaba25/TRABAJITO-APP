---
id: 018
titulo: "Migración fase 1: cimientos del cliente HTTP en Flutter"
estado: hecho
agente: "flutter-agent"
creada: 2026-08-26
rama: "feature/fase1-cliente-http-v2"
---

## Objetivo

Primera fase ejecutable de la migración (ADR-0009, épica en la tarea 014).
Construir la base sobre la que se migrarán los 6 servicios de Flutter, **sin
migrar todavía ninguno**.

Hoy `pubspec.yaml` **no tiene ningún cliente HTTP**: la app habla con
Firestore por SDK. Hay que crear la capa que hablará con `/api/**`.

## Contexto

- `docs/decisions.md` ADR-0009 (se migra), ADR-0008 (formato de error del
  backend: `{timestamp,status,error,message,fields?}`).
- `docs/api.md` y `backend/README.md` — mapa de endpoints.
- `lib/models/` — 7 modelos con `desdeFirestore()`/`aFirestore()`.
- Skills instaladas que aplican: **`flutter-use-http-package`**,
  **`flutter-implement-json-serialization`**,
  `flutter-apply-architecture-best-practices`. Úsalas.

## Alcance

1. **Cliente HTTP** en `pubspec.yaml` (paquete `http`, salvo que justifiques
   otro).
2. **`ApiClient` único** en `lib/services/api/`:
   - URL base configurable (no hardcodeada: la app corre en emulador,
     dispositivo físico y demo — cada uno ve el servidor en una dirección
     distinta).
   - Cabecera `Authorization: Bearer <token>` automática.
   - Traducción del formato de error del backend a excepciones Dart
     tipadas, con el `message` en español listo para mostrar al usuario y
     los `fields` disponibles para marcar errores por campo en formularios.
   - Timeouts y manejo de "no hay conexión" (hoy Firestore lo daba gratis).
3. **Almacenamiento seguro del token** en el dispositivo — NO en texto
   plano. Justifica el paquete elegido.
4. **Modelos a JSON**: añadir `desdeJson()`/`aJson()` a los 7 modelos.
   **No borres** `desdeFirestore()`/`aFirestore()` todavía: la app sigue
   funcionando con Firestore hasta que cada servicio migre. Conviven.
   Ojo con los campos que difieren entre ambos modelos (ver
   `docs/database.md`).
5. **Tests** de la capa nueva: parseo de respuestas, manejo de errores,
   token que se adjunta.

## El contrato de sesión YA está cerrado (fase 0, tarea 015)

No hay que inventar nada: `ApiClient` debe implementar **este** contrato, que
ya funciona en el servidor (ADR-0010, verificado por el `tech-lead`):

- `POST /api/auth/registro` y `POST /api/auth/login` devuelven
  `{token, refreshToken, usuario}`.
- El **token de acceso dura 15 minutos**. Cuando caduque, el cliente debe
  llamar a `POST /api/auth/refresh` con `{"refreshToken": "..."}` y recibir
  un par nuevo. **El refresh token rota**: el viejo deja de valer.
- `POST /api/auth/logout` revoca la sesión de verdad.
- **Ojo, esto es crítico para el cliente:** si se reutiliza un refresh token
  ya rotado, el backend revoca **toda la familia** de tokens por seguridad.
  Es decir, dos peticiones que refresquen a la vez con el mismo token dejan
  al usuario fuera. El `ApiClient` debe serializar el refresco: **una sola
  renovación en vuelo**, y las peticiones que lleguen mientras tanto esperan
  a que termine, no lanzan la suya.
- El login puede responder **429** (freno de fuerza bruta) con cabecera
  `Retry-After` en segundos. Hay que mostrarlo como un mensaje entendible,
  no como un error genérico.

## Los `Stream` de Firestore: qué los sustituye (decisión del `tech-lead`)

**Medido:** 11 de las 23 pantallas usan `StreamBuilder` (19 usos), y 16 de
los 58 métodos de servicio devuelven `Stream`. Firestore daba tiempo real
gratis; una API REST no.

Decisión, para no frenar la demo:

- **Por defecto, carga puntual + "deslizar para actualizar"** (`RefreshIndicator`).
  Es lo normal en una app REST y se ve bien en una demo.
- **Tiempo real solo en el chat**, vía WebSocket, en la fase 2.
- Si más adelante se quiere tiempo real en más sitios, se añade sin rehacer
  lo anterior.

En **esta** fase no se cambia ninguna pantalla: solo hay que tener esto en
cuenta al diseñar el `ApiClient`, para que la fase 2 no tenga que rehacerlo.

## Fuera de alcance

- Migrar servicios (fase 2, una tarea por servicio).
- Tocar pantallas.
- Quitar Firebase de `pubspec.yaml` (fase 3).

## Criterios de aceptación

- [x] `flutter analyze` sin errores nuevos. **65 issues antes y después**,
      0 errores; **0 issues en los archivos nuevos o tocados**.
- [x] `flutter test` pasa. De **4 a 86 tests** (+82).
- [x] La app **sigue funcionando igual que hoy** con Firestore: esta fase
      solo añade, no sustituye. Ningún servicio ni pantalla cambió; los
      `desdeFirestore()`/`aFirestore()` siguen intactos y conviven con los
      `desdeJson()`/`aJson()` nuevos.
- [x] La URL base se configura sin recompilar: `ApiClient.cambiarUrlBase()`
      la guarda en el dispositivo y manda sobre `--dart-define`.
- [x] Documentado en `docs/development.md` → "Apuntar la app al backend
      (URL base)", con la tabla emulador / dispositivo físico / VM.

## Notas del agente que la ejecuta

**Qué se construyó** (`lib/services/api/`, 6 archivos, ninguna pantalla tocada):

- `configuracion_api.dart` — URL base con tres niveles de prioridad, tiempos
  límite y `RutasApi`.
- `api_excepciones.dart` — `sealed class ExcepcionApi` con 10 subclases y el
  traductor del formato de error de ADR-0008.
- `sesion_api.dart` — la sesión (token + refresh + caducidad absoluta).
- `almacen_sesion.dart` — `flutter_secure_storage` + un doble en memoria.
- `pagina_api.dart` — el envoltorio de página de Spring Data.
- `api_client.dart` — el cliente.

**Lo más delicado: la renovación del token.** El encargo avisaba de que dos
refrescos simultáneos revocan la familia entera. Hicieron falta **dos**
candados, no uno:

1. **Una sola renovación en vuelo.** La primera petición que necesita renovar
   lanza la llamada y guarda su `Future`; las siguientes se cuelgan de ese
   mismo `Future`. La asignación ocurre sin ningún `await` en medio, así que
   nada puede colarse entre la comprobación y la asignación.
2. **Comparar el refresh token que vio quien pide renovar.** Una petición
   lenta puede despertar *después* de que la renovación terminó: entonces ya
   no hay ninguna "en vuelo" y el candado 1 no la protege. Si mandara su
   refresh token (el viejo, ya rotado) provocaría exactamente la revocación de
   familia. Por eso se compara con el guardado: si no coinciden, alguien ya
   renovó y se reutiliza su resultado **sin tocar la red**.

El candado 1 sin el 2 deja pasar el caso "llegué tarde con el token viejo",
que es el más difícil de reproducir y el que expulsaría usuarios al azar.

**Cómo se prueba sin fiarse de la teoría.** Hay un backend de mentira en los
tests (`BackendFalsoConRotacion`) que **se comporta como el real**: rota el
refresh en cada uso y, si recibe uno ya usado, marca `familiaRevocada` y
devuelve 401 a todo. Los tests afirman que tras 10 peticiones simultáneas
—y tras varias rondas seguidas— la familia **no** se revocó. Si alguien
quitara cualquiera de los dos candados, esos tests se pondrían rojos solos,
sin necesidad de tocar nada más.

**Verificado contra el servidor real** (VM Ubuntu, 2026-08-27), no deducido de
`docs/api.md`: forma de `AuthResponse` (`expiraEnSegundos: 900`,
`tokenType: "Bearer"`), formato de error de ADR-0008 con `fields`, la rotación
del refresh y **la revocación de familia** (reutilizar el token anterior dejó
inservible también al que lo sustituyó), el `429` con `Retry-After: 900`, y el
envoltorio de página de Spring. Los JSON de `test/models/modelos_json_test.dart`
son copias literales de esas respuestas.

**Un detalle que habría costado horas de depurar:** Spring manda
`Content-Type: application/json` **sin** `charset`, y en ese caso el paquete
`http` decodifica en latin-1. `"Sesión inválida"` habría llegado como
`"SesiÃ³n invÃ¡lida"`. El cliente decodifica `bodyBytes` en UTF-8 a mano y hay
un test que lo fija.

**Hallazgo que condiciona la fase 2:** el backend no guarda el perfil del
trabajador. La entidad `Usuario` de Spring **no tiene** `habilidades`,
`experiencia`, `estudios`, `telefonoEmergencia`, `fechaNacimiento`, `genero`,
`viveEnHonduras`, `codigoPostal`, `pais`, `urlCV`, `cargoContacto`,
`descripcionEmpresa` ni `registroCompleto` — justo lo que llena
`registro_trabajador_screen`. Tampoco hay tarjetas. Detalle y propuesta en el
reporte.
