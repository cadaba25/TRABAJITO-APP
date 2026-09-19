# Reporte 057 - SUBSCRIBE STOMP por participante + autorNombre

Rama: `feature/057-subscribe-stomp-autor` (desde `feature/056-security-chat-pago`). Sin push ni merge.

## A. SUBSCRIBE STOMP
- `security/StompAuthChannelInterceptor`: nuevo manejo de `SUBSCRIBE`. Deny by default: solo `/topic/chats/{uuid}` y solo si `ChatRoom.esParticipante(principal.id)`. Rechaza (StompAuthException -> frame ERROR) chat inexistente, id malformado, cualquier otro destino y sesion sin usuario. Misma respuesta para "no existe" y "no es tuyo".
- El constructor recibe ahora `ChatRoomRepository` (el bean se inyecta solo; nadie lo construia a mano).
- Cambio en `security/`: requiere revision de security-agent antes de mergear.
- Limite conocido: no se filtra `SEND` a `/app/**` (no hay handlers `@MessageMapping`; el chat publica por REST). Sin cambios en el CONNECT.

## B. autorNombre
- `CalificacionResponse` gana `autorNombre` (aditivo, campos existentes intactos). `CalificacionService.nombresDeAutores` resuelve los nombres con una sola consulta (`findAllById`); el controller lo usa en POST y en GET `/usuario/{id}`. Si el autor no existe queda `null`.

## Tests
- Nuevos: `StompSubscribeAutorizacionTest` (4: participante empleador/trabajador OK, ajeno, inexistente, malformado/otro destino/sin usuario), `CalificacionAutorNombreTest` (1).
- `mvn test` completo (JDK temurin-24.0.2 con los flags indicados): 147 tests, 0 fallos, BUILD SUCCESS. `WebSocketAuthTest` (3) sigue verde.
- No hay test de integracion con cliente STOMP real que suscriba (solo unitario del interceptor con mensajes construidos); tampoco test HTTP del JSON de calificaciones.
