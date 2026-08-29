---
id: 022
tarea: docs/agent-tasks/022-revision-qa-de-la-migracion.md
agente: "qa-agent"
fecha: 2026-08-29
---

## Objetivo (copiado de la tarea)

Revisar lo migrado en las tareas 018, 019 y 020 antes de seguir con la fase
2b, **arreglando** lo que se encuentre y no solo diagnosticándolo. En orden de
importancia: `lib/services/api/` (el `ApiClient` y la renovación de token),
`auth_service.dart` / `sesion_usuario.dart`, las pantallas adaptadas en la
020, y la privacidad del perfil ajeno (backend, tarea 019).

Puntos calientes señalados: el borrado silencioso del CV, la renovación de
token con sus candados, las pantallas que reciben un perfil ajeno con campos
`null`, y el mensaje del 429 del login.

## Resumen

**Tres fallos encontrados y arreglados**, dos de ellos reproducidos en el
emulador contra el backend real, uno reproducido con un test:

1. Una renovación de token en vuelo **resucitaba una sesión ya cerrada**.
2. Editar el perfil con la sesión restaurada sin conexión **borraba la
   presentación** del servidor y **descartaba en silencio** las habilidades
   escritas, diciendo "Perfil actualizado".
3. `LoginScreen` no se protegía del doble envío por la tecla "listo" del
   teclado (dos `POST /api/auth/login`).

**Las tres barreras del CV funcionan** — se comprobó de verdad, no se dio por
bueno el reporte de la 020. **La privacidad del perfil ajeno es correcta**.
**El 429 del login se entiende**. Ver detalle abajo.

Se deja una tarea nueva (`023`) por ser decisión de interfaz, no fallo
mecánico.

## Lo que se revisó, y cómo

Se distingue a propósito entre **leído** y **ejecutado**, porque no vale lo
mismo.

| Ámbito | Cómo se revisó |
|---|---|
| `ApiClient`: candados de renovación | Leído + **sonda ejecutada** que reprodujo el fallo + 4 tests nuevos |
| `ApiClient`: manejo de errores, `Retry-After`, almacén | Leído (ya cubierto por los 32 tests de la 018) |
| `auth_service.dart` / `sesion_usuario.dart` | Leído + ejercitado de punta a punta en el emulador |
| El CV que llega `null` (las 3 barreras) | **Ejecutado en el emulador** contra el backend real, con verificación en PostgreSQL |
| Pantallas de la 020 (login, registro trabajador, editar perfil, configuración, inicio, perfil) | **Recorridas a mano en el emulador** (Pixel_6, Android 13) |
| Privacidad del perfil ajeno (019) | **Ejecutado**: `GET /api/usuarios/{id}` con el token de otra cuenta + lectura de `UsuarioResponse` y `UsuarioService` |
| 429 del login | **Provocado de verdad** en el emulador y fotografiado |
| Pestañas de personas (`TrabajadoresTab`, `RankingTab`) | Leído |
| Los 5 servicios que siguen en Firestore | **No revisados**, fuera de alcance por indicación de la tarea |

Entorno: emulador **Pixel_6 (Android 13, API 33)**, APK de debug compilado con
`--dart-define=TRABAJITO_API_URL=http://10.0.2.2:8080`, contra el backend real
de la VM (`docker compose ps`: `trabajito-api` y `trabajito-db` sanos). Las
comprobaciones de datos se hicieron con `psql` dentro del contenedor, no
mirando la pantalla.

---

## Fallo 1 — Una renovación en vuelo revivía una sesión cerrada

**Gravedad: alta (seguridad).** Es el peor de los tres: deja una sesión
utilizable en el dispositivo después de que el usuario haya pulsado "cerrar
sesión".

### Qué pasaba

`ApiClient._ejecutarRenovacion()` guardaba el par de tokens que devolvía
`POST /api/auth/refresh` **sin comprobar si la sesión que pidió esa renovación
seguía existiendo**. Si el usuario pulsaba "cerrar sesión" mientras había un
refresco en vuelo:

