# 043 — Iconografía, fase 0: paquete Lucide, mapa de 100 glifos y `compartido/widgets/` (ADR-0017)

**Estado:** hecho
**Fecha:** 2026-09-12
**Agente:** flutter-agent
**Rama:** `feature/hotfixes-qa-039` (ver nota de coordinación abajo — no se creó
`feature/iconografia-fundamentos`). Cambios dejados **sin commit** en el
working tree, tal como se pidió.

## Coordinación (importante para quien retome esto)

Esta tarea se ejecutó con dos `flutter-agent` más trabajando en background,
en el mismo working tree de `feature/hotfixes-qa-039`:

- uno en la tarea 041 (`lib/funcionalidades/trabajos/**`),
- otro en la tarea 037 (`lib/funcionalidades/perfil/**` + `inicio_screen.dart`).

Por instrucción explícita, **no se tocó ningún archivo de esas dos carpetas
ni `inicio_screen.dart`**, y no se creó la rama que sugiere el frontmatter
original de la tarea (`feature/iconografia-fundamentos`): se trabajó
directamente sobre la rama vigente. El alcance real ejecutado fue
exactamente el que pidió el encargo: `pubspec.yaml`, el mapa de 100 glifos
(este reporte) y los 8 archivos de `lib/compartido/widgets/`. Ningún archivo
de `trabajos/`, `perfil/` o `inicio_screen.dart` fue tocado — confirmado con
`git status` antes de terminar.

## Qué se hizo

### 1. Dependencia nueva

`pubspec.yaml`:

```yaml
lucide_icons_flutter: ^3.1.19
```

Verificado contra `pub.dev` en vivo el mismo día (2026-09-12): `3.1.19`
sigue siendo la última versión, publicada 2026-09-07 — coincide con lo que
ya había verificado ADR-0017, sin necesidad de actualizar la cifra.
`flutter pub get` solo agregó esa dependencia (`+ lucide_icons_flutter
3.1.19`); nada más cambió en el árbol de dependencias (las ~37 líneas de
"newer version available" que muestra `pub get` son preexistentes, de
paquetes de Firebase/etc., no relacionadas). `pubspec.lock` refleja el único
paquete nuevo.

### 2. Mapa completo de los 100 glifos (artefacto citable por 044-048)

Confirmado con `grep -rn "Icons\." lib | wc -l` → **203** usos,
`grep -oE "Icons\.[A-Za-z0-9_]+" | sort -u | wc -l` → **100** glifos únicos,
`grep -rln "Icons\." lib | wc -l` → **52** archivos. Coincide exactamente con
la auditoría de ADR-0017: no cambió nada desde que se escribió el ADR.

Cada nombre `LucideIcons.*` de la tabla fue **verificado que existe de
verdad** en el paquete instalado (`lucide_icons_flutter-3.1.19`), buscando
`static const IconData <nombre> =` en su `lib/lucide_icons.dart` (130 044
líneas) — ninguno es una suposición.

