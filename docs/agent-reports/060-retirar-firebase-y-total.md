# Reporte 060 — Retirar Firebase y pago total

## Hecho
- Pago total: `panel_negociacion.dart` y `detalle_trabajo_screen.dart` muestran
  "L. N en total"; el diálogo dice "Proponer pago total" / "Pago total
  (Lempiras)". Test `chat_screen_test.dart` ajustado. Los textos de mensaje de
  sistema "Pago acordado: L. 150.00 / hora" en `chat_service_test.dart` son
  fixtures de lo que manda el servidor: NO se tocaron (backend fuera de alcance;
  si el servidor aún escribe "/ hora", hay que cambiarlo allí).
- Firebase: quitados `firebase_core`, `firebase_auth`, `cloud_firestore` y
  `firebase_auth_platform_interface`/`firebase_core_platform_interface` (dev);
  `Firebase.initializeApp()` de `main.dart`; plugin google-services en
  `android/settings.gradle.kts` y `android/app/build.gradle.kts`;
  `android/app/google-services.json`. No existía `firebase_options.dart`.
  Tres tests (perfil_tab, trabajadores_ranking_navegacion, manual de capturas)
  dejan de llamar a `setupFirebaseCoreMocks`/`initializeApp`.
- ADR-0019 en `docs/decisions.md`.

## Verificación
- `flutter pub get` OK. `flutter analyze`: 8 issues, todos info/warning
  preexistentes (ninguno nuevo). `flutter test`: 350 pasan (baseline 350).
- `flutter build apk --debug`: compila (aviso preexistente de compileSdk 37 por
  flutter_secure_storage).
- Los `generated_plugin_registrant` de linux/macos/windows que `pub get`
  regeneró se revirtieron y no van en el commit (siguen listando plugins
  Firebase; se regenerarán en cada máquina).

## Pendiente
- Fase 3: borrar `firestore.rules` y el proyecto Firebase (security-agent).
- Comentarios históricos sobre Firestore en `lib/` se dejaron.
- No se actualizó el snapshot (cifras de tests sin cambio).