1. `cerrarSesion()` mandaba `POST /api/auth/logout` con el refresh token
   *viejo* (`refresh-0`) y borraba la sesión local.
2. El refresco terminaba después y guardaba `refresh-1`.
3. **`refresh-1` no lo revocó nadie**: el backend
   (`RefreshTokenService.revocar`) revoca **solo el token que se le presenta**,
   no la familia. Se verificó leyendo el código, no suponiéndolo.

Resultado: `haySesion == true` y el almacén seguro con un refresh token que el
servidor sigue aceptando. Al siguiente arranque, `restaurarSesion()` mete al
usuario dentro otra vez.

Dos variantes del mismo agujero, también arregladas: un refresco viejo que
llega tarde **pisaba la sesión de otra cuenta** recién iniciada (con los tokens
*y el perfil* del usuario anterior), y un 401 de ese refresco viejo
**tumbaba la sesión nueva**.

### Cómo reproducirlo

Sonda ejecutada antes del arreglo (`MockClient`, sin sockets):

```dart
final enCurso = cliente.obtener('/api/trabajos'); // token caducado → renueva
await cliente.cerrarSesion();                     // el usuario no espera
```

Salida real:

```
haySesion tras logout: true
sesion en almacen tras logout: refresh-1
rutas: [/api/auth/refresh, /api/auth/logout, /api/trabajos, ...]
```

### Arreglo

Tercer candado en `ApiClient`: antes de guardar los tokens nuevos se comprueba
que `_sesion` sigue siendo la que pidió la renovación (se compara el refresh
token, que es único por rotación). Si no lo es, se tiran los tokens nuevos y
se responde `SesionInvalida`. Lo mismo en la rama del 401: solo se termina la
sesión si es la nuestra.

`test/api/renovacion_y_sesion_test.dart` — 4 tests. **Sin el arreglo fallan 3**
(el cuarto es el control de que la renovación normal sigue funcionando):

```
$ git stash push -- lib/services/api/api_client.dart && flutter test test/api/renovacion_y_sesion_test.dart
00:01 +1 -3: Some tests failed.
$ git stash pop && flutter test test/api/renovacion_y_sesion_test.dart
00:00 +4: All tests passed!
```

### Lo que NO se pudo romper

Se intentó tirar abajo los candados 1 y 2 (los que ya existían) con el backend
de mentira que revoca la familia igual que el real (`BackendFalsoConRotacion`):
peticiones simultáneas, peticiones que despiertan tarde con el token viejo,
renovaciones encadenadas. **No se consiguió provocar una doble renovación con
el mismo token.** Esos dos candados están bien.

---

## Fallo 2 — Editar el perfil sin conexión borraba datos del servidor

**Gravedad: alta (pérdida de datos del usuario).** Este es el que el dueño
temía, aunque no por donde se esperaba: **el CV sobrevivió**, lo que se perdió
fue la presentación.

### Qué pasaba

Cuando la app arranca sin conexión, `restaurarSesion()` entra con el perfil
guardado junto a la sesión —el que devolvió el login—, que trae el CV a `null`
(`cvCargado == false`) y puede estar viejo en todo lo demás. Desde ahí, abrir
"Editar perfil" y pulsar "Guardar cambios":

- Los campos de texto salían **vacíos** (la presentación real no estaba en ese
  perfil) y `PUT /api/usuarios/me` los mandaba vacíos: **se borraba la
  presentación** que sí estaba guardada en el servidor.
- Las habilidades que el usuario escribiera se **descartaban en silencio** —la
  barrera de `cvCargado` impedía mandarlas, que era **lo correcto**— y aun así
  se decía **"Perfil actualizado"** y se volvía atrás.

O sea: la barrera del CV hacía bien su trabajo, pero solo protegía el CV, y
además mentía al usuario sobre lo que había guardado.

