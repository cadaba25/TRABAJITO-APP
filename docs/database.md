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

Es decir: **cualquier usuario autenticado puede escribir el saldo de
cualquier otro usuario** vía reglas de Firestore, mientras el módulo de pagos
siga siendo un prototipo client-side. Esto fue revisado en la tarea
`docs/agent-tasks/002-revisar-riesgo-saldo-firestore.md` (ver
`docs/decisions.md` ADR-0004 para el análisis completo): se confirmó que el
vector explotable de verdad era que un tercero podía REDUCIR el saldo de
otro usuario sin ninguna relación real (sabotaje/DoS de cartera) — eso ya
está mitigado en `firestore.rules` (un tercero solo puede incrementar el
saldo ajeno, nunca reducirlo). **Sigue sin resolver:** un tercero aún puede
fijar los campos de reputación de otro usuario
(`calificacionPromedio`/`totalCalificaciones`/`trabajosCompletados`/
`trabajosPublicados`/`pagosConfirmados`) a cualquier valor, sin relación
real — ver `docs/agent-tasks/004-endurecer-metricas-terceros-firestore.md`.

## 2. PostgreSQL vía JPA (DISEÑADO, NO EN USO)

Entidades en `backend/src/main/java/com/trabajito/modules/<módulo>/`, una
tabla por entidad (esquema autogenerado por Hibernate, `ddl-auto=update` —
**no hay migraciones versionadas todavía**, ver `backend/README.md` sección
Pendientes).

| Entidad | Módulo | Corresponde conceptualmente a |
|---|---|---|
| `Usuario` | `usuarios` | `usuarios` de Firestore |
| `Habilidad` | `usuarios` | el array `habilidades` de Firestore, **una fila por etiqueta** (tabla `habilidades`, FK a `usuarios`) |
| `Experiencia` | `usuarios` | la lista embebida `experiencia`, **una fila por puesto** (tabla `experiencias`, FK a `usuarios`) |
| `Estudio` | `usuarios` | la lista embebida `estudios`, **una fila por estudio** (tabla `estudios`, FK a `usuarios`) |
| `Trabajo` | `trabajos` | `publicaciones` de Firestore |
| `Postulacion` | `postulaciones` | `postulaciones` de Firestore |
| `ChatRoom`, `Mensaje`, `Propuesta` | `chats` | `chats` de Firestore, pero modelado con propuestas de negociación como entidad propia |
| `Evidencia` | `evidencias` | subcolección `evidencias` de Firestore |
| `Calificacion` | `calificaciones` | `calificaciones` de Firestore (incluye `rolCalificado`, igual que allí) |
| `MovimientoCartera` | `pagos` | no tiene equivalente en Firestore (el "saldo" ahí es un campo suelto en `usuarios`) — aquí es un ledger de movimientos, más seguro |
| `Notificacion` | `notificaciones` | no existe nada equivalente en el lado Flutter/Firestore hoy |
| `Reporte` | `reportes` | no existe nada equivalente en el lado Flutter/Firestore hoy |
| `IntentoLogin`, `RefreshToken` | `auth` | freno de fuerza bruta y sesión revocable (ADR-0010); no existen en Firestore |

**Relaciones reales.** Casi todo el esquema referencia por **UUID suelto**, sin
clave ajena: `trabajos.empleador_id`, `postulaciones.trabajador_id`,
`calificaciones.receptor_id`… no tienen `FOREIGN KEY` en la base. Las **únicas
tres FK reales** son las que introdujo la tarea 019 (ADR-0011):
`fk_habilidades_usuario`, `fk_experiencias_usuario` y `fk_estudios_usuario`,
todas hacia `usuarios(id)`. Que el resto no las tenga es deuda conocida, no un
descuido documental.

### El perfil del usuario (tarea 019, ADR-0011)

