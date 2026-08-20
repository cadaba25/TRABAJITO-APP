# API del backend (Spring Boot)

El mapa completo y detallado de endpoints ya está documentado en
[`backend/README.md`](../backend/README.md) — no se duplica aquí para evitar
que dos documentos se desincronicen. Este archivo es un resumen de alto nivel
más las reglas que `backend-agent` debe seguir al tocar la API.

**Recuerda:** ningún endpoint de esta API es consumido por la app Flutter
todavía (ver `docs/architecture.md`). Cambiar un contrato aquí hoy no rompe
nada en producción — pero si tu tarea es justo la de empezar a conectar
Flutter a un endpoint, coordínate con `flutter-agent` y documenta el contrato
exacto (request/response) en el reporte de la tarea antes de que el otro lado
lo consuma.

## Grupos de recursos (ver detalle de rutas en `backend/README.md`)

| Base path | Módulo | Auth |
|---|---|---|
| `/api/auth` | registro, login, `/yo` | público (excepto `/yo`) |
| `/api/usuarios` | perfil, ranking, baja de cuenta | JWT |
| `/api/trabajos` | ciclo de vida completo del trabajo (publicar → asignar → iniciar → terminar → aceptar/cancelar/rechazar) | JWT |
| `/api/postulaciones` | postularse, aceptar, retirar | JWT |
| `/api/trabajos/{id}/evidencias` | evidencias de avance | JWT |
| `/api/chats` (+ WebSocket `/ws`) | mensajería y negociación de pago/tiempo | JWT |
| `/api/cartera` | saldo y movimientos (prototipo — sin pasarela real) | JWT |
| `/api/calificaciones` | calificar y ver reseñas | JWT |
| `/api/notificaciones` | notificaciones in-app | JWT |
| `/api/reportes` | denuncias | JWT |
| `/api/admin` | panel de administración | JWT + rol `ADMIN` |
| `/api/archivos` | subida de archivos (a disco local, no S3/object storage) | JWT |

Documentación interactiva (Swagger UI vía springdoc-openapi):
`http://localhost:8080/swagger-ui.html` cuando el backend corre localmente.

## Convenciones que ya sigue el código (no las inventes distinto)

- Auth por header `Authorization: Bearer <token>` (JWT, ver `docs/decisions.md`
  y `backend/src/main/java/com/trabajito/security/`).
- Autorización de "dueño/participante" se resuelve en el `Service`, nunca en
  el cliente ("el cliente nunca decide permisos" — cita textual de
  `backend/README.md`). Cualquier endpoint nuevo debe seguir el mismo patrón.
- Errores centralizados vía `GlobalExceptionHandler` /
  `ApiException` (`backend/src/main/java/com/trabajito/common/exception/`) —
  no lances excepciones genéricas sin mapear.
- DTOs de request/response separados de las entidades JPA (carpeta `dto/`
  dentro de cada módulo) — no expongas entidades directamente en el body.

## Pendientes conocidos (del propio `backend/README.md`, no inventados)

Validación de JWT en el handshake de WebSocket, pasarela de pago real, FCM
para push real, migraciones Flyway/Liquibase, almacenamiento de objetos
(S3/MinIO) en vez de disco local, auto-liberación de escrow y flujo de
disputa. Cualquiera de estos es candidato a tarea de `backend-agent`
coordinada con `security-agent` (varios tocan dinero o auth).
