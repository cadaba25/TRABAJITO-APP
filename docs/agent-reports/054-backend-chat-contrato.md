# 054 — Contrato REST del chat para la demo (backend-agent)

Rama `feature/054-backend-chat-demo` (desde `docs/plan-demo-completa`). Insumo
para la tarea 053 (flutter-agent, ADR-0018: REST + sondeo). Sin push ni merge.

## 1. Comparación Firestore vs. `/api/chats`

| Función de `lib/services/chat_service.dart` | Equivalente REST | Estado |
|---|---|---|
| `streamMisChats` | `GET /api/chats` (sondear) | OK; ya viene ordenado por `fechaUltimoMensaje` desc |
| `obtenerChat(id)` / `streamChat` | `GET /api/chats/{id}` | OK |
| chat id = `idPublicacion` (trabajo) | `GET /api/chats/trabajo/{trabajoId}` | **BRECHA CERRADA** (nuevo): el id REST es un UUID propio, no el del trabajo |
| `asegurarChat` (crear/reparar) | El chat lo crea el backend al aceptar la postulación (`PostulacionService` → `crearParaTrabajo`). No hay `POST` de creación | **Diferencia**: el cliente NO crea chats; si no existe, `GET /trabajo/{id}` da 404 (trabajo sin asignar). Trabajos asignados antes del backend no tienen chat (no aplica a datos nuevos de demo) |
| `streamMensajes` | `GET /api/chats/{id}/mensajes` (sondear) | OK; **nuevo** `?desde=<ISO-8601>` para sondeo incremental |
| `enviarMensaje` | `POST /api/chats/{id}/mensajes` | OK; **nuevo** tope 2000 chars → 400 (antes 500 por la BD) |
| `marcarLeido` | `POST /api/chats/{id}/leido` | OK (200, cuerpo vacío) |
| `noLeidos` por chat y `streamTotalNoLeidos` | `GET /api/chats/no-leidos` | **BRECHA CERRADA** (nuevo): `ChatRoom` no traía contadores |
| `proponerPago` / `aceptarPago` | `POST .../proponer-pago`, `.../aceptar-pago` | OK; `aceptar-pago` ahora idempotente (no repite el mensaje de sistema) |
| `proponerTiempo` / `aceptarTiempo` | `POST .../proponer-tiempo`, `.../aceptar-tiempo` | OK; idem idempotente |

Todos exigen JWT y ser participante (ajeno → 403, chat inexistente → 404).
Formato de error: ver `docs/api.md` (ADR-0008).

### Diferencias de semántica que el cliente debe absorber
- Campos: el texto es `contenido` (no `texto`), la fecha es `creadoEn`
  (no `fecha`), no existe `participantes` (se deduce de `empleadorId` y
  `trabajadorId`) ni `idPublicacion` (es `trabajoId`).
- `tipo` es enum en MAYÚSCULAS: `TEXTO, IMAGEN, ARCHIVO, PROPUESTA_PAGO,
  PROPUESTA_TIEMPO, SISTEMA`. Firestore usaba `texto`/`sistema`. Las propuestas
  son mensajes `PROPUESTA_*` y las aceptaciones `SISTEMA`.
- Sin propuesta: `pagoPropuestoPor` / `tiempoPropuestoPor` / `tiempoValor` son
  `null` (Firestore: cadena vacía); `pagoMonto` es `0`.
- Regla nueva que Firestore no tenía: la **primera** propuesta de pago la debe
  hacer el trabajador (si no: 400 `"La primera propuesta la hace el trabajador"`).
- Aceptar la propia propuesta o sin propuesta: 400 `"No hay una propuesta de
  pago de la otra parte"` (texto distinto al del cliente viejo).
- Proponer de nuevo tras acordar reinicia `pagoAcordado=false` (igual que hoy).
- Textos que pone el servidor (el cliente no los arma): `"Propuesta de pago:
  L. 150.00 / hora"`, `"Pago acordado: L. 150.00 / hora"`, `"Propuesta de
  tiempo: 3 días"`, `"Tiempo acordado: 3 días"`.

## 2. Formas JSON (verificadas con `ChatHttpTest`)

