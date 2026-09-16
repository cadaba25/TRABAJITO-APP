---
id: 051
titulo: "UI: barrido de contraste dorado-sobre-claro (hallazgo 2 de la auditoría de diseño 2026-09-13)"
estado: bloqueada
agente: "flutter-agent"
creada: 2026-09-13
rama: "feature/barrido-contraste-dorado"
---

## Objetivo

Terminar de aplicar en modo claro el mismo criterio que ADR-0016 (tareas
031-034) ya fijó para el botón primario, el checkbox y el precio
(`AppColores.doradoTexto`/`colorPrecio()` en vez de `AppColores.acento`
crudo como color de texto/ícono): el par blanco/dorado sobre dorado/blanco
mide 1.63:1 (WCAG AA exige 4.5:1, o 3:1 para texto grande), y reaparece sin
corregir en bastantes más sitios de los que ADR-0016 alcanzó a tocar.

Es el hallazgo 2 (`[ALTO — necesita plan de tech-lead]`) del reporte
`docs/agent-reports/audit-diseno-2026-09-13.md`, **ampliado** con hallazgos
adicionales que encontró el `tech-lead` al planificar (ver "Qué hacer",
tienen la misma causa raíz que los del reporte pero el reporte no los
listó). Modo oscuro **no se toca**: `AppTema.temaOscuro()` ya usa `acento`
sin problema ahí (fondo oscuro, no claro).

## Bloqueada por

**Tarea 050 (`sistema-de-botones`) debe estar en `en-revision` o `hecho`
antes de empezar esta.** Motivo: 050 migra a `BotonTexto` dos de los sitios
que el reporte de auditoría cuenta como parte de este mismo hallazgo
(`login_screen.dart` — enlace "Regístrate" — y
`bienvenida_registro_screen.dart` — enlace "Inicia sesión"), porque son
funcionalmente botones de texto, no solo un color a cambiar. Si esta tarea
empieza antes, va a tocar las mismas líneas que 050 y uno de los dos
agentes pisa el trabajo del otro. El `tech-lead` actualiza el `estado` de
este archivo a `todo` cuando 050 llegue a `en-revision`.

## Contexto relevante

- `docs/agent-reports/audit-diseno-2026-09-13.md`, hallazgo 2 completo
  (líneas 115-165): qué se corrigió ya (ADR-0016), qué sigue sin corregirse
  (8 archivos con línea exacta) y por qué importa.
- `docs/design-system-frontend.md` sección 14 (Accesibilidad → Contraste) y
  `docs/design-system-ux-patrones.md` sección 15 (Auditoría final →
  Accesibilidad).
- `docs/decisions.md` ADR-0016 — el ratio medido (1.63:1) y la solución ya
  construida: `AppColores.doradoTexto` (`lib/nucleo/tema/app_colores.dart:29`)
  y `colorPrecio(BuildContext)` (`lib/nucleo/tema/colores_por_tema.dart:66`).
- **Tarea 050**: si se ejecutó como está planificada, ya existe
  `colorAcentoTexto(BuildContext)` en `colores_por_tema.dart` (nombre
  genérico de la misma lógica que `colorPrecio()`) — úsalo en vez de
  `colorPrecio()` para los casos de esta tarea que no son precios (usar
  `colorPrecio()` para pintar un ranking sería confuso de leer en el código,
  aunque funcione igual). Si por algún motivo la 050 no llegó a crear esa
  función, créala tú aquí siguiendo el mismo criterio antes de continuar, y
  dilo en tu reporte.
- **Líneas del reporte de auditoría potencialmente desactualizadas**: las
  tareas 049 y 050 tocan `ranking_tab.dart`, `trabajadores_tab.dart`,
  `tarjeta_trabajo.dart` y `login_screen.dart` antes que esta. Los números de
  línea que cita el reporte y los que cita este archivo son de la fecha en
  que se escribieron (2026-09-13, antes de 050) — vuelve a `grep` cada
  patrón (`AppColores.acento`) en el archivo real antes de editar, no edites
  a ciegas por número de línea.