| # | `Icons.*` | `LucideIcons.*` | Tipo |
|---|---|---|---|
| 1 | `account_balance_outlined` | `landmark` | literal |
| 2 | `account_balance_wallet_outlined` | `wallet` | literal (ejemplo del ADR) |
| 3 | `add_photo_alternate_outlined` | `imagePlus` | literal |
| 4 | `add_rounded` | `plus` | literal |
| 5 | `arrow_back_ios_new_rounded` | `chevronLeft` | literal-ish |
| 6 | `arrow_forward_ios_rounded` | `chevronRight` | literal-ish |
| 7 | `assignment_ind_outlined` | `idCard` | semántico ("asignado a" una persona) |
| 8 | `assignment_outlined` | `clipboardList` | semántico (documento/tarea genérica) |
| 9 | `badge_outlined` | `badge` | literal |
| 10 | `block_rounded` | `ban` | semántico |
| 11 | `bolt_outlined` | `zap` | literal-ish |
| 12 | `business_center_outlined` | `briefcase` | semántico (caso "trabajo" del ADR) |
| 13 | `business_center_rounded` | `briefcase` | ídem |
| 14 | `business_outlined` | `building` | literal (edificio de oficina) |
| 15 | `calendar_today_outlined` | `calendar` | literal |
| 16 | `camera_alt_rounded` | `camera` | literal |
| 17 | `cancel_outlined` | `circleX` | literal-ish |
| 18 | `category_outlined` | `shapes` | semántico (caso "categoría" del ADR — ver nota) |
| 19 | `check` | `check` | literal |
| 20 | `check_circle` | `circleCheck` | literal-ish |
| 21 | `check_circle_outline` | `circleCheck` | ídem |
| 22 | `check_circle_outline_rounded` | `circleCheck` | ídem |
| 23 | `check_circle_rounded` | `circleCheck` | ídem |
| 24 | `check_rounded` | `check` | literal |
| 25 | `cloud_off_outlined` | `cloudOff` | literal (ejemplo del ADR) |
| 26 | `cloud_off_rounded` | `cloudOff` | ídem |
| 27 | `credit_card_rounded` | `creditCard` | literal (ejemplo del ADR) |
| 28 | `dark_mode_rounded` | `moon` | semántico |
| 29 | `delete_forever_rounded` | `trash2` | semántico (variante "definitivo") |
| 30 | `delete_outline_rounded` | `trash` | literal (ejemplo del ADR) |
| 31 | `description_outlined` | `fileText` | semántico (caso del ADR) |
| 32 | `done_all_rounded` | `checkCheck` | semántico (caso del ADR: doble check) |
| 33 | `edit_note_rounded` | `notebookPen` | semántico |
| 34 | `edit_outlined` | `pencil` | semántico/literal-ish |
| 35 | `email_outlined` | `mail` | literal-ish |
| 36 | `emoji_events_outlined` | `trophy` | semántico |
| 37 | `emoji_events_rounded` | `trophy` | ídem |
| 38 | `error_outline` | `circleAlert` | semántico |
| 39 | `event_available_outlined` | `calendarCheck` | literal-ish |
| 40 | `format_quote_rounded` | `quote` | literal (ejemplo del ADR) |
| 41 | `forum_outlined` | `messagesSquare` | semántico (caso del ADR) |
| 42 | `forum_rounded` | `messagesSquare` | ídem |
| 43 | `groups_outlined` | `users` | semántico |
| 44 | `handshake_outlined` | `handshake` | literal (ejemplo del ADR) |
| 45 | `handshake_rounded` | `handshake` | ídem |
| 46 | `help_outline_rounded` | `circleHelp` | semántico |
| 47 | `inbox_outlined` | `inbox` | literal |
| 48 | `info_outline_rounded` | `info` | literal |
| 49 | `keyboard_arrow_down_rounded` | `chevronDown` | literal-ish |
| 50 | `language_outlined` | `globe` | semántico (por contexto de uso: campo "Sitio web") |
| 51 | `light_mode_rounded` | `sun` | semántico |
| 52 | `location_city_outlined` | `building2` | semántico (distinto de `business_outlined`) |
| 53 | `location_on_outlined` | `mapPin` | literal-ish |
| 54 | `lock_outline` | `lock` | literal |
| 55 | `lock_outline_rounded` | `lock` | ídem |
| 56 | `logout_rounded` | `logOut` | literal |
| 57 | `map_outlined` | `map` | literal |
| 58 | `mark_email_read_outlined` | `mailCheck` | literal-ish |
| 59 | `markunread_mailbox_outlined` | `mailbox` | literal (por contexto: dirección postal) |
| 60 | `notifications_none_rounded` | `bell` | semántico |
| 61 | `payments_outlined` | `banknote` | semántico |
| 62 | `payments_rounded` | `banknote` | ídem |
| 63 | `people_outline_rounded` | `users` | semántico |
| 64 | `people_rounded` | `users` | ídem — ver nota BottomNav |
| 65 | `person_outline` | `user` | semántico |
| 66 | `person_outline_rounded` | `user` | ídem |
| 67 | `person_rounded` | `user` | ídem |
| 68 | `phone_in_talk_outlined` | `phoneCall` | literal-ish |
| 69 | `phone_outlined` | `phone` | literal |
| 70 | `pin_drop_outlined` | `mapPin` | semántico (mismo que `location_on`) |
| 71 | `play_arrow_rounded` | `play` | literal |
| 72 | `play_circle_outline_rounded` | `circlePlay` | literal-ish |
| 73 | `post_add_outlined` | `filePlus` | semántico |
| 74 | `post_add_rounded` | `filePlus` | ídem |
| 75 | `receipt_long_rounded` | `receipt` | literal-ish |
| 76 | `refresh_rounded` | `refreshCw` | literal-ish |
| 77 | `report_gmailerrorred_rounded` | `triangleAlert` | semántico ("reportar problema a soporte") |
| 78 | `schedule_outlined` | `clock` | semántico |
| 79 | `schedule_rounded` | `clock` | ídem |
| 80 | `school_outlined` | `graduationCap` | semántico |
| 81 | `search_rounded` | `search` | literal |
| 82 | `sell_outlined` | `tag` | literal-ish |
| 83 | `send_outlined` | `send` | literal |
| 84 | `send_rounded` | `send` | ídem |
| 85 | `settings_outlined` | `settings` | literal |
| 86 | `star_half_rounded` | `starHalf` | literal (ejemplo del ADR) |
| 87 | `star_outline` | `star` | literal (ejemplo del ADR) |
| 88 | `star_outline_rounded` | `star` | ídem |
| 89 | `star_rounded` | `star` | ídem — **ver hallazgo del octavo caso, abajo** |
| 90 | `timeline_rounded` | `timeline` | literal |
| 91 | `title_rounded` | `heading` | semántico |
| 92 | `tune_rounded` | `slidersHorizontal` | semántico (caso del ADR: filtros) |
| 93 | `upload_file_outlined` | `fileUp` | semántico/literal-ish |
| 94 | `verified_outlined` | `badgeCheck` | semántico |
| 95 | `visibility_off_outlined` | `eyeOff` | literal |
| 96 | `visibility_outlined` | `eye` | literal |
| 97 | `wc_outlined` | `venusAndMars` | semántico (caso del ADR: género) |
| 98 | `work_outline` | `briefcase` | semántico (caso del ADR: trabajo) |
| 99 | `work_outline_rounded` | `briefcase` | ídem |
| 100 | `work_rounded` | `briefcase` | ídem |

