---
tarea: 061-contraste-chat-calificar
agente: flutter-agent
fecha: 2026-09-18
estado: en-revision
---

## Cambios

- `lib/compartido/widgets/boton_primario.dart`: nuevo parametro opcional `colorTexto` (foregroundColor cuando se pasa `color`).
- `lib/funcionalidades/trabajos/pantallas/detalle_trabajo_screen.dart`: "Calificar" usa `colorTexto: AppColores.principal` (10.67:1 sobre dorado).
- `lib/funcionalidades/chat/widgets/burbuja_mensaje.dart`: texto propio `AppColores.principal` sobre dorado, ambos temas.
- `lib/funcionalidades/chat/pantallas/chats_tab.dart`: titulo del trabajo e inicial del avatar con `colorAcentoTexto`; numero del badge de no leidos (blanco sobre dorado) a `principal`.
- `lib/funcionalidades/chat/widgets/panel_negociacion.dart`: `_BotonMini` con `colorTexto`; "Proponer" y "Contraproponer" usan `colorAcentoTexto` (el fondo tenue dorado se queda).
- `lib/funcionalidades/chat/widgets/barra_envio.dart`: icono de enviar blanco sobre dorado a `principal` (hallazgo del barrido).
- `test/funcionalidades/chat/contraste_chat_test.dart`: 6 tests (3 x 2 temas) que calculan el contraste WCAG >= 4.5.

## Verificacion

- `flutter analyze`: 8 issues, todos previos (info/warning en archivos no tocados); 0 errores nuevos.
- `flutter test`: 363 pasan, todo verde.
- No se verifico en emulador.

## Otros hallazgos (no corregidos)

- `calificar_sheet.dart:127`: estrellas `AppColores.dorado` sobre la hoja (blanca en claro), ~1.6:1. Son iconos decorativos; el estado se lee por relleno vs contorno. Decision de diseno pendiente.
- `calificar_sheet.dart:148`: spinner `Colors.white` en el boton "Enviar"; en tema oscuro el boton es dorado, asi que el spinner blanco pierde contraste (transitorio).
- `RefreshIndicator`/spinners con `AppColores.acento`: no son texto.
- `encabezado_feed.dart`: `Colors.white` sobre gradiente marino, correcto.