### Cómo reproducirlo (emulador, backend real)

```bash
adb shell svc wifi disable && adb shell svc data disable
adb shell am force-stop com.trabajito.trabajito
adb shell monkey -p com.trabajito.trabajito -c android.intent.category.LAUNCHER 1
# Perfil → se ve "Experiencias 0 / Estudios 0 / Sin habilidades registradas"
adb shell svc wifi enable && adb shell svc data enable
# Configuración → Editar perfil → añadir una habilidad → Guardar cambios
```

Estado en PostgreSQL **antes** (tras registrarse y editar con normalidad):

```
 presentacion | hab | exp | est
--------------+-----+-----+-----
 PruebaQA022  |   2 |   1 |   1
```

**Después** de guardar desde el estado sin conexión:

```
 presentacion |          hab          | exp | est
--------------+-----------------------+-----+-----
              | Electricidad,Plomería |   1 |   1
```

La presentación desapareció. La habilidad "Pintura" que se acababa de escribir
no se guardó, y la pantalla dijo "Perfil actualizado".

### Arreglo

`EditarPerfilScreen` ya no edita un perfil que no venga de una lectura
completa. Si llega con `cvCargado == false`, pide `GET /api/auth/yo` antes de
enseñar nada; si no puede (sin conexión), muestra *"No pudimos cargar tu perfil
completo — para no borrar sin querer lo que ya tienes guardado, la edición se
abre solo con tu perfil al día"* con un botón **Reintentar**, y **no dibuja el
formulario ni el botón de guardar**.

Verificado en el emulador después del arreglo:

- Sin conexión → sale el cartel, no hay "Guardar cambios". (`f1.png`)
- Con la red de vuelta y "Reintentar" → aparece el formulario con la
  presentación y las habilidades reales. (`f2.png`)
- Añadir "Pintura" y guardar → PostgreSQL:

```
             presentacion              |              hab              | exp | est
---------------------------------------+-------------------------------+-----+-----
 Presentacion QA que no se debe borrar | Electricidad,Plomería,Pintura |   1 |   1
```

`test/screens/editar_perfil_screen_test.dart` — 4 tests (primeros tests de
pantalla del proyecto junto al del login). **Sin el arreglo fallan 3.**

---

## Fallo 3 — Doble envío del login por la tecla "listo"

**Gravedad: baja.** No lo llegué a provocar con un usuario real; sí a nivel de
código. Lo digo así de claro para que no se lea como más de lo que es.

El botón "Iniciar sesión" ya se desactivaba mientras la petición viajaba
(`onPressed: _cargando ? null : _iniciarSesion`), pero el campo de la
contraseña llama al **mismo método** desde la tecla "listo" del teclado
(`alTerminar`), y ese camino no pasa por el botón. Dos eventos en el mismo
frame → dos `POST /api/auth/login` → dos familias de refresh tokens en el
servidor, y la segunda sesión pisa a la primera, que queda **viva y sin
revocar**.

- **En el emulador NO se reprodujo**: tres `adb shell input keyevent 66`
  seguidos produjeron **un solo login** (comprobado contando filas en
  `refresh_tokens`: pasó de 1 a 2, una sola familia nueva). Cada `adb input`
  es un viaje aparte de ~300 ms, así que el segundo llegaba cuando la pantalla
  ya había navegado.
- **A nivel de widget sí**: invocando `alTerminar` dos veces en el mismo frame
  salían **2** llamadas a `/api/auth/login`. Es una carrera latente, no un
  fallo que haya visto sufrir a nadie.

Arreglo: `if (_cargando) return;` al principio de `_iniciarSesion`.
`test/screens/login_screen_test.dart` — 1 test, que sin el arreglo da 2.

---

## Lo que se revisó y está BIEN (sin hallazgos)

Vale la pena escribirlo: "revisado, sin hallazgos" también es resultado.

