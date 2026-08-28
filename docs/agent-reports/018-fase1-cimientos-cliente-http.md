---
id: 018
tarea: docs/agent-tasks/018-fase1-cimientos-cliente-http.md
agente: "flutter-agent"
fecha: 2026-08-27
---

## Objetivo (copiado de la tarea)

Primera fase ejecutable de la migración (ADR-0009, épica en la tarea 014).
Construir la base sobre la que se migrarán los 6 servicios de Flutter, **sin
migrar todavía ninguno**. Hoy `pubspec.yaml` no tiene ningún cliente HTTP: la
app habla con Firestore por SDK. Hay que crear la capa que hablará con
`/api/**`.

## Cambios realizados

### 1. Capa HTTP nueva — `lib/services/api/` (6 archivos)

| Archivo | Qué hace |
|---|---|
| `configuracion_api.dart` | URL base con prioridad **override guardado → `--dart-define` → valor por plataforma**, tiempo límite (20 s), margen de renovación (30 s) y `RutasApi`. |
| `api_excepciones.dart` | `sealed class ExcepcionApi` + 10 subclases + el traductor del formato de error de ADR-0008. |
| `sesion_api.dart` | La sesión: token de acceso, refresh token, caducidad **absoluta** y el `usuario` en crudo. Se serializa para el almacén. |
| `almacen_sesion.dart` | Interfaz `AlmacenSesion`, implementación con `flutter_secure_storage` y doble en memoria para tests. |
| `pagina_api.dart` | `PaginaApi<T>`: lee el envoltorio de página de Spring Data o un array pelado. |
| `api_client.dart` | El cliente: cabecera `Authorization`, verbos, renovación serializada, cierre de sesión. |

Nada de esto está enchufado todavía: **ninguna pantalla ni servicio cambió**.

### 2. Los 7 modelos ganan `desdeJson()` / `aJson()`

Conviven con `desdeFirestore()`/`aFirestore()`, que **no se tocaron**. Se añadió
`lib/models/json_utiles.dart` con las ayudas de lectura (`textoJson`,
`decimalJson`, `fechaJson`...), porque el backend manda `null` en todo campo
opcional y los modelos de la app usan `''` y `0`.

### 3. Traducción de enums centralizada en `lib/utils/constantes.dart`

`EstadosTrabajo.desdeApi/aApi`, `EstadosPostulacion.desdeApi/aApi`,
`TiposMensaje`, `RolesApi` y el ayudante `MapeoEnumApi`. Se añadieron las dos
constantes de estado que faltaban (`enDisputa`, `cancelado`), que el backend
sí produce. Así ningún servicio de la fase 2 escribirá `"EN_PROGRESO"` a mano.

### 4. Android

`INTERNET` en el manifiesto principal (antes solo lo declaraba el de debug y,
de rebote, los SDK de Firebase al fusionar) y un
`network_security_config.xml` **solo en `src/debug/`** que permite HTTP sin
TLS. La build de release sigue exigiendo HTTPS, que es lo que hará falta
cuando la fase 4 ponga el certificado.

### 5. Documentación

`docs/development.md` gana la sección "Apuntar la app al backend (URL base)",
con la tabla emulador / dispositivo físico / VM y los cuatro fallos típicos.

## Archivos modificados

Nuevos:
- `lib/services/api/configuracion_api.dart`
- `lib/services/api/api_excepciones.dart`
- `lib/services/api/sesion_api.dart`
- `lib/services/api/almacen_sesion.dart`
- `lib/services/api/pagina_api.dart`
- `lib/services/api/api_client.dart`
- `lib/models/json_utiles.dart`
- `test/api/ayudas_api.dart`
- `test/api/api_client_test.dart`
- `test/api/sesion_y_pagina_test.dart`
- `test/models/modelos_json_test.dart`
- `android/app/src/debug/res/xml/network_security_config.xml`

Modificados:
- `lib/models/usuario.dart`, `publicacion.dart`, `postulacion.dart`,
  `calificacion.dart`, `evidencia.dart`, `chat.dart`, `tarjeta.dart`
  (solo se **añadió**; nada se borró)
- `lib/utils/constantes.dart`
- `pubspec.yaml`, `pubspec.lock`
- `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/debug/AndroidManifest.xml`
- `docs/development.md`, `docs/agent-tasks/018-...md`,
  `docs/agent-context/repo-snapshot.md`

**Fuera de `lib/` y `test/`:** se tocó `android/` (permiso de internet y
config de red) porque sin eso la capa nueva no puede hacer una sola petición.
Es configuración de la app Flutter, no de `backend/` ni de infraestructura.
No se tocó `backend/**` ni `firestore.rules`.

## Decisiones tomadas

