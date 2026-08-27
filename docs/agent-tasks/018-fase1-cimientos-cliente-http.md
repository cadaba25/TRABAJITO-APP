---
id: 018
titulo: "Migración fase 1: cimientos del cliente HTTP en Flutter"
estado: en-progreso
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

- [ ] `flutter analyze` sin errores nuevos.
- [ ] `flutter test` pasa (hoy 4 tests).
- [ ] La app **sigue funcionando igual que hoy** con Firestore: esta fase
      solo añade, no sustituye.
- [ ] La URL base se configura sin recompilar (o con un mecanismo claro y
      documentado).
- [ ] Documentado en `docs/development.md` cómo apuntar la app al servidor.

## Notas del agente que la ejecuta

(vacío — en progreso)