### Las tres barreras del CV funcionan

El caso que el dueño pedía, hecho entero en el emulador: registrarse
rellenando los 5 pasos (2 habilidades, 1 experiencia, 1 estudio), cerrar
sesión, volver a entrar, y comprobar que el CV sigue completo. Después editar
el perfil y comprobar que tampoco lo borra.

| Momento | `hab` | `exp` | `est` |
|---|---|---|---|
| Tras el registro (5 pasos) | 2 | 1 | 1 |
| Tras cerrar sesión y volver a entrar | 2 | 1 | 1 |
| Tras editar el perfil (con conexión) | 2 | 1 | 1 |

Cuenta creada: `qa022a@trabajito.test` / `QaTrabajito2026` (trabajadora, Ana
QaVeintidos, Tegucigalpa). Comprobado en la BD, no en la pantalla.

Las tres barreras revisadas una a una:
- **`Usuario.cvCargado`** (`json['habilidades'] != null`) — correcta.
- **`Usuario.aJson()` nunca manda el CV**, y `AuthService._cuerpoDePerfil()`
  deja `habilidades` fuera de la lista de campos admitidos — correcto.
- **Tras login y registro se pide `GET /api/auth/yo`** — correcto.
- Y una cuarta que no estaba anotada: el **backend** también protege
  (`UsuarioService.actualizarPerfil` solo toca las habilidades si
  `req.habilidades() != null`).

### Doble toque en el registro

Se pulsó **tres veces seguidas** cada botón de los 5 pasos del registro de
trabajador (crear cuenta, guardar datos, siguiente con experiencia, finalizar
con estudio). Resultado en PostgreSQL: **1 experiencia, 1 estudio, 1 cuenta**.
El guardado `if (_cargando) return;` de `_avanzar()` aguanta, porque
`_cargando` se pone a `true` **antes** del primer `await`. Lo mismo en
`registro_empleador_screen`.

### Privacidad del perfil ajeno (tarea 019)

`GET /api/usuarios/{id}` con el token de otra cuenta, contra el servidor real:

```
"correo":null, "dni":null, "telefono":null, "telefonoEmergencia":null,
"fechaNacimiento":null, "genero":null, "codigoPostal":null, "rtn":null,
"saldo":null
```

Y sí trae lo público (nombres, ciudad, reputación, CV). `UsuarioResponse` tiene
las dos vistas bien separadas y `UsuarioService.perfilPublico` usa la correcta.
**Sin hallazgos.**

En el cliente, `DetalleTrabajadorScreen` (la única pantalla que recibe un
perfil ajeno, desde `PostulantesScreen`) **no revienta** con esos `null`:
`json_utiles.dart` los convierte a `''`/`0` antes de llegar a la UI, y la
pantalla no lee ningún campo oculto.

### El 429 del login

Provocado de verdad (5 intentos fallidos por `curl` + el 6º desde la app). En
pantalla, con letra grande y en rojo:

> **Demasiados intentos fallidos para esta cuenta. Espera unos minutos e
> inténtalo de nuevo. Vuelve a intentarlo en 15 minutos.**

Se entiende, dice cuánto falta y no parece un error de la app. Único pero,
cosmético: "Espera unos minutos" y "Vuelve a intentarlo en 15 minutos" dicen lo
mismo dos veces (el primero es el `message` del backend, el segundo lo añade
`AuthService` con el `Retry-After`). No lo toco: es texto, no un fallo.

Y lo importante de ADR-0010, comprobado en el mismo sitio: con la cuenta ya
"con fricción", **la contraseña correcta entró igual**. El freno no deja fuera
al dueño legítimo.

### Estados raros por la app mixta

Se buscó lo que pedía la tarea (algo que se quede cargando para siempre en vez
de decir que no hay datos) y **no apareció**. Con y sin conexión, la pestaña de
trabajos enseña "Aún no hay trabajos publicados", no una ruedita eterna.
`TrabajadoresTab` distingue error de vacío y ofrece "desliza para reintentar".
El único estado engañoso que sí apareció es el del perfil sin conexión, y va en
la tarea 023 por ser decisión de interfaz.

