---
id: 060
titulo: "Retirar Firebase de la app y pago del chat como monto total"
estado: en-revision
agente: flutter-agent
creada: 2026-09-18
rama: "feature/060-retirar-firebase-y-total"
---

## Objetivo

(1) El pago negociado en el chat es un monto total, no "/ hora". (2) Quitar
Firebase de la app (ADR-0019).

## Criterios de aceptación

- Sin `firebase_*`/`cloud_firestore` en `pubspec.yaml` ni imports en `lib/`/`test/`.
- Sin plugin google-services ni `google-services.json` en Android.
- `flutter analyze` sin errores nuevos, `flutter test` verde, APK debug compila.