`ChatRoom` (respuesta de `GET /api/chats` [array], `/{id}`, `/trabajo/{id}` y de
las 4 acciones de negociación). Se serializa la entidad directamente:
```json
{
  "id": "uuid", "creadoEn": "2026-09-18T19:27:32.101Z", "actualizadoEn": "2026-09-18T19:27:32.101Z",
  "trabajoId": "uuid", "tituloTrabajo": "Pintar fachada",
  "empleadorId": "uuid", "empleadorNombre": "Ana Pérez",
  "trabajadorId": "uuid", "trabajadorNombre": "Luis Mejía",
  "ultimoMensaje": "Chat iniciado. ¡Acuerden el pago y el tiempo!",
  "fechaUltimoMensaje": "2026-09-18T19:27:32.101Z",
  "pagoMonto": 150.00, "pagoPropuestoPor": "uuid|null", "pagoAcordado": false,
  "tiempoValor": "3 días|null", "tiempoPropuestoPor": "uuid|null", "tiempoAcordado": false
}
```
`Mensaje` (`GET /{id}/mensajes` devuelve array ascendente por `creadoEn`; el
`POST` devuelve uno):
```json
{ "id": "uuid", "creadoEn": "2026-09-18T19:27:32.5Z", "actualizadoEn": "...",
  "chatId": "uuid", "deUid": "uuid", "tipo": "TEXTO",
  "contenido": "hola", "leido": false }
```
Requests: envío `{"contenido":"hola"}` (`tipo` opcional, default `TEXTO`;
el cliente no debería mandarlo); `{"monto":150}` (proponer-pago, > 0);
`{"tiempo":"3 días"}` (proponer-tiempo, no vacío). `aceptar-*` y `leido` no
llevan cuerpo.

`GET /api/chats/no-leidos`:
```json
{ "total": 3, "porChat": { "<chatId-uuid>": 2, "<otro-uuid>": 1 } }
```
Cuenta mensajes del otro participante con `leido=false`; incluye todos los
chats del usuario (con 0).

Sondeo sugerido: lista + `no-leidos` cada ~5 s en la pestaña; dentro de un chat
`GET /{id}/mensajes?desde=<creadoEn del último>` cada 2-3 s (filtro
estrictamente posterior, Instant ISO-8601 con Z; formato inválido → 400).

## 3. `reservar-pago`: NO toma el acuerdo del chat

`POST /api/trabajos/{id}/reservar-pago` (solo el empleador; trabajo en
`ASIGNADO`; devuelve `TrabajoResponse`):
```json
{ "monto": 150.00, "tiempo": "3 días" }
```
`monto` obligatorio y positivo; `tiempo` opcional. **El backend no consulta
`chat_rooms`**: usa tal cual lo que manda el cliente, retiene ese monto de la
cartera del empleador (400 `Saldo insuficiente. Recarga tu cartera.`) y guarda
`montoAcordado`/`tiempoAcordado` en el trabajo → `ACORDADO`. Idempotente si ya
estaba retenido; 409 si el estado no es `ASIGNADO`.

Cómo debe llamarlo el cliente: leer el chat (`GET /api/chats/trabajo/{id}`),
comprobar `pagoAcordado && tiempoAcordado` y enviar `monto = pagoMonto`,
`tiempo = tiempoValor`. Nota: el chat habla de "por hora" pero el trabajo lo
trata como monto total retenido; conserva lo que la app manda hoy, no lo cambié.

## 4. Brechas grandes (solo reporte, no tocadas)
1. **Integridad**: `reservar-pago` no verifica que el chat esté acordado ni que
   `monto/tiempo` coincidan con él; un cliente modificado del empleador puede
   retener un monto distinto al pactado. Corregirlo cambia un contrato ya
   consumido (nuevos 400/409): decisión de tech-lead/security-agent. No bloquea la demo.
2. `ChatRoom` y `Mensaje` se exponen como entidades JPA (sin DTO), contra la
   convención; cualquier campo nuevo de la entidad se filtra al JSON.
3. `GET /{id}/mensajes` sin paginación (carga inicial trae todo el historial);
   `desde` y `marcarLeido` filtran/iteran en memoria. Aceptable para demo.
4. Cada `POST` de mensaje también empuja por STOMP `/topic/chats/{id}`; inocuo
   con sondeo.

## 5. Cambios hechos (aditivos; ningún contrato consumido cambia)
- `ChatController`/`ChatService`: `GET /trabajo/{trabajoId}`, `GET /no-leidos`,
  `?desde=` en mensajes, `@Size(max=2000)`, idempotencia de `aceptar-pago/tiempo`.
- Nuevo `backend/src/test/java/com/trabajito/modules/chats/ChatHttpTest.java`
  (5 tests, MockMvc + H2).
- `docs/api.md`: sección "Chat".

## 6. Verificación
- Maven existe pero no había JDK en el PATH; se usó
  `C:\Users\enigm\.jdks\temurin-24.0.2`. Con JDK 24 hay que pasar
  `-Dmaven.compiler.proc=full -Dlombok.version=1.18.40` (el Lombok del BOM no
  soporta JDK 24). Sin cambios en `pom.xml`.
- Compila. `ChatHttpTest` 5/5 verde; `TarjetaHttpTest`, `PerfilCompletoHttpTest`
  y `TrabajitoApplicationTests` verdes.
- NO verdes en este entorno: `AuthServiceTest`, `PostulacionServiceTest`,
  `TrabajoServiceTest` (54 errores) por `MockitoException: Could not modify all
  classes` (Mockito/ByteBuddy vs JDK 24). No toco esos servicios, pero **no lo
  pude comprobar con JDK 17**, que es el del proyecto.
- No se corrió `backend/scripts/prueba-flujo-negocio.sh` (requiere servidor y
  PostgreSQL) ni se probó contra PostgreSQL real.
