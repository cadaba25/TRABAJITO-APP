---
id: 001
titulo: "Arreglar test/widget_test.dart (referencia MyApp inexistente)"
estado: hecho
agente: qa-agent
creada: 2026-08-19
rama: "fix/qa-widget-test-and-backend-tests"
---

## Objetivo

`flutter test` no compila hoy porque `test/widget_test.dart` es el test por
defecto del template de Flutter y referencia una clase `MyApp` que nunca
existió en este proyecto (la app raíz se llama `TrabajitApp`, en
`lib/main.dart`). Es el bloqueador más obvio para que el checklist de
"tarea terminada" (`docs/development.md`) sea cumplible por cualquier otro
agente que toque Flutter.

## Contexto relevante

`docs/development.md` sección "Estado conocido al 2026-08-19".
`lib/main.dart` — `TrabajitApp`, `PantallaInicial`.

## Criterios de aceptación

- [x] `flutter test` compila y corre sin el error `MyApp isn't a class`.
- [x] El test resultante prueba algo real de arranque de la app (por ejemplo,
      que `PantallaInicial` decide entre `LoginScreen` e `InicioScreen` según
      el estado de auth), no solo un smoke test vacío para que compile.
- [x] No se requiere Firebase real corriendo para que el test pase (mockear
      `FirebaseAuth`/`Firestore` si hace falta, o aislar el widget que se
      prueba).

## Notas del agente que la ejecuta

`test/widget_test.dart` se dejó como comprobación mínima e independiente
(que `TrabajitApp` es importable y es un `StatelessWidget`); el test real de
arranque vive en `test/pantalla_inicial_test.dart`, nuevo.

Estrategia de mock de Firebase: en vez de mockear a nivel de canal de
plataforma completo, se reemplaza `FirebaseAuthPlatform.instance` (el punto
de extensión oficial que expone `firebase_auth_platform_interface` para que
las plataformas se registren) por un fake propio, y se usa
`setupFirebaseCoreMocks()` de `firebase_core_platform_interface/test.dart`
(ya era dependencia transitiva) para que `Firebase.initializeApp()` no
intente hablar con un canal de plataforma real. No se agregó ninguna
dependencia de mocking de terceros (tipo `firebase_auth_mocks`); en su
lugar se declararon como `dev_dependencies` explícitas
`firebase_auth_platform_interface` y `firebase_core_platform_interface`
(ya resueltas transitivamente, solo se fijó la versión y se silenció el
lint `depend_on_referenced_packages`).

Limitación documentada en el propio test: el caso "usuario autenticado" (→
`InicioScreen`) solo verifica la decisión de enrutamiento de
`PantallaInicial`, no el contenido interno de `InicioScreen`, porque esa
pantalla crea streams de Firestore reales en su `initState`
(`AuthService`/`ChatService`) y Firestore no se mockeó (habría requerido
replicar buena parte de `cloud_firestore_platform_interface`, fuera de
alcance para esta tarea). En la práctica, en la corrida real no se observó
ninguna excepción interna (Firestore no llegó a lanzar `MissingPlugin`
dentro del único `pump()` usado), pero el test está escrito para tolerarla
si apareciera, documentándolo con un `print` explicativo.

`flutter test` → 4/4 tests pasan (ver
`docs/agent-reports/001-fix-widget-test.md`). `flutter analyze` → 65
issues, todos preexistentes (warnings/info en `lib/`), ninguno nuevo
introducido por estos cambios.