### Dos candados para la renovación, no uno (lo más importante de la tarea)

El encargo avisaba: dos refrescos simultáneos con el mismo refresh token hacen
que el backend revoque la familia entera y expulse al usuario. Lo verifiqué
contra el servidor antes de escribir nada — reutilizar el token anterior dejó
inservible también al que lo había sustituido.

La solución evidente (una sola renovación en vuelo) **no basta**:

```dart
Future<SesionApi> _renovar(String refreshVisto) {
  final actual = _sesion;
  if (actual == null) return Future<SesionApi>.error(const SesionInvalida());

  // Candado 2: alguien renovó mientras esperábamos. Mandar el refresh viejo
  // aquí sería justo lo que el backend considera reutilización.
  if (actual.refreshToken != refreshVisto) {
    return Future<SesionApi>.value(actual);
  }

  // Candado 1: ya hay una renovación en marcha; esperamos a esa.
  final enVuelo = _refrescoEnVuelo;
  if (enVuelo != null) return enVuelo;

  // Entre la comprobación de arriba y esta asignación no hay ningún `await`,
  // así que ninguna otra petición puede colarse en medio.
  final futuro = _ejecutarRenovacion(actual);
  _refrescoEnVuelo = futuro;
  futuro.whenComplete(() {
    if (identical(_refrescoEnVuelo, futuro)) _refrescoEnVuelo = null;
  }).ignore();
  return futuro;
}
```

El candado 1 cubre el caso simultáneo. El **candado 2** cubre el que se escapa:
una petición lenta cuyo 401 llega *después* de que la renovación terminó. En
ese momento `_refrescoEnVuelo` ya es `null`, así que el candado 1 la deja
pasar, y esa petición todavía recuerda el refresh token viejo. Ese es el caso
que expulsaría usuarios al azar y que sería dificilísimo de diagnosticar.
Hay un test dedicado a él (`una petición lenta que despierta tras la
renovación tampoco`).

Complementos: **renovación por adelantado** con 30 s de margen (evita el 401
en el caso normal), **un solo reintento** tras renovar (nunca un bucle), y
`_refrescoEnVuelo` se limpia comprobando `identical` para no borrar una
renovación posterior.

### Un fallo de red durante el refresh NO cierra la sesión

Solo un 401 explícito del backend la mata. Si se cayera la sesión cada vez que
falla la conexión, un trabajador con cobertura intermitente —el caso de uso
real de esta app— tendría que volver a iniciar sesión constantemente.

### `http` en vez de `dio`

`dio` aporta interceptores, reintento y timeouts; `ApiClient` ya resuelve esas
tres cosas de la forma concreta que este contrato necesita (la serialización
del refresco no es un interceptor genérico). `http` es el paquete oficial del
equipo de Dart, tiene `package:http/testing.dart` con `MockClient` —que es lo
que permite probar toda la capa sin abrir un socket ni añadir otra dependencia
de test— y es lo que recomienda la skill `flutter-use-http-package`.

### `flutter_secure_storage` en vez de `shared_preferences`

Lo que se guarda es un refresh token de 30 días que **es** la sesión: quien lo
tenga puede pedir tokens de acceso hasta que se revoque. `shared_preferences`
escribe XML en claro dentro del sandbox; en un dispositivo con root o vía copia
de seguridad de Android es legible. Firebase Auth guardaba su sesión por dentro
y esto no era decisión nuestra; con el backend propio, sí lo es.

### Sin `json_serializable` ni `freezed`

CLAUDE.md dice que no se cambia el patrón de modelos sin un ADR de
`tech-lead`. Se mantuvo el `desdeX()`/`aX()` a mano, que además permite algo
que la generación automática no da gratis: los nombres del backend **no**
coinciden con los de la app (`empleadorId` → `uidEmpleador`, `contenido` →
`texto`, `creadoEn` → `fecha`) y hay que traducir enums en medio.

### Se conservó `desdeFirestore()`/`aFirestore()`

La tarea lo pedía y es lo que garantiza que la app siga funcionando igual. Las
dos parejas conviven en cada modelo, separadas por un comentario que dice de
dónde viene cada una.

### Los `Stream` de Firestore

No se tocó ninguna pantalla, pero `PaginaApi` se diseñó pensando en la decisión
del `tech-lead` (carga puntual + `RefreshIndicator`): expone `hayMas` y
`paginaSiguiente` para que el scroll infinito de la fase 2 no obligue a
rehacerla.

### Enums: lo desconocido cae en el valor más conservador

Un `estado` que la app no conoce se lee como `cerrado`, no se cuela tal cual
por la UI. Un `rol` desconocido cae en `trabajador`, el de menos privilegios.

## Problemas encontrados

### 1. El paquete `http` decodifica en latin-1 si no hay `charset`