**Los 7 casos semánticos de ADR-0017 quedan resueltos** exactamente como
decidió el ADR: `business_center_*`/`work_*` → `briefcase` (#12,13,98-100),
`forum_*` → `messagesSquare` (#41-42), `tune_rounded` → `slidersHorizontal`
(#92), `description_outlined` → `fileText` (#31), `category_outlined` →
`shapes` (#18, ver nota), `done_all_rounded` → `checkCheck` (#32),
`wc_outlined` → `venusAndMars` (#97).

**Nota sobre `category_outlined` (#18):** el ADR dejaba abierto `shapes` vs
`layoutGrid` "a decidir por contexto de uso". Los usos reales de
`category_outlined` (revisados con grep antes de decidir, aunque están fuera
de mi alcance de archivos) son todos el mismo patrón — un campo/dropdown de
"Categoría" o "Sector" en formularios y filtros, nunca una vista tipo
cuadrícula de categorías. Se resuelve **uniformemente a `shapes`** para las
44-47; si algún caso concreto resulta ser una vista de cuadrícula real,
anótenlo y usen `layoutGrid` ahí puntualmente, pero no se encontró ningún uso
así.

**Nota sobre `people_outline_rounded`/`people_rounded` (#63-64):** ambos se
resuelven a `users`. El ADR advierte que hay que preservar la distinción
visual outline/relleno del `BottomNav` de `inicio_screen.dart` (que sigue
usando `Icons.*`, fuera de mi alcance). Como Lucide **no tiene una variante
"rellena" de `users`** (ver el hallazgo siguiente, mismo problema que con
`star`), quien ejecute la tarea 047 va a necesitar la misma estrategia que
usé aquí: diferenciar por color (o por un `Container`/fondo detrás del
ícono seleccionado), no por glifo. Dejo esto anotado explícitamente para no
repetir la investigación.

### 3. Octavo caso semántico encontrado (no previsto por el ADR)

Al migrar `estrellas.dart`/`resenas.dart` y verificar visualmente (paso
obligatorio del criterio de aceptación), encontré que **Lucide no tiene un
glifo de "estrella rellena" distinto de la vacía** — es un set de solo
trazo (outline), a diferencia de Material, que sí trae `star_rounded`
(relleno) y `star_outline_rounded` (contorno) como glifos separados.
Migrar 1:1 a `LucideIcons.star` para AMBOS casos (como haría una lectura
literal de la tabla del ADR) hace que una calificación de 0 estrellas se
vea **igual** que una de 5 — se pierde toda la información de la
calificación.

Verificado con capturas reales antes/después (`docs/agent-reports/capturas/
043-estrellas-resenas-{antes,despues}.png`, ver más abajo): la señal de
"llena" pasó a llevarla el **color**, no el glifo — mismo criterio semántico
que pide ADR-0017 (decisión 5): sin crear ninguna capa de abstracción nueva
(`AppIconos`), solo dos líneas dentro de `Estrellas`/`ResumenCalificacion`:

```dart
color: (llena || media) ? AppColores.dorado : AppColores.grisMedio,
```

Esto **no estaba en el objetivo original de "solo cambiar el nombre del
glifo"**, pero es imprescindible para que la calificación siga siendo
legible — se documenta aquí para que 044-047 lo tengan presente si se topan
con otro par relleno/contorno de Material que Lucide no separe (el caso de
`people_outline_rounded`/`people_rounded` de arriba es exactamente ese mismo
problema, ya anotado). Se fijó con un test nuevo,
`test/compartido/widgets/estrellas_test.dart`, para que nadie lo revierta
sin darse cuenta.

## 4. Los 8 archivos de `lib/compartido/widgets/` migrados

| Archivo | `Icons.*` → `LucideIcons.*` |
|---|---|
| `botones_si_no.dart` | `check` → `check` |
| `custom_dropdown.dart` | `keyboard_arrow_down_rounded` → `chevronDown` |
| `custom_textfield.dart` | `visibility_off_outlined`/`visibility_outlined` → `eyeOff`/`eye` |
| `entrada_etiquetas.dart` | `sell_outlined` → `tag`; `add_rounded` → `plus` |
| `estado_exito.dart` | `check_circle_rounded` → `circleCheck` |
| `estrellas.dart` | `star_half_rounded`/`star_rounded`/`star_outline_rounded` → `starHalf`/`star` (+ color, ver arriba) |
| `mostrar_snackbar.dart` | `error_outline`/`check_circle_outline` → `circleAlert`/`circleCheck` |
| `resenas.dart` | mismo caso que `estrellas.dart` (duplica la lógica de pintado) |

Confirmado con `grep -n "Icons\." lib/compartido/widgets/*.dart | grep -v
"LucideIcons"` → vacío. Ningún archivo pasa de 300 líneas (el más grande,
`resenas.dart`, quedó en 163).

## Verificación

- **`flutter analyze`**: 12 issues (bajó de los 14 iniciales porque otro
  agente en background limpió dos warnings de un archivo `test/manual/`
  ajeno a esta tarea, no por algo mío), 0 errores, 0 issues nuevos
  introducidos por esta tarea.
- **`flutter test`**: **270/270** pasan (268 preexistentes + 2 nuevos de
  `test/compartido/widgets/estrellas_test.dart`).
  - `test/compartido/widgets/estado_exito_test.dart` se actualizó: buscaba
    `find.byIcon(Icons.check_circle_rounded)`, ahora
    `find.byIcon(LucideIcons.circleCheck)`.
  - `test/funcionalidades/postulaciones/widgets/tarjeta_postulante_test.dart`
    también busca `Icons.check_circle_rounded`, pero ese glifo vive en
    `tarjeta_postulante.dart` (fuera de mi alcance, tarea 045) — **no se
    tocó**, sigue en verde porque esa pantalla todavía usa Material.
  - Nuevo: `test/compartido/widgets/estrellas_test.dart` (2 casos): fija que
    llena/media son doradas y vacía es gris, y que "sin calificaciones" no
    dibuja ningún ícono.
- **Verificación visual** (sin emulador — ver nota abajo): capturas reales
  con `RenderRepaintBoundary.toImage()`, mismo patrón que
  `test/manual/generar_capturas_*.dart` de las tareas 033-041, en
  `test/manual/generar_capturas_iconografia_043.dart`. Genera:
  - `docs/agent-reports/capturas/043-estrellas-resenas-{antes,despues}.png`
  - `docs/agent-reports/capturas/043-snackbar-exito-{antes,despues}.png`
  - `docs/agent-reports/capturas/043-snackbar-error-{antes,despues}.png`

  Confirmado visualmente: los íconos de Lucide (estrella de contorno,
  círculo con check, círculo con "!") son igual de reconocibles a la escala
  en la que se usan (16-26px) que sus equivalentes de Material.

  **Nota técnica para quien reutilice este script en 044-048:** `flutter
  test` NO carga ninguna fuente real por defecto (ni `MaterialIcons` del
  SDK ni `Lucide` del paquete) — dibuja "tofu" (cuadrados) para cualquier
  glifo a menos que se cargue explícitamente con `FontLoader`, igual que ya
  hacía este repo con la fuente `Sora`. El script nuevo resuelve esto solo
  (busca `MaterialIcons-Regular.otf` en la raíz de Flutter y `lucide.ttf` en
  el pub cache), pero el detalle que cuesta encontrar es que
  **`LucideIcons.*` declara `fontPackage: 'lucide_icons_flutter'`**, así que
  hay que registrar la fuente bajo el nombre
  `'packages/lucide_icons_flutter/Lucide'`, no `'Lucide'` a secas — si no,
  el `FontLoader` "funciona" sin error pero el glifo sigue saliendo en
  blanco. Las capturas de tareas anteriores (033-041) probablemente muestran
  sus íconos en blanco por este mismo motivo si alguna vez se revisan de
  cerca; no lo arreglé ahí porque está fuera de mi alcance.

- **Sin emulador**: se comprobó con `adb devices` (usando
  `platform-tools/adb.exe`, ya que el `bash` de este entorno no tenía `adb`
  en el `PATH`) que el emulador `emulator-5554` **ya tenía la app real
  corriendo** (`pidof com.trabajito.trabajito` → PID activo), casi seguro
  por otro agente/persona revisándola en vivo. Por la regla de no instalar
  un harness sobre una sesión que no arranqué yo, **no se usó el emulador**
  y se optó por la verificación con capturas reales, que es la alternativa
  explícita que permite el propio criterio de aceptación.

## Archivos tocados

- `pubspec.yaml`, `pubspec.lock` (dependencia nueva)
- `lib/compartido/widgets/botones_si_no.dart`
- `lib/compartido/widgets/custom_dropdown.dart`
- `lib/compartido/widgets/custom_textfield.dart`
- `lib/compartido/widgets/entrada_etiquetas.dart`
- `lib/compartido/widgets/estado_exito.dart`
- `lib/compartido/widgets/estrellas.dart` (+ fix de color llena/vacía)
- `lib/compartido/widgets/mostrar_snackbar.dart`
- `lib/compartido/widgets/resenas.dart` (+ fix de color llena/vacía)
- `test/compartido/widgets/estado_exito_test.dart` (actualizado)
- `test/compartido/widgets/estrellas_test.dart` (nuevo)
- `test/manual/generar_capturas_iconografia_043.dart` (nuevo, herramienta manual de captura, no se ejecuta con `flutter test` sin argumentos)
- `docs/agent-tasks/043-iconografia-fundamentos-lucide.md` (estado, checkboxes, notas)
- `docs/agent-reports/043-iconografia-fundamentos-lucide.md` (este archivo)
- `docs/agent-reports/capturas/043-*.png` (6 archivos nuevos)

**No se tocó** ningún archivo de `lib/funcionalidades/trabajos/**`,
`lib/funcionalidades/perfil/**` ni `inicio_screen.dart` (confirmado con
`git status` al terminar) — son las tareas 046/047, bloqueadas hasta que
041/037 terminen.

## Recomendaciones para 044-048

1. Citar la tabla de arriba por número de fila o por nombre de glifo; no
   volver a derivarla.
2. Antes de migrar cualquier par Material relleno/contorno
   (`_rounded` vs `_outlined`) que hoy distinga estado (seleccionado/no,
   llena/vacía), comprobar primero si Lucide tiene una variante equivalente.
   Si no la tiene (como pasó con `star` y como va a pasar con `users` en el
   `BottomNav` de 047), la señal hay que preservarla por color o por un
   fondo/contenedor detrás del ícono, no asumir que el glifo solo ya
   alcanza — verificarlo con una captura antes/después, no de memoria.
3. Si generan capturas con el mismo script de esta tarea (o uno derivado),
   usar el nombre de familia con prefijo `packages/lucide_icons_flutter/` al
   cargar la fuente Lucide con `FontLoader`, si no los glifos salen en
   blanco sin ningún error visible.
