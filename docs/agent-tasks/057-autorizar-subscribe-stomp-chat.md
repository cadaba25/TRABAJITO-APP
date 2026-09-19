---
id: 057
titulo: "Autorizar SUBSCRIBE STOMP por participante + autorNombre en CalificacionResponse"
estado: en-revision
agente: "backend-agent"
creada: 2026-09-18
rama: "feature/057-subscribe-stomp-autor"
---

# 057 - Autorizar SUBSCRIBE STOMP a /topic/chats/{id} por participante

- Parte B (agregada): `autorNombre` aditivo en `CalificacionResponse` (la app lo lee; sin él las reseñas salían "Anónimo").

- Origen: hallazgo 4 de `docs/agent-reports/056-security-chat-pago.md`. Severidad media.
- Problema: solo el CONNECT valida JWT; cualquier usuario autenticado puede suscribirse al topic de cualquier chat y leer mensajes ajenos.
- Alcance (backend-agent, revisa security-agent): en `StompAuthChannelInterceptor` (o un interceptor aparte) manejar `SUBSCRIBE`: extraer chatId de `/topic/chats/{id}`, exigir `ChatRoom.esParticipante(principal.id)`, rechazar el resto de destinos `/topic/**` desconocidos. Alternativa: dejar de empujar por WS (ADR-0018 usa sondeo REST).
- Tests: suscripcion de participante OK, de ajeno rechazada.
- Prioridad: antes de migrar el chat a WS o de exponer el backend fuera de la demo.
