# Modelo de datos

Dos modelos de datos coexisten hoy en el repo. Solo el primero está en uso.

## 1. Firestore (EN USO — fuente de verdad actual)

Nombres de colección centralizados en `lib/utils/constantes.dart`
(`FirestoreColecciones`). Reglas de acceso en `firestore.rules`. Índices
compuestos en `firestore.indexes.json`.

| Colección | Tipo | Modelo Dart | Notas |
|---|---|---|---|
| `usuarios` | raíz, doc id = `uid` de Firebase Auth | `lib/models/usuario.dart` | Trabajador o empleador (`tipoUsuario`). Incluye experiencia y estudios embebidos como listas de mapas |
| `usuarios/{uid}/tarjetas` | subcolección | `lib/models/tarjeta.dart` | Tarjetas guardadas del usuario — solo el dueño lee/escribe (`firestore.rules`) |
| `publicaciones` | raíz | `lib/models/publicacion.dart` | Los trabajos publicados. Estados del ciclo de vida en `EstadosTrabajo` (`constantes.dart`) |
| `publicaciones/{id}/evidencias` | subcolección | `lib/models/evidencia.dart` | Avances/evidencias subidas durante el trabajo |
| `postulaciones` | raíz | `lib/models/postulacion.dart` | Un trabajador se postula a una publicación |
| `calificaciones` | raíz | `lib/models/calificacion.dart` | Calificación bidireccional (empleador↔trabajador) al terminar un trabajo |
| `chats` | raíz | `lib/models/chat.dart` | Chat + negociación de pago/tiempo entre empleador y trabajador |
| `mensajes` | ¿raíz o subcolección de `chats`? | — | **Verificar en el código antes de asumir la forma exacta** — no confirmado en este análisis |

Índice compuesto confirmado (`firestore.indexes.json`):
`publicaciones` → `estado ASC, fechaCreacion DESC` (para el feed filtrado por
estado y ordenado por fecha).

### Riesgo de seguridad ya documentado en el propio `firestore.rules`

El archivo trae este comentario, textual, sobre la función `soloMetricas()`
que permite a terceros escribir el campo `saldo` de otro usuario:

> "NOTA: permitir 'saldo' aquí es solo para el prototipo de cartera. En
> producción los movimientos de dinero deben hacerse en un backend seguro."

Es decir: **cualquier usuario autenticado puede hoy escribir el saldo de
cualquier otro usuario** vía reglas de Firestore, mientras el módulo de pagos
siga siendo un prototipo client-side. Esto ya está anotado como pendiente de
`security-agent` en `docs/agent-tasks/` (ver tarea sembrada al crear este
sistema) — no es un hallazgo nuevo, es una decisión de diseño consciente del
equipo anterior que hay que revisar antes de manejar dinero real.

## 2. PostgreSQL vía JPA (DISEÑADO, NO EN USO)

Entidades en `backend/src/main/java/com/trabajito/modules/<módulo>/`, una
tabla por entidad (esquema autogenerado por Hibernate, `ddl-auto=update` —
**no hay migraciones versionadas todavía**, ver `backend/README.md` sección
Pendientes).

| Entidad | Módulo | Corresponde conceptualmente a |
|---|---|---|
| `Usuario` | `usuarios` | `usuarios` de Firestore |
| `Trabajo` | `trabajos` | `publicaciones` de Firestore |
| `Postulacion` | `postulaciones` | `postulaciones` de Firestore |
| `ChatRoom`, `Mensaje`, `Propuesta` | `chats` | `chats` de Firestore, pero modelado con propuestas de negociación como entidad propia |
| `Evidencia` | `evidencias` | subcolección `evidencias` de Firestore |
| `Calificacion` | `calificaciones` | `calificaciones` de Firestore |
| `MovimientoCartera` | `pagos` | no tiene equivalente en Firestore (el "saldo" ahí es un campo suelto en `usuarios`) — aquí es un ledger de movimientos, más seguro |
| `Notificacion` | `notificaciones` | no existe nada equivalente en el lado Flutter/Firestore hoy |
| `Reporte` | `reportes` | no existe nada equivalente en el lado Flutter/Firestore hoy |

**No hay diagrama ER verificado** — este documento lista las entidades por
nombre de archivo, no por relaciones FK reales (no se leyó el código fuente
de cada entidad en detalle). Antes de diseñar una migración real, alguien
debe abrir cada entidad y documentar sus relaciones y constraints aquí.

### Diferencias de modelado a resolver antes de migrar

- Firestore modela pagos como un campo `saldo` embebido en `usuarios` (con el
  riesgo de seguridad de arriba). Postgres modela un ledger (`MovimientoCartera`).
  Son incompatibles tal cual — hay que decidir cuál gana.
- `Notificacion` y `Reporte` no tienen equivalente actual en Firestore — son
  funcionalidad nueva que el backend ya diseñó pero que la app Flutter no usa.

## 3. Redis

No existe en el repo. Sin caché, sin sesiones, sin rate-limiting basado en
Redis hoy. Es parte del stack objetivo, sin trabajo iniciado.
