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
| `/api/trabajos` | ciclo de vida completo del trabajo (publicar → asignar → iniciar → entregar → aceptar / cancelar / rechazar / reclamar) | JWT |
| `/api/postulaciones` | postularse, aceptar, retirar | JWT |
| `/api/trabajos/{id}/evidencias` | evidencias de avance | JWT |
| `/api/chats` (+ WebSocket `/ws`) | mensajería y negociación de pago/tiempo | JWT |
| `/api/cartera` | saldo y movimientos (prototipo — sin pasarela real) | JWT |
| `/api/calificaciones` | calificar y ver reseñas | JWT |
| `/api/notificaciones` | notificaciones in-app | JWT |
| `/api/reportes` | denuncias | JWT |
| `/api/admin` | panel de administración **y resolución de disputas de dinero** | JWT + rol `ADMIN` |
| `/api/archivos` | subida de archivos (a disco local, no S3/object storage) | JWT |

Documentación interactiva (Swagger UI vía springdoc-openapi):
`http://localhost:8080/swagger-ui.html` cuando el backend corre localmente.

## Reglas de negocio que la API impone (ADR-0007, tarea 010)

El principio, en palabras del dueño del proyecto: *"nunca ninguna de las dos
partes debe tener la ventaja de irse ganando"*. Traducido a contratos de API:

- **Cancelar solo antes de iniciar.** `POST /api/trabajos/{id}/cancelar` se
  admite desde `ACTIVO`/`ASIGNADO`/`ACORDADO`; desde `EN_PROGRESO` responde
  `409` y no mueve el escrow. Lo mismo para el trabajador con
  `POST /api/trabajos/{id}/rechazar`: la regla es simétrica.
- **El empleador elige el destino al cancelar.** El body
  `{"reabrir": true|false}` es **obligatorio** (`true` → el trabajo vuelve al
  feed como `ACTIVO`; `false` → queda `CANCELADO`). Sin ese campo, `400`.
- **Entregar exige evidencias.** `POST /api/trabajos/{id}/terminar` responde
  `409` si el trabajador no subió ninguna evidencia
  (`POST /api/trabajos/{id}/evidencias`). Tras una petición de corrección hace
  falta una evidencia **posterior** a esa petición.
- **Reclamar a soporte congela el dinero.**
  `POST /api/trabajos/{id}/reclamar` (motivo obligatorio, lo pueden usar las
  **dos** partes) deja el trabajo `EN_DISPUTA` con el escrow retenido: ni
  `aceptar`, ni `cancelar`, ni `rechazar` lo mueven (`409`). Abre un `Reporte`
  `ABIERTO` para la bandeja de soporte.
- **Solo un `ADMIN` descongela.** `GET /api/admin/trabajos/en-disputa` lista la
  cola y `POST /api/admin/trabajos/{id}/resolver-disputa` con
  `{"aFavorDe":"TRABAJADOR"|"EMPLEADOR","resolucion":"..."}` libera o
  reembolsa. No hay repartos parciales todavía.

La tabla completa de transiciones (desde qué estado, quién puede, qué pasa con
el escrow) está en `docs/decisions.md` → ADR-0007. El mapa de rutas detallado
sigue en `backend/README.md`.

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
- **Los campos que otorgan privilegios no se aceptan del cliente.** Concreto:
  `POST /api/auth/registro` (público) solo admite `rol` = `TRABAJADOR` o
  `EMPLEADOR`; su DTO usa el enum `RolPublico`, que no incluye `ADMIN`, y
  cualquier otro valor responde 400 sin crear usuario (ADR-0005, tarea 008).
  No existe endpoint para crear ni promover administradores: se aprovisionan
  con `ADMIN_INICIAL_CORREO`/`ADMIN_INICIAL_PASSWORD` o con SQL de operación
  (ver `backend/README.md` → "Cómo se crea un ADMIN"). Si añades un endpoint
  que escriba `rol`, `saldo`, `activo` o cualquier campo de reputación,
  coordina con `security-agent`: son datos que el dueño del registro **no**
  debe poder fijar por sí mismo.

## Pendientes conocidos (del propio `backend/README.md`, no inventados)

Validación de JWT en el handshake de WebSocket, pasarela de pago real, FCM
para push real, migraciones Flyway/Liquibase, almacenamiento de objetos
(S3/MinIO) en vez de disco local y auto-liberación de escrow por inactividad.
El **flujo de disputa mínimo ya existe** desde la tarea 010 (ADR-0007:
`reclamar` + resolución por `ADMIN`); lo que no existe es un sistema completo
con plazos, apelaciones, chat de disputa ni repartos parciales, ni notificación
a las partes cuando se abre o se resuelve una. Cualquiera de estos es candidato
a tarea de `backend-agent` coordinada con `security-agent` (varios tocan dinero
o auth).