## Archivos modificados

- `lib/services/api/api_client.dart` — tercer candado en la renovación
  (`_esLaSesionActual`) y guarda en la rama del 401. Documentación de clase
  actualizada: eran dos candados, ahora tres.
- `lib/screens/editar_perfil_screen.dart` — pide el perfil completo antes de
  dejar editar; estados de carga, de "no se pudo" y reintento.
- `lib/screens/login_screen.dart` — `if (_cargando) return;` en
  `_iniciarSesion`.
- `test/api/renovacion_y_sesion_test.dart` — **nuevo**, 4 tests.
- `test/screens/editar_perfil_screen_test.dart` — **nuevo**, 4 tests.
- `test/screens/login_screen_test.dart` — **nuevo**, 1 test.
- `docs/agent-tasks/023-perfil-viejo-sin-conexion-no-se-avisa.md` — **nueva
  tarea**.
- `docs/agent-tasks/022-...md`, este reporte.

**No se tocó nada de `backend/`.**

## Decisiones tomadas

- **En `EditarPerfilScreen`, no enseñar el formulario cuando no se puede
  completar el perfil**, en vez de enseñarlo con los campos que haya. Es más
  restrictivo, y es a propósito: la alternativa era seguir permitiendo guardar
  campos vacíos encima de datos buenos. Editar un perfil que no se ha leído
  entero no es una operación segura.
- **En `_ejecutarRenovacion`, lanzar `SesionInvalida` en vez de devolver la
  sesión nueva** cuando la sesión cambió a mitad. Devolverla haría que una
  petición del usuario anterior se reintentara con el token del nuevo.
- **No se arregló el aviso de "datos de hace un rato"** (tarea 023): son tres
  decisiones de interfaz sobre qué se le promete al usuario, no un fallo
  mecánico. La parte destructiva sí se arregló aquí.
- **No se arregló el texto repetido del 429**: es una decisión de redacción y
  el mensaje ya se entiende.
- Los tests de pantalla inyectan el cliente con `ApiClient.fijarInstancia()` y
  el estado con `sesionActual`, sin tocar el código de producción para hacerlo
  testeable. Son los **primeros tests de pantalla** del proyecto; el snapshot
  decía que no había ninguno y era cierto.

## Problemas encontrados (de método, no del producto)

- `adb shell input text` **parte los textos con espacios**: "Constructora QA"
  entró como "Constructora". No es un fallo de la app.
- `adb shell input keyevent 4` (atrás) en el paso 1 del registro sale de la
  pantalla y **pierde el formulario**. Es el comportamiento normal de Android,
  pero conviene saberlo si se automatiza.
- `testTextInput.receiveAction` **no deja solapar dos llamadas**
  (`TestAsyncUtils`: "Guarded function conflict"), así que el doble envío del
  login se probó invocando el callback del campo directamente. Está explicado
  en el propio test.
- El cupo de fuerza bruta por IP (20 fallos en 15 min) lo comparte todo lo que
  sale del host. Esta sesión gastó **~7**. Quien pruebe logins fallidos en la
  próxima media hora debería tenerlo en cuenta.

## Tests ejecutados

Comandos exactos y su salida real.

**Flutter — antes de tocar nada (línea base):**
```
$ flutter test
00:03 +135: All tests passed!
$ flutter analyze
62 issues found. (ran in 8.3s)
```

**Flutter — al terminar:**
```
$ flutter test
00:03 +144: All tests passed!
$ flutter analyze
62 issues found. (ran in 5.1s)
```

**144 tests** (135 + 9 nuevos). **62 issues**, las mismas de la línea base:
**cero issues nuevas**.

