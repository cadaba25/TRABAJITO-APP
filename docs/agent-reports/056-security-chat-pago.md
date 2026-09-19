# 056 - Revision de seguridad de las tareas 054 y 055 (chat REST + reservar-pago)

Aplica al **backend propio (JWT)**. Firebase no interviene. Veredicto: **APTO condicionado** a la
tarea 057 (SUBSCRIBE STOMP) antes de que el chat use WebSocket o se exponga fuera de la demo.

## Hallazgos
| # | Sev. | Hallazgo | Estado |
|---|---|---|---|
| 1 | Media | `POST /api/chats/{id}/leido` no validaba participante: cualquier autenticado marcaba como leidos los mensajes de un chat ajeno (integridad, no filtra contenido). | ARREGLADO + test |
| 2 | Media | `POST /{id}/mensajes` aceptaba `tipo` del cliente: se podia falsificar `SISTEMA`/`PROPUESTA_*` ("Pago acordado") en el chat. | ARREGLADO + test (400; solo TEXTO/IMAGEN/ARCHIVO) |
| 3 | Media | Sin bloqueo sobre `ChatRoom` (sin `@Version`): `proponer-*`, `aceptar-*` y `reservar-pago` leian/escribian la fila entera sin serializar; un `aceptar` con entidad vieja podia pisar una contraproposicion concurrente y `reservar-pago` podia leer un acuerdo que cambiaba a la vez. | ARREGLADO: `SELECT FOR UPDATE` (`findByIdParaActualizar`, `findByTrabajoIdParaActualizar`) en negociacion y en reservar-pago. Orden de bloqueo trabajo -> chat -> usuario, sin ciclos (la negociacion solo toma chat). Tests unitarios ajustados; la prueba concurrente real (Testcontainers) esta skipped sin Docker: **no verificado contra PostgreSQL**. |
| 4 | Media | **WebSocket SUBSCRIBE sin autorizacion**: `StompAuthChannelInterceptor` solo valida CONNECT. Cualquier usuario con JWT puede suscribirse a `/topic/chats/{id}` y leer mensajes ajenos en vivo (`ChatService.enviar` los empuja). | NO arreglado (cambio de alcance) -> tarea 057 |
| 5 | Baja | `ultimoMensaje` es varchar(255) y el mensaje admite 2000: un mensaje largo podia dar 500. `tiempo` sin `@Size` (255) igual. | ARREGLADO (recorte a 255 y `@Size(max=255)`) + test |
| 6 | Baja | Tras `pagoRetenido` la negociacion sigue abierta: se puede cambiar `pagoMonto` del chat sin efecto en el escrow (el monto vive en `Trabajo.montoAcordado`) pero confunde a la UI. | Reportado, sin arreglar |
| 7 | Info | Cambiar el acuerdo entre aceptar y reservar: cubierto. `proponer-*` pone `acordado=false`; reservar exige acuerdo vigente Y monto/tiempo iguales al del cuerpo. Doble gasto: `retener` bloquea usuario y trabajo esta bloqueado; `pagoRetenido` idempotente. | OK |

## Comprobado sin hallazgos
- IDOR de lectura: `GET /chats/{id}`, `/trabajo/{id}`, `/{id}/mensajes` (+`desde`), `/no-leidos` filtran por participante (403/404); `no-leidos` solo cuenta chats propios.
- `ChatRoom`/`Mensaje` serializados como entidad: solo exponen ids/nombres de los dos participantes y contenido del propio chat; ningun dato de terceros (sin correo, telefono ni saldo).
- Validacion: contenido `@NotBlank/@Size(2000)`, monto `@Positive` (+ `MontoDinero` en reservar), `desde` mal formado lo rechaza Spring (400).
- Primera propuesta de pago solo del trabajador (servicio); test agregado (empleador 400, ajeno 403).
- CONNECT STOMP sigue exigiendo JWT (`StompAuthChannelInterceptor`, `WebSocketAuthTest` 3/3 pasan).

## Verificacion
`mvn -o test` completo (JDK 24 + flags indicados): 142 tests, 0 fallos, 8 skipped (concurrencia, requiere Docker).
Tests nuevos en `ChatHttpTest`: marcarLeidoAjeno, tipoFalsificado, largos, primeraPropuestaTrabajador.
Tarea derivada: `docs/agent-tasks/057-autorizar-subscribe-stomp-chat.md`.
