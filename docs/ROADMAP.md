# Roadmap Trabajito — Camino al MVP público

> Flujo principal objetivo: **Contratador publica → Trabajador encuentra → Trabajador se postula → Contratador selecciona → Trabajo se realiza → Se marca completado → Ambos se califican.**

## Estado actual (hecho)
Registro, login, roles, navegación inferior, pantallas Trabajos/Trabajadores/Ranking/Perfil, configuración, tema claro/oscuro, marca V1.0, publicación de trabajos, gestión de "Mis publicaciones".

## Fases
- **A — Núcleo del flujo (MVP):** T1–T7.
- **B — Confianza/seguridad (pre-lanzamiento):** T8–T10.
- **C — Retención (post-MVP):** notificaciones push, chat, búsqueda/filtros, CV/fotos, pagos, reportes.

## Orden de implementación

| # | Funcionalidad | Dificultad | Horas | Depende de |
|---|---|---|---|---|
| 1 | Detalle de Trabajo | Fácil-Medio | 4–6 | — |
| 2 | Postulación (trabajador) | Medio | 5–7 | T1 |
| 3 | Mis Postulaciones | Fácil-Medio | 4–5 | T2 |
| 4 | Bandeja de Postulantes + perfil postulante | Medio | 5–7 | T2 |
| 5 | Selección / Asignación | Medio-Difícil | 5–7 | T4 |
| 6 | Ciclo de vida + Completado | Medio | 4–6 | T5 |
| 7 | Calificación bidireccional | Difícil | 8–10 | T6 |
| 8 | Reglas de seguridad Firestore | Medio | 3–5 | T2–T7 |
| 9 | Pulido + estados vacíos | Fácil-Medio | 4–6 | todo |
| 10 | Reset/verificación de correo | Fácil | 3–4 | — |

## Plan semanal (2–4 h/día)
| Semana | Objetivo |
|---|---|
| 1 | T1 Detalle + T2 Postulación |
| 2 | T3 Mis Postulaciones + T4 Bandeja de Postulantes |
| 3 | T5 Selección + T6 Completado |
| 4 | T7 Calificación bidireccional |
| 5 | T8 Reglas de seguridad + T9 Pulido |
| 6 | T10 Reset de contraseña + beta → MVP público |

## Cambios en Firebase
| Colección | Acción | Campos clave | Índices |
|---|---|---|---|
| `publicaciones` | Modificar | estado(activo/asignado/en_progreso/completado/cerrado), uidTrabajadorAsignado, nombreTrabajadorAsignado, fechaAsignacion, fechaCompletado, calificadoPorEmpleador, calificadoPorTrabajador | (estado, fechaCreacion DESC) |
| `postulaciones` | Crear | idPublicacion, uidTrabajador, uidEmpleador, nombreTrabajador, mensaje, estado, fechaPostulacion | (idPublicacion, fecha DESC), (uidTrabajador, fecha DESC) |
| `calificaciones` | Crear | idPublicacion, deUid, paraUid, rolCalificado, estrellas, comentario, fecha | (paraUid, fecha DESC) |
| `usuarios` | Modificar | calificacionPromedio, totalCalificaciones (trabajosCompletados ya existe) | — |

> docId determinista en `postulaciones` = `{idPublicacion}_{uidTrabajador}` para evitar duplicados sin índices extra.

## Pantallas
- **Modificar:** TrabajosTab, MisPublicacionesScreen, PerfilTab, RankingTab, PublicacionService.
- **Ocultar temporalmente (MVP):** TrabajadoresTab y RankingTab (hasta que existan calificaciones).
- **Crear:** DetalleTrabajoScreen, PostularseSheet, MisPostulacionesScreen, PostulantesScreen, DetalleTrabajadorScreen, CalificarSheet.