Spring manda `Content-Type: application/json` **sin** `charset`, y en ese caso
`response.body` usa latin-1: `"Sesión inválida"` habría llegado como
`"SesiÃ³n invÃ¡lida"` a la cara del usuario. `ApiClient` decodifica
`bodyBytes` en UTF-8 explícitamente, y hay un test que lo fija (`el mensaje
llega con las tildes intactas aunque falte el charset`).

### 2. `flutter_secure_storage` 11 cambió la API

`AndroidOptions(encryptedSharedPreferences: true)` ya no existe: en la v11 el
cifrado (AES-GCM con clave envuelta en el Keystore) es el comportamiento por
defecto. Se usa `AndroidOptions()` a secas.

### 3. El backend no guarda el perfil del trabajador — el hallazgo grande

Se revisó la **entidad JPA**, no solo el DTO. `Usuario` de Spring **no tiene**:

`habilidades`, `experiencia`, `estudios`, `telefonoEmergencia`,
`fechaNacimiento`, `genero`, `viveEnHonduras`, `codigoPostal`, `pais`, `urlCV`,
`cargoContacto`, `descripcionEmpresa`, `registroCompleto`, `fechaRegistro`.

Y dos que la entidad sí tiene pero `UsuarioResponse` **no expone**: `rtn` y
`activo`.

Es la diferencia más grande de toda la migración y no estaba anotada en
`docs/database.md`, que solo mencionaba el `saldo`, `Notificacion` y `Reporte`.
Habilidades, experiencia y estudios son justo lo que llena
`registro_trabajador_screen` y lo que se muestra en el perfil público de un
trabajador: sin ellos, migrar el perfil **pierde datos visibles al usuario**.

### 4. Tampoco hay tarjetas en el backend

No existe entidad, tabla ni endpoint de tarjeta; `/api/cartera` solo tiene
`recargar` y `movimientos`. `Tarjeta.desdeJson/aJson` usan de momento los
mismos nombres que Firestore, con un comentario que lo deja claro.

### 5. Otros campos que el backend no manda y la UI sí usa

- `Postulacion`: `tituloPublicacion` y `uidEmpleador` (en Firestore iban
  desnormalizados para pintar la lista sin una segunda lectura).
- `Calificacion`: `deNombre` y `rolCalificado`.
- `Chat`: `noLeidos` (el backend marca `leido` mensaje a mensaje, no lleva
  contador por chat) — la lista de chats mostraría 0 sin avisar.

Todos están anotados en un comentario dentro del modelo correspondiente.

### 6. No se pudo hacer la comprobación por mutación

Quise dejar constancia empírica de que los candados hacen falta desactivando
uno y viendo el test en rojo (como hizo `backend-agent` con el test de
concurrencia). El sistema de permisos bloqueó ejecutar los tests con esa
modificación en el árbol, así que se restauró el código y se resolvió de otra
forma, mejor: el backend de mentira `BackendFalsoConRotacion` **implementa la
regla del servidor real** (rota, y si detecta reutilización marca
`familiaRevocada` y devuelve 401 a todo). Los tests afirman que la familia no
se revocó. Si alguien quitara cualquiera de los dos candados, esos tests se
pondrían rojos por sí solos.

## Tests ejecutados

```
$ flutter analyze
65 issues found. (ran in 4.7s)      # mismas 65 que antes de la tarea, 0 errores
```

Los 65 son los preexistentes (`withOpacity` deprecado,
`use_build_context_synchronously`, un campo sin usar). Filtrando por lo que
esta tarea toca o crea:

```
$ flutter analyze | grep -E "services\\api|models\\|test\\api|test\\models|utils\\constantes"
(sin salida)
```

**Cero issues en todo lo nuevo.**

```
$ flutter test
00:02 +86: All tests passed!
```

De **4 a 86** (+82):

| Archivo | Tests | Qué cubre |
|---|---|---|
| `test/api/api_client_test.dart` | 32 | cabeceras, cuerpo UTF-8, parámetros de consulta, los 8 códigos de error de ADR-0008, `Retry-After`, sin conexión, timeout, 204, respuesta ilegible, renovación proactiva y reactiva, sin bucles, borrado de sesión, **serialización del refresco** (7 tests, 3 de ellos contra el backend falso con revocación de familia), cierre de sesión |
| `test/api/sesion_y_pagina_test.dart` | 16 | `SesionApi` con la respuesta real, caducidad con margen, ida y vuelta al almacén, `toString` que no filtra tokens, `PaginaApi` con el envoltorio real de Spring, `ConfiguracionApi`, `Retry-After` |
| `test/models/modelos_json_test.dart` | 34 | los 7 modelos con JSON **copiado del servidor real**, traducción de enums, `null` → `''`, fechas ISO con nanosegundos, y que `aJson()` no mande campos que decide el servidor |
| preexistentes | 4 | sin cambios |

