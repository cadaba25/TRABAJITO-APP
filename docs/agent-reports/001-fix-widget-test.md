---
id: 001
tarea: docs/agent-tasks/001-fix-widget-test.md
agente: qa-agent
fecha: 2026-08-19
---

## Objetivo (copiado de la tarea)

`flutter test` no compila hoy porque `test/widget_test.dart` es el test por
defecto del template de Flutter y referencia una clase `MyApp` que nunca
existió en este proyecto (la app raíz se llama `TrabajitApp`, en
`lib/main.dart`). El test resultante debe probar algo real de arranque
(idealmente que `PantallaInicial` decide entre `LoginScreen` e
`InicioScreen` según el estado de auth), sin depender de Firebase real.

## Cambios realizados

- Reescrito `test/widget_test.dart`: ya no referencia `MyApp`. Queda como
  una comprobación mínima e independiente de que `TrabajitApp` (la clase
  raíz real) es importable y es un `StatelessWidget`. No monta el widget
  ahí para no duplicar el setup de mocks de Firebase.
- Nuevo `test/pantalla_inicial_test.dart`: el test real de arranque.
  Reemplaza `FirebaseAuthPlatform.instance` (punto de extensión oficial de
  `firebase_auth_platform_interface`) por un fake propio
  (`_FirebaseAuthPlatformFalso`) que controla qué emite
  `authStateChanges()`/`idTokenChanges()`/`userChanges()`, y usa
  `setupFirebaseCoreMocks()` de `firebase_core_platform_interface/test.dart`
  para que `Firebase.initializeApp()` no intente hablar con un canal de
  plataforma real. Cubre:
  1. `PantallaInicial` muestra `PantallaCarga` mientras el stream de auth
     no ha emitido (estado `waiting`).
  2. `PantallaInicial` muestra `LoginScreen` cuando el usuario no está
     autenticado — verificación de contenido real (2 `TextFormField`,
     botón "Iniciar sesión"), no solo el tipo de widget.
  3. `PantallaInicial` construye `InicioScreen` cuando el usuario sí está
     autenticado — solo verifica la decisión de enrutamiento (ver
     limitación documentada abajo), tolerando cualquier excepción interna
     de `InicioScreen` si apareciera.
- `pubspec.yaml`: se agregaron como `dev_dependencies` explícitas
  `firebase_auth_platform_interface: ^7.3.0` y
  `firebase_core_platform_interface: ^5.4.2` (ya eran dependencias
  transitivas de `firebase_auth`/`firebase_core`, resueltas exactamente a
  esas versiones; se declararon explícitas solo para que `flutter analyze`
  no marque `depend_on_referenced_packages` al importarlas directo en el
  test, y para fijar la versión probada). No se agregó ningún paquete de
  mocking de terceros.

## Archivos modificados

- `test/widget_test.dart`
- `test/pantalla_inicial_test.dart` (nuevo)
- `pubspec.yaml`
- `docs/agent-tasks/001-fix-widget-test.md`

## Decisiones tomadas

**Por qué mockear a nivel de `FirebaseAuthPlatform.instance` y no con un
paquete de terceros (`firebase_auth_mocks`, etc.):** el proyecto no tiene
ninguna capa de abstracción propia sobre `firebase_auth` (`AuthService`
usa `FirebaseAuth.instance` directo, hardcodeado, sin inyección de
dependencias), así que no había forma de sustituir el `FirebaseAuth` real
por un mock de Dart puro sin tocar `lib/` (fuera del alcance permitido para
esta tarea). Investigando el código fuente de
`firebase_auth_platform_interface` (ya en el pub cache del proyecto, sin
agregar dependencias nuevas para la investigación) se confirmó que
`FirebaseAuthPlatform.instance` tiene un setter público pensado
exactamente para que las implementaciones de plataforma (Android/iOS/web)
se registren ahí — es el mismo mecanismo que usan paquetes como
`firebase_auth_mocks` internamente. Se implementó un fake propio en vez de
depender de un paquete externo, evitando agregar una dependencia de
terceros para algo que se resuelve con ~80 líneas usando el punto de
extensión ya expuesto por la librería.

