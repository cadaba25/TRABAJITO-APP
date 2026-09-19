---
id: 053
titulo: "Migrar chat_service de Firestore a la API REST (sondeo) y cerrar la costura de reservar-pago"
estado: todo
agente: "flutter-agent"
creada: 2026-09-18
rama: "feature/053-chat-a-api"
---

## Objetivo
Última pieza de Firestore en `lib/`. Ver ADR-0018: REST + sondeo, sin STOMP.
Dependencia: **tarea 052 en `en-revision` o `hecho`** (ramar desde su rama, o
desde `develop` si ya se mergeó). Motivo: ambas tocan `proveedores.dart` y
`detalle_trabajo_screen.dart`.

## Contexto relevante
`docs/api.md` y `ChatController` (`/api/chats`, `/{id}`, `/{id}/mensajes`
(GET/POST), `/{id}/leido`, `/proponer-pago`, `/aceptar-pago`, `/proponer-tiempo`,
`/aceptar-tiempo`). **Verifica los DTO reales y los nombres de parámetro contra
el código Java y contra el servidor**, no supongas (regla de oro 3).

## Módulos afectados y orden de trabajo
Solo Flutter (`lib/`, `test/`). Si el contrato REST no alcanza para algo que
la app hace hoy, PARA y repórtalo al tech-lead (no toques `backend/`).
1. Nuevo `lib/funcionalidades/chat/datos/chat_service.dart` (API), modelos
   `Chat`/`Mensaje` con `desdeJson`; inyectado por `provider`.
2. `chat_screen.dart` y `chats_tab.dart` → `funcionalidades/chat/pantallas/`,
   sondeo con `Timer` cancelado en `dispose` y pausado en background.
3. `DetalleTrabajoScreen._reservarPago`: el acuerdo de pago sale del chat REST,
   no de Firestore. Cero `cloud_firestore` en `lib/` al terminar (los modelos
   `desdeFirestore` muertos se eliminan si nada los usa).
4. Tests de servicio (respuestas simuladas) y de las pantallas de chat.

## Criterios de aceptación
- [ ] `grep -r cloud_firestore lib` vacío (o justificado).
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde.
- [ ] Archivos nuevos <300 líneas; sin `final _s = Servicio();` en States.
- [ ] Reporte en `docs/agent-reports/053-...md` con lo probado y lo NO probado.

## Notas del agente que la ejecuta
