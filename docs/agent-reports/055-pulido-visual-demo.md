---
tarea: 055-pulido-visual-demo
agente: flutter-agent (frontend visual)
fecha: 2026-09-18
estado: en-revision (alcance parcial, ver "Que falta")
---

## Resumen

Base: `feature/barrido-contraste-dorado` (051). Rama `feature/055-pulido-visual-demo`.
Solo capa visual; no se tocaron servicios, backend, chat/cartera/calificaciones ni contratos.

## Antes / despues

| Sitio | Antes | Despues |
|---|---|---|
| Badge de chats no leidos (`inicio_screen`) | numero blanco sobre dorado (1.63:1) | `AppColores.principal` sobre dorado (10.67:1) |
| FAB "Publicar" (`inicio_screen`, `mis_publicaciones_screen`) | texto/icono blanco sobre dorado | `AppColores.principal` |
| Circulo de camara (`formulario_editar_perfil`) | icono blanco sobre dorado | icono `principal` |
| `_badgeEstado` (`detalle_trabajo_screen`) | `AppColores.dorado` como texto | `AppColores.acento` + texto via `colorAcentoTexto` |
| SnackBars (`app_tema`, claro y oscuro) | pegados al borde, esquinas por defecto | flotantes con `AppRadios.chip` |

`tarjeta_trabajo` no tenia `_badgeEstado` (la 051 lo listaba en ambos; solo existe en el detalle).

## Que falta (honesto)

No hice el recorrido completo pantalla por pantalla (login, feed, postulaciones, perfil):
solo cerre los hallazgos concretos de la 051 y un ajuste global de tema. Los estados
vacio/carga/error ya existen como widgets (`estados_feed`, `estados_postulantes`,
`estados_mis_publicaciones`) y no los revise a fondo. Micro-interacciones: ya existen
`PulsaConEscala` y `CambioDeEstado`; no anadi mas. `detalle_trabajo_screen.dart` sigue en
~1240 lineas (excede el techo desde antes; no se reorganizo). Sin cambios en
chat/cartera/calificaciones. No se pudo ver la app en emulador: no lo intente; verificado solo con analyze y tests.

## Verificacion

- `flutter analyze`: 12 issues, todas preexistentes, 0 nuevas.
- `flutter test`: 298 pasan (296 + 2 nuevos en `test/nucleo/tema/tema_pulido_055_test.dart`).
- Sin dependencias nuevas.

## Que mostrar en la demo

1. Login / bienvenida de registro (titulo y enlaces dorados legibles).
2. Feed de trabajos con toggle y chips de plazo activos, tarjetas con precio.
3. Detalle de trabajo: chips de categoria y badge de estado en tono legible.
4. Boton "Publicar" y badge de chats en modo claro (ya con contraste).
5. Alternar modo claro/oscuro desde Configuracion.
6. Feedback con snackbars flotantes (p. ej. al calificar o postular).
7. Estados vacios/error nuevos: Mis publicaciones sin datos ("Publicar un trabajo") y forzar un error para ver "Reintentar".

## Segunda pasada (estados y micro-interacciones)

- Nuevo `lib/compartido/widgets/estado_pantalla.dart` (`EstadoPantalla`): icono Lucide en circulo de
  `colorSuperficieAlterna`, mensaje, detalle y CTA opcional; claro y oscuro (test en ambos).
- Reemplaza los iconos grises sueltos de los estados de feed, mis publicaciones, postulantes y mis postulaciones.
  Copy nuevo con siguiente paso ("Cuando alguien se postule, aparecera aqui", etc.).
- CTA: mis publicaciones vacio -> "Publicar un trabajo"; error en mis publicaciones, postulantes y mis postulaciones
  -> "Reintentar" (llaman al `_cargar` existente; sin cambio de logica). Feed: solo copy, sin CTA (el FAB "Publicar" ya
  esta; no se hizo plumbing por `FilaFeed`).
- Iconos Lucide (ADR-0017) en esos estados en lugar de `Icons.*`.
- Micro-interaccion: `PulsaConEscala` en las tarjetas de eleccion de rol (`bienvenida_registro_screen`) y en
  `tarjeta_tipo_empleador`.
- Revisado por grep: no quedan colores hex ni `Colors.white` fuera de cabeceras de degradado oscuro (intencional).
  Pendiente menor: `fontSize: 20` suelto en `campo_fecha_nacimiento.dart`.
- La revision de login/registro/perfil/detalle fue por codigo y grep, NO en pantalla.
- Tests: `test/compartido/estado_pantalla_test.dart` (+5). Total 303 verdes; analyze 12 issues, ninguna nueva.
- Emulador: `adb` no esta disponible en este entorno; no se lanzo Pixel_6 ni se tomaron capturas.