**Limitación documentada del caso "usuario autenticado":** `InicioScreen`
crea streams de Firestore reales (`AuthService.streamUsuarioActual()`,
`ChatService().streamTotalNoLeidos()`) en su `initState`, sin ninguna capa
de abstracción. Mockear Firestore también habría requerido reimplementar
buena parte de `cloud_firestore_platform_interface` (colecciones, queries
con `where`, snapshots) — un esfuerzo bastante mayor al alcance de esta
tarea, y el propio archivo de tarea autoriza explícitamente un test más
acotado si el mock completo resulta muy costoso. Por eso ese test solo
verifica que `PantallaInicial` decide construir `InicioScreen` (la lógica
real que se quería cubrir: el enrutamiento), no el contenido interno de
`InicioScreen`. En la práctica, al correr el test no se observó ninguna
excepción interna real (dentro de un solo `pump()` no llegó a dispararse
ningún `MissingPluginException` de Firestore), pero el test está escrito
para tolerar y reportar esa excepción si apareciera en el futuro, en vez de
fallar sin explicación.

Se decidió NO intentar mockear Firestore también, para no ampliar el
alcance de esta tarea puntual (arreglar el test roto) hacia construir
infraestructura de test genérica para Firestore — eso se deja como
pendiente explícito (ver abajo).

## Problemas encontrados

Ninguno bloqueante. El mayor riesgo era no encontrar un punto de extensión
para mockear `FirebaseAuth.instance` sin tocar `lib/`; se resolvió
inspeccionando el código fuente de los paquetes ya presentes en el pub
cache local en vez de asumir que existía un mecanismo o que no existía.

## Tests ejecutados

Comando: `flutter test` (desde la raíz del repo), dos veces (una completa
con `flutter pub get` de por medio tras editar `pubspec.yaml`, y una vez
más para confirmar estabilidad). Resultado real (salida completa, no
resumida):

```
00:00 +0: loading .../test/pantalla_inicial_test.dart
00:00 +0: (setUpAll)
00:00 +0: PantallaInicial muestra PantallaCarga mientras no hay respuesta de auth
00:01 +2: PantallaInicial muestra LoginScreen cuando no hay usuario autenticado
00:01 +3: PantallaInicial construye InicioScreen cuando hay usuario autenticado (...)
00:01 +3: (tearDownAll)
All tests passed!
```

Corrida completa incluyendo ambos archivos (`flutter test` sin argumento):
4 tests totales (3 de `pantalla_inicial_test.dart` + 1 de `widget_test.dart`),
`All tests passed!`.

También se corrió `flutter test test/widget_test.dart` de forma aislada
para confirmar ese archivo específico:
```
00:00 +0: loading .../test/widget_test.dart
00:00 +0: TrabajitApp es la clase raíz de la app y es un StatelessWidget
00:00 +1: All tests passed!
```

Comando: `flutter analyze` (raíz del repo). Resultado: 65 issues, todos
preexistentes en `lib/` (warnings de imports no usados y `info` de
`deprecated_member_use`/`use_build_context_synchronously`/etc. ya
presentes antes de esta tarea). Antes de agregar las dos
`dev_dependencies` explícitas había 2 issues `info` adicionales
(`depend_on_referenced_packages`) apuntando a los imports directos en
`test/pantalla_inicial_test.dart`; se resolvieron declarando esas
dependencias. No se introdujo ningún error ni warning nuevo en `lib/`.

## Pendientes

- No se mockeó `cloud_firestore`. Si en el futuro se quiere probar el
  contenido real de `InicioScreen` (o cualquier pantalla que dependa de
  Firestore) de punta a punta en un widget test, haría falta construir un
  fake de `FirebaseFirestorePlatform` (mismo patrón usado aquí para Auth,
  pero con más superficie: colecciones, `where`, `doc`, `snapshots`). Vale
  la pena evaluar en ese momento si conviene en cambio introducir una capa
  de abstracción propia sobre Firestore en `lib/services/` (lo que también
  facilitaría testing en general) — esto es una decisión de arquitectura,
  no de testing, y no se implementó aquí por estar fuera del alcance de
  esta tarea. Sugerido como tarea futura para `flutter-agent`/`tech-lead`.
- El patrón de fake de `FirebaseAuthPlatform` usado en
  `test/pantalla_inicial_test.dart` es reutilizable para futuros tests de
  `LoginScreen`/`AuthService` (por ejemplo, probar el flujo de login con
  credenciales inválidas). No se generalizó a un helper compartido en esta
  tarea porque solo hay un archivo de test que lo necesita hoy; si
  `flutter-agent` o `qa-agent` agregan más tests que lo necesiten, vale la
  pena extraerlo a `test/helpers/`.