**Verificado contra el servidor real** (VM Ubuntu, 2026-08-27, vía
`ssh -p 2222 -o BatchMode=yes`), no deducido de `docs/api.md`:

- `POST /api/auth/registro` y `/login` → `{token, refreshToken, tokenType:"Bearer", expiraEnSegundos:900, usuario:{...}}`.
- Formato de error de ADR-0008, incluido `fields` en un 400 de validación.
- `POST /api/auth/refresh` rota el par; **reutilizar el token anterior devolvió
  401 y dejó inservible también al que lo sustituyó** (revocación de familia
  confirmada, es la razón de ser de los dos candados).
- `POST /api/auth/logout` → `204`, también con un token ya revocado.
- 6 logins fallidos seguidos → `429` con `Retry-After: 900`; el 7.º con la
  contraseña **correcta** → `200` (el freno no bloquea al dueño legítimo).
- `GET /api/trabajos` devuelve el envoltorio de página de Spring
  (`content`, `totalElements`, `number`, `first`/`last`...).
- Fechas como `Instant` ISO-8601 UTC con nanosegundos
  (`"2026-08-27T04:46:47.688473359Z"`).

**Lo que NO se pudo verificar:** no se ejecutó la app en un emulador ni en un
dispositivo físico (no hay ninguno disponible en este entorno). La sección de
`docs/development.md` sobre `10.0.2.2` y el `network_security_config.xml` está
razonada y es el montaje estándar de Android, pero **no está probada en un
emulador real**. Tampoco se probó `flutter_secure_storage` contra un
dispositivo: los tests usan el doble en memoria porque los canales de
plataforma no existen en `flutter test`.

**Efecto sobre el servidor de pruebas:** se crearon 5 cuentas
`f018*@trabajito.test` y 1 trabajo de prueba, y se gastaron ~6 intentos
fallidos del cupo por IP (20 en 15 min, compartido por todo lo que sale del
host — ver tarea 016). No se borró nada existente.

## Pendientes

Candidatos a tarea nueva, en orden de urgencia para la fase 2:

1. **[`backend-agent`] El backend no guarda el perfil del trabajador.**
   Faltan `habilidades`, `experiencia`, `estudios` y 11 campos más en la
   entidad `Usuario` (lista completa arriba). **Bloquea la migración de
   `auth_service` y del perfil**: sin esto, migrar pierde datos que el usuario
   ve. Hay que decidir columnas + DTO antes de la fase 2, y coordinarlo con
   `security-agent` (`ActualizarPerfilRequest` decide qué puede escribir el
   dueño de la cuenta).
2. **[`backend-agent`] Campos desnormalizados que la lista necesita.**
   `tituloTrabajo`/`empleadorId` en `Postulacion`, `autorNombre`/`rolCalificado`
   en `Calificacion`. Sin ellos cada fila de la lista necesita una petición
   extra (N+1 sobre HTTP, que no es lo mismo que sobre Firestore).
3. **[`backend-agent` + `flutter-agent`] Contador de no leídos por chat.**
   El backend marca `leido` por mensaje; la app enseña un badge por chat.
4. **[`tech-lead`] Decidir qué pasa con las tarjetas.** No existen en el
   backend y la cartera es un prototipo sin pasarela real.
5. **[`flutter-agent`, fase 3] `archivoUrl` en `Evidencia`** y los cuatro
   campos de disputa de `TrabajoResponse` (`disputaAbiertaPorId`,
   `motivoDisputa`, `resolucionDisputa`, `fechaSolicitudCorreccion`): el
   backend ya los da (ADR-0007) y la app no tiene dónde ponerlos.
6. **[`flutter-agent`] Probar la capa en un emulador de verdad**, en cuanto la
   fase 2 conecte el primer servicio: confirmar `10.0.2.2`, el permiso de
   internet, el `network_security_config` y que
   `flutter_secure_storage` persiste entre arranques.
7. **[`docs-agent`] `docs/database.md` §"Diferencias de modelado"** solo
   menciona el `saldo`, `Notificacion` y `Reporte`. Falta todo lo de los
   puntos 1-3, que es bastante más grande.
8. **[`flutter-agent`] Reconectar `ApiClient.eventosSesion` con la
   navegación** cuando exista el flujo nuevo: hoy el evento `terminada` se
   emite y nadie lo escucha, porque no hay pantalla que migrar todavía.
9. **[`security-agent`] Revisar esta capa.** Toca almacenamiento de tokens y
   el ciclo de sesión: entra de lleno en su dominio, aunque todavía no la use
   ninguna pantalla.