La tabla `usuarios` **ya guarda todo lo que recoge el registro de 5 pasos de
Flutter**. Hasta el 2026-08-27 no era así, y eso bloqueaba la fase 2 de la
migración (ADR-0009): migrar el perfil habría perdido datos que el usuario ve.

| Grupo | Columnas |
|---|---|
| Identidad | `correo`, `password_hash`, `nombres`, `apellidos`, `dni`, `rol`, `activo`, `registro_completo`, `creado_en` |
| Contacto | `telefono`, `telefono_emergencia` |
| Personales | `fecha_nacimiento` (`date`), `genero` |
| Ubicación | `departamento`, `ciudad`, `codigo_postal`, `pais`, `vive_en_honduras` |
| Perfil | `foto_url`, `presentacion`, `url_cv` |
| Empresa (empleador) | `tipo_empleador`, `nombre_empresa`, `rtn`, `cargo_contacto`, `sector_empresa`, `tamano_empresa`, `sitio_web`, `descripcion_empresa` |
| Actividad | `trabajos_completados`, `trabajos_publicados`, `pagos_confirmados` |
| Reputación | `calificacion_promedio`, `total_calificaciones` (global) + `calificacion_como_trabajador`, `total_calificaciones_como_trabajador`, `calificacion_como_empleador`, `total_calificaciones_como_empleador` |
| Cartera | `saldo` (`numeric(12,2)`, `CHECK (saldo >= 0)`) |

Y el CV en tres tablas hijas:

| Tabla | Columnas | Notas |
|---|---|---|
| `habilidades` | `usuario_id`, `habilidad` | única `(usuario_id, habilidad)`; índice sobre `habilidad` para poder **filtrar el feed por habilidad** |
| `experiencias` | `usuario_id`, `empresa`, `puesto`, `habilidades`, `descripcion`, `fecha_inicio`, `fecha_fin`, `trabaja_actualmente` | fechas en **texto** (`MM/AAAA`: son parciales) |
| `estudios` | `usuario_id`, `nivel`, `centro`, `fecha_inicio`, `fecha_fin`, `cursando_actualmente` | ídem |

**Equivalencias con el modelo de Firestore que conviene tener a mano al migrar:**
el `estado` (`activo`/`suspendido`) de Firestore es el booleano `activo` de
Postgres —no hay columna `estado`—; `fechaRegistro` es `creado_en`;
`fotoPerfil` es `foto_url`; y `tipoUsuario`/`rol`, que allí eran dos campos, aquí
son el mismo enum `rol`. La `fechaNacimiento` allí es texto `dd/MM/yyyy` y aquí
es `date`: la API acepta los dos formatos al escribir y **siempre devuelve ISO**.

### Diferencias de modelado a resolver antes de migrar

- Firestore modela pagos como un campo `saldo` embebido en `usuarios` (con el
  riesgo de seguridad de arriba). Postgres modela un ledger (`MovimientoCartera`).
  Son incompatibles tal cual — hay que decidir cuál gana.
- `Notificacion` y `Reporte` no tienen equivalente actual en Firestore — son
  funcionalidad nueva que el backend ya diseñó pero que la app Flutter no usa.
- **Ya resuelto (tarea 019):** el perfil del trabajador (habilidades,
  experiencia, estudios y los 11 campos sueltos que faltaban) y la reputación,
  que en Firestore es un único promedio y aquí son dos, una por rol.
- **Sigue sin resolver:** no existe entidad ni tabla de **tarjetas** de pago;
  `Postulacion` no lleva los campos desnormalizados que las listas de Firestore
  usaban (`tituloTrabajo`, `empleadorId`) ni `Calificacion` lleva `autorNombre`;
  y no hay contador de **mensajes no leídos por chat** (el backend marca `leido`
  mensaje a mensaje). Ver los pendientes de las tareas 018 y 019.

## 3. Redis

No existe en el repo. Sin caché, sin sesiones, sin rate-limiting basado en
Redis hoy. Es parte del stack objetivo, sin trabajo iniciado.