**Que los tests nuevos detectan el fallo** (no basta con que pasen):
```
$ git stash push -- lib/services/api/api_client.dart
$ flutter test test/api/renovacion_y_sesion_test.dart
00:01 +1 -3: Some tests failed.
$ git stash pop

$ git stash push -- lib/screens/editar_perfil_screen.dart
$ flutter test test/screens/editar_perfil_screen_test.dart
00:02 +1 -3: Some tests failed.
$ git stash pop
```
Y el del login, con la expectativa puesta a un valor imposible para ver el
número real antes del arreglo: `Expected: <99> / Actual: <2>` → dos logins.

**Backend (no se tocó, se corre igual como control):**
```
$ cd backend && mvn test -Dtest='!IntegridadCarteraConcurrenteTest'
[INFO] Tests run: 103, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```
Sigue en **103/103**, 0 saltados.

**`backend/scripts/prueba-flujo-negocio.sh` NO se ejecutó.** Dos razones, y las
digo en vez de asumir que habría pasado: (1) no se tocó una sola línea de
`backend/`, así que la condición de la tarea ("si tocas algo de ahí") no
aplica; (2) el script incluye 20 comprobaciones de fuerza bruta que dependen
del cupo por IP, y esta sesión ya gastó parte de ese cupo provocando el 429 a
propósito, así que ahora mismo daría fallos que no serían del backend.

**En dispositivo real (Pixel_6, Android 13, backend de la VM):**
```
$ flutter build apk --debug --dart-define=TRABAJITO_API_URL=http://10.0.2.2:8080
$ adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
Recorrido completo: restaurar sesión → cerrar sesión → registro de trabajador
en 5 pasos con triple toque en cada botón → perfil con CV → cerrar sesión →
login → perfil con CV → editar perfil → arranque sin conexión → editar perfil
sin conexión → volver la red → reintentar → guardar → 429 del login → login
correcto con la cuenta "con fricción". Cada paso comprobado con
`adb exec-out screencap` y, cuando había datos de por medio, con `psql`.

## Pendientes

- **`docs/agent-tasks/023-perfil-viejo-sin-conexion-no-se-avisa.md`** (creada
  aquí): la app enseña el perfil viejo sin decir que lo es,
  `EstadoSesion.avisoSinConexion` no lo lee nadie, y `PerfilTab` no tiene
  "deslizar para actualizar", así que al volver la conexión el perfil sigue
  viejo hasta reiniciar la app.
- **Las reputaciones por rol de la 019 no se usan en la app.** El backend
  devuelve `calificacionComoTrabajador` y `calificacionComoEmpleador` desde la
  tarea 019, pero `Usuario.desdeJson` no las lee y las pantallas siguen
  enseñando la media global. No es un fallo (nada se rompe), es una función
  del backend que el cliente no aprovecha. Candidato a tarea cuando la fase 2b
  toque las calificaciones.
- **Sigue sin haber tests de la mayoría de pantallas.** Esta tarea añadió los
  tres primeros (login y editar perfil). El registro de 5 pasos, que es donde
  más lógica de guardado hay, solo está probado a mano.
- Las tareas 018, 019 y 020 seguían marcadas como **pendientes de revisión de
  `security-agent`**. Esta revisión es de QA y ha cubierto el comportamiento y
  la privacidad de la vista pública; **no sustituye** una revisión de seguridad
  del almacenamiento del token ni de la cadena de filtros del backend.

## Estado del servidor de pruebas después de esta tarea

- Cuenta nueva **`qa022a@trabajito.test`** / `QaTrabajito2026` (trabajadora,
  Tegucigalpa) con 3 habilidades, 1 experiencia y 1 estudio. Su presentación es
  `"Presentacion QA que no se debe borrar"`, puesta a propósito para poder
  detectar borrados.
- Se gastaron **~7 intentos fallidos** del cupo por IP (20 en 15 min)
  provocando el 429.
- No se borró ni modificó ningún dato preexistente.