## Qué hacer

Para cada caso: cambiar el color de texto/ícono de `AppColores.acento`
(crudo) a `colorAcentoTexto(context)` (o `colorPrecio(context)` si el caso
es literalmente un precio) — **no** cambiar `AppColores.acento` cuando se
usa como fondo con alpha (`.withValues(alpha: ...)`), como borde, o como
color de un `CircularProgressIndicator`/`RefreshIndicator` — esos usos no
son texto ni ícono informativo y no están dentro del alcance de este
hallazgo (el reporte los revisó y no los marcó; no los reabras).

1. **Los 8 archivos que ya listó el reporte de auditoría** (verifica línea
   real con `grep`, no confíes en el número):
   - `lib/funcionalidades/trabajos/pantallas/widgets/tarjeta_trabajo.dart` —
     color del texto de la inicial del avatar y del `_Chip` de categoría.
   - `lib/funcionalidades/postulaciones/pantallas/widgets/tarjeta_postulante.dart`
     — mismo patrón (inicial de avatar + textos/bordes del chip; los bordes
     con alpha se quedan, el texto/ícono no).
   - `lib/funcionalidades/perfil/pantallas/ranking_tab.dart` — color de la
     medalla/posición y del puntaje (el fondo con alpha del círculo de la
     medalla se queda igual).
   - `lib/funcionalidades/perfil/pantallas/trabajadores_tab.dart` — color de
     "especialidad" y los demás textos de la tarjeta que hoy usan
     `AppColores.acento` directo.
   - `lib/funcionalidades/perfil/pantallas/widgets/formulario_editar_perfil.dart`
     — `tt.tituloGrande.copyWith(color: AppColores.acento)`.
   - `lib/funcionalidades/autenticacion/pantallas/bienvenida_registro_screen.dart`
     — el título "¡Hola!" (`tituloGrande.copyWith(color: AppColores.acento)`).
     **El enlace "Inicia sesión" de esta misma pantalla NO se toca aquí**: ya
     lo migró la tarea 050 a `BotonTexto`.
   - `lib/funcionalidades/autenticacion/pantallas/widgets/registro/terminos_condiciones_checkbox.dart`
     — el `estiloEnlace` del `RichText` ("Condiciones de servicio" / "Política
     de privacidad"). Es texto dentro de un `TextSpan`, no un botón — no lo
     conviertas en botón aquí, solo cambia el color.
   - `lib/funcionalidades/autenticacion/pantallas/login_screen.dart` — vuelve
     a revisar el archivo por si queda algún `AppColores.acento` como texto
     que no sea el enlace "¿Olvidaste tu contraseña?"/"Regístrate" (esos dos
     ya los migró la tarea 050 a `BotonTexto`, con color correcto incluido).

2. **Hallazgo nuevo del `tech-lead` — mismo patrón en `detalle_trabajo_screen.dart`**,
   no listado por el reporte original: la inicial del avatar del autor
   (`CircleAvatar` con `child: Text(...)`) y el `_chip(context, pub.categoria,
   AppColores.acento)` de categoría — es el mismo componente visual que
   `tarjeta_trabajo.dart`, con el mismo bug. El `RefreshIndicator(color:
   AppColores.acento, ...)` de la misma pantalla **no se toca** (es un
   spinner, no texto).

3. **Hallazgo nuevo del `tech-lead` — `ChoiceChip` blanco sobre dorado en 3
   archivos**, más grave que el resto porque no es "dorado sobre blanco" sino
   literalmente el mismo par que midió ADR-0016 (`Colors.white` sobre
   `AppColores.acento` = 1.63:1), reproducido a mano en:
   - `lib/funcionalidades/trabajos/pantallas/editar_trabajo_screen.dart`
   - `lib/funcionalidades/trabajos/pantallas/publicar_trabajo_screen.dart`
   - `lib/funcionalidades/trabajos/pantallas/widgets/selector_tarifa.dart`

   Los tres tienen el mismo `ChoiceChip` con
   `labelStyle: ... color: activo ? Colors.white : colorTextoFuerte(context)`
   y `selectedColor: AppColores.acento`. **Arréglalo en el sistema, no en los
   3 archivos por separado** (mismo principio que ADR-0016 y que la sección
   15 del primer documento — "pensar primero en el sistema"): añade un
   `chipThemeData` a `AppTema.temaClaro()`/`temaOscuro()` en
   `lib/nucleo/tema/app_tema.dart` con `selectedColor: AppColores.acento` y
   el color de la etiqueta seleccionada correcto para cada modo (en claro,
   el mismo criterio que ya usa `onPrimary` del botón primario —
   `AppColores.principal` sobre `acento`, 10.67:1 — no blanco). Con el
   `chipTheme` puesto, simplifica los 3 `ChoiceChip` para que dejen de fijar
   `labelStyle`/`selectedColor` a mano y hereden del tema (menos código, no
   solo mejor contraste).

4. **Grep final de verificación.** Antes de dar la tarea por terminada,
   corre `grep -rn "AppColores.acento" lib/funcionalidades/` y revisa cada
   resultado que quede: si es texto/ícono informativo sobre superficie clara,
   corrígelo aunque no esté en esta lista; si es fondo con alpha, borde o
   spinner, déjalo y no lo menciones como pendiente (ya está revisado y es
   intencional).

## Qué NO es esta tarea

- No toca modo oscuro (`AppTema.temaOscuro()` ya está bien).
- No toca fondos con alpha, bordes, ni colores de `CircularProgressIndicator`/
  `RefreshIndicator` — eso no es texto/ícono informativo y el reporte no lo
  marcó como incumplimiento.
- No toca los dos enlaces que ya migró la tarea 050
  (`login_screen.dart` "Regístrate", `bienvenida_registro_screen.dart`
  "Inicia sesión") — si al revisar descubres que 050 no los tocó como se
  planeó, dilo en tu reporte y arréglalos aquí como excepción, no los des
  por hechos a ciegas.
- No añade funcionalidad nueva (p. ej., no hagas que
  `terminos_condiciones_checkbox.dart` abra un diálogo de términos — sigue
  sin tener `onTap`, eso es un cambio de producto fuera de alcance).
- No reordena `detalle_trabajo_screen.dart` (hallazgo 7, tarea aparte).

## Criterios de aceptación

- [ ] Los 8 sitios del reporte original corregidos (`colorAcentoTexto`/
      `colorPrecio` según corresponda), verificados por `grep` propio, no por
      las líneas citadas en el reporte.
- [ ] `detalle_trabajo_screen.dart` (avatar + chip de categoría) corregido.
- [ ] `chipThemeData` añadido a `AppTema` y los 3 `ChoiceChip` simplificados
      para heredar del tema en vez de fijar `labelStyle`/`selectedColor` a
      mano.
- [ ] `grep -rn "AppColores.acento" lib/funcionalidades/` revisado caso por
      caso al final; cualquier uso como texto/ícono que quede sin corregir
      está justificado explícitamente en el reporte (no silenciado).
- [ ] Ningún caso corregido cambia el comportamiento, solo el color — mismos
      textos, mismos íconos, mismas acciones.
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde.
- [ ] Reporte en `docs/agent-reports/051-*.md` con la lista final de archivos
      tocados y, si aplica, la constancia de que los dos enlaces migrados por
      la tarea 050 se verificaron y no se volvieron a tocar.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja. El estado de este archivo empieza en
`bloqueada`; el `tech-lead` lo pasa a `todo` cuando la tarea 050 llegue a
`en-revision` o `hecho`.)
