# Reporte — tarea 031: tokens de tipografía/espaciado + arreglo de contraste (ADR-0016)

**Fecha:** 2026-09-11
**Agente:** flutter-agent
**Rama:** `feature/rediseno-fundamentos` (sobre `feature/movimiento-y-feedback`)
**Estado:** hecho

## Qué se hizo

1. `lib/nucleo/tipografia/app_tipografia.dart` (123 líneas) — type scale con
   nombre sobre `Sora`, más una extensión `AppTextThemeExtension on TextTheme`
   para exponer los roles como `Theme.of(context).textTheme.<rol>`.
2. `lib/nucleo/espaciado/app_espaciado.dart` (60 líneas) — `AppEspaciado`
   (escala de espaciado) y `AppRadios` (roles de radio de borde) en el mismo
   archivo, como permite el punto 3 de la tarea.
3. Arreglo de contraste en `lib/nucleo/tema/app_tema.dart` (175 líneas,
   antes 150): `onPrimary`, `onSecondary` y el `checkColor` del checkbox de
   `temaOscuro()` dejan de ser blanco sobre el dorado de acento.
4. Dos roles semánticos nuevos en `lib/nucleo/tema/colores_por_tema.dart`
   (52 líneas, antes 24): `colorSuperficieAlterna` y `colorDeshabilitado`.
5. `AppTema` ya usa `AppRadios.campo` (radio de botones/campos) y
   `AppEspaciado.lg` (`contentPadding` de los inputs) en vez de los literales
   `12`/`16` — mismo valor numérico, cero cambio visual, ya referenciado por
   nombre para que 032–037 no reintroduzcan el número suelto.
6. Ninguna pantalla de `lib/funcionalidades/**/pantallas/` se tocó (fuera de
   alcance de esta tarea, según lo pedido).

No se tocó ningún archivo de `lib/screens/` (los tres servicios de
Firestore), ni `lib/nucleo/movimiento/` (ADR-0015 intacto), ni se añadió
ninguna dependencia nueva.

## Roles definidos — para que 032–037 los citen por nombre

### Tipografía (`AppTipografia`, en `lib/nucleo/tipografia/app_tipografia.dart`)

| Rol | Tamaño | Peso | Interlineado | Extra | Uso previsto |
|---|---|---|---|---|---|
| `tituloGrande` | 28 | w800 | 1.2 | `letterSpacing: -0.5` | Cabeceras de bienvenida/hero (**añadido por esta tarea**, ver "Desvíos" abajo) |
| `titulo` | 22 | w700 | 1.25 | `letterSpacing: -0.3` | Título de sección/pantalla |
| `subtitulo` | 17 | w600 | 1.3 | — | Subtítulos, cabeceras de tarjeta |
| `cuerpo` | 15 | w500 | 1.4 | — | Texto de cuerpo por defecto |
| `cuerpoChico` | 13 | w500 | 1.35 | — | Texto secundario / metadatos |
| `etiqueta` | 11 | w600 | 1.2 | `letterSpacing: 0.3` | Chips, badges, texto de apoyo |
| `numero` | 20 | w700 | 1.1 | `FontFeature.tabularFigures()` | Montos y precios |

Acceso: `Theme.of(context).textTheme.titulo` (y análogos), vía la extensión
`AppTextThemeExtension on TextTheme` — **decisión documentada en el propio
archivo**: no se tocan los campos nativos de `TextTheme` (`bodyLarge`,
`titleMedium`, etc.) porque Flutter/Material los sigue usando por dentro; la
extensión Dart añade getters con nombre sin pisar ni sustituir ninguno.

### Espaciado (`AppEspaciado`, en `lib/nucleo/espaciado/app_espaciado.dart`)

| Rol | Valor |
|---|---|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 24 |
| `xxl` | 32 |

Sin cambios respecto a lo que proponía ADR-0016 — la auditoría (≈19 valores
de `SizedBox`, 2 a 40; 7 de `EdgeInsets.all`: 6/12/14/16/20/24/32) confirmó
que esta escala cubre 6 de los 7 valores casi exactos (el 14 es un caso
suelto de redondeo, no un patrón repetido).

### Radios de borde (`AppRadios`, mismo archivo)

| Rol | Valor | Uso |
|---|---|---|
| `campo` | 12 | Botones y campos de texto (ya lo usaba `AppTema`, ahora con nombre) |
| `tarjeta` | 16 | Tarjetas y contenedores de contenido |
| `chip` | 20 | Chips, pastillas, badges |

Consolidan los 10 valores sueltos de la auditoría (2, 4, 8, 10, 12, 14, 16,
18, 20, 24). No se forzó cada uno de los 10 a caer en un rol: el checkbox de
`AppTema` sigue con `BorderRadius.circular(4)` literal a propósito (es una
forma nativa de Material muy pequeña, no un patrón de card/chip/campo que
mereciera su propio rol).

### Roles semánticos nuevos de color (`colores_por_tema.dart`)

| Rol | Valor claro | Valor oscuro | Evidencia que motivó el rol |
|---|---|---|---|
| `colorSuperficieAlterna` | `AppColores.grisClaro` | `Color.alphaBlend(blanco 6%, superficieOscura)` | 7+ usos sueltos de `AppColores.acento.withOpacity(0.10–0.35)` para el mismo propósito (fondo de insignias/iconos) en `bienvenida_registro_screen`, `ranking_tab`, `trabajadores_tab`, los dos registros |
| `colorDeshabilitado` | = `colorBorde` | = `colorBorde` | `bienvenida_registro_screen.dart:169`: `proximamente ? colorBorde(context) : AppColores.acento.withOpacity(0.12)` — el "deshabilitado" ya usaba `colorBorde` a mano; se nombra aparte para no depender de una coincidencia numérica |

No se migró ninguna pantalla a estos dos roles nuevos en esta tarea — queda
para 032–037, tal como pide el punto 5 de la tarea.

## El arreglo de contraste — cálculo completo

No existe un lector de contraste automático en el repo (confirmado en
ADR-0016); el cálculo se hizo a mano con la fórmula WCAG 2.x:

```
canal_lineal(c) = c/12.92                        si c ≤ 0.03928
                 = ((c+0.055)/1.055) ^ 2.4        si no
luminancia(color) = 0.2126·lin(R) + 0.7152·lin(G) + 0.0722·lin(B)
contraste(A, B) = (L_claro + 0.05) / (L_oscuro + 0.05)
```

(`R/G/B` en escala 0–1.) Calculado con un script Node de un solo uso (no se
añadió al repo, era desechable) y verificado también con los tests nuevos de
`test/nucleo/tema/app_tema_test.dart`, que repiten la misma fórmula en Dart
sobre el `ThemeData` real que devuelve `AppTema.temaOscuro()`.

| Par | Contraste | ¿Cumple AA (4.5:1)? |
|---|---|---|
| Blanco sobre `AppColores.acento` (#FFC107) — **el defecto, antes del arreglo** | **1.63:1** | No |
| `AppColores.principal` (#0D1B2A) sobre `AppColores.acento` — **el arreglo** | **10.67:1** | Sí (cumple incluso AAA) |
| Blanco sobre `AppColores.principal` (AppBar, botón del tema claro) | 17.39:1 | Sí — sin cambios, no tenía el defecto |
| Blanco sobre `AppColores.error` (#EF4444) | 3.76:1 | Falla AA para texto normal (cumple AA para texto grande/UI, 3:1) — **fuera de alcance**, ADR-0016 no lo señaló y no se tocó; queda anotado por si 032–037 o una tarea de QA quiere revisarlo |

El arreglo cambia tres sitios de `temaOscuro()`, todos el mismo par de
colores defectuoso:

- `ColorScheme.onPrimary`: `AppColores.blanco` → `AppColores.principal`.
- `ColorScheme.onSecondary`: mismo cambio (`secondary` también es `acento`
  en el tema oscuro).
- `elevatedButtonTheme.foregroundColor`: mismo cambio.
- `checkboxTheme.checkColor`: se fija explícito a `AppColores.principal` en
  vez de depender de la herencia implícita de `onPrimary` de Material 3
  (`_CheckboxDefaultsM3.checkColor` resuelve a `colorScheme.onPrimary`
  cuando el checkbox está seleccionado — sin el arreglo de `onPrimary`, el
  checkmark también habría estado en blanco sobre dorado; se deja explícito
  para que no vuelva a depender de una herencia que nadie ve).

El tema claro **no tenía** el defecto (su `primary` es el marino, no el
dorado) y no se tocó — confirmado con un test dedicado
(`temaClaro() no tenía el defecto y no cambió`).

## Capturas antes/después (botón primario, modo oscuro)

Tomadas en el emulador Android `emulator-5554` (Pixel, Android 13) con un
harness desechable (`lib/main_captura_tema.dart`, creado y borrado dentro de
esta misma tarea — no queda en el árbol) que monta `MaterialApp(theme:
AppTema.temaOscuro())` con un `ElevatedButton` y un `Checkbox` marcado.

- **Antes:** `docs/agent-reports/capturas/031-boton-antes.png` — texto
  blanco "Publicar trabajo" sobre fondo dorado, y check blanco sobre relleno
  dorado; ambos de contraste bajo, como predice el 1.63:1 calculado.
- **Después:** `docs/agent-reports/capturas/031-boton-despues.png` — mismo
  botón con el texto en marino (`AppColores.principal`), y el check también
  en marino; contraste alto, legible.

Metodología para la captura "antes": se guardó el diff de
`lib/nucleo/tema/app_tema.dart` con `git stash push -- lib/nucleo/tema/app_tema.dart`,
se reconstruyó y relanzó la app (`flutter run -d emulator-5554`), se
capturó, se hizo `git stash pop` para restaurar el arreglo, y se verificó de
nuevo `flutter analyze`/`flutter test` tras la restauración.

## Verificación

- `flutter analyze`: **36 issues, 0 errores** — igual que la línea base
  documentada en `docs/agent-context/repo-snapshot.md` antes de esta tarea.
  Al escribir `colores_por_tema.dart` y `app_espaciado.dart` aparecieron
  momentáneamente 2 issues nuevas (un `unused_import` y un `withOpacity`
  deprecado); se corrigieron antes de terminar (import innecesario
  eliminado, `withOpacity` cambiado a `withValues`).
- `flutter test`: **253/253 pasan** (233 preexistentes en esta rama —ya
  incluían las 12 fases de movimiento de ADR-0015 fusionadas antes de esta
  tarea— + **20 nuevos**):
  - `test/nucleo/tipografia/app_tipografia_test.dart` (8): cada rol fija su
    tamaño/peso/familia, y la extensión de `TextTheme` expone los 7 roles
    sin perder los campos nativos de Material (`bodyMedium`, `titleLarge`).
  - `test/nucleo/espaciado/app_espaciado_test.dart` (2): los 6 valores de
    `AppEspaciado` y los 3 de `AppRadios`.
  - `test/nucleo/tema/app_tema_test.dart` (7): el cálculo de contraste WCAG
    hecho en Dart, aplicado al `ThemeData` real — confirma que el par viejo
    (blanco/acento) seguía por debajo de AA, que el nuevo (principal/acento)
    lo cumple, que `temaOscuro()` ya no usa blanco en `onPrimary`/
    `onSecondary`/botón/checkbox, y que `temaClaro()` no cambió.
  - `test/nucleo/tema/colores_por_tema_test.dart` (3, primer test de este
    archivo): los 4 roles existentes cambian correctamente entre temas, y
    los 2 nuevos (`colorDeshabilitado`, `colorSuperficieAlterna`) se
    comportan como se documentó.
  - Ningún test existente dependía del color viejo del botón — no hubo que
    corregir ninguno de los 233 preexistentes.

## Desvíos de criterio propio (anotados, no se paró a preguntar)

1. **Rol de tipografía añadido: `tituloGrande`.** ADR-0016 sugería 6 roles
   (`titulo`, `subtitulo`, `cuerpo`, `cuerpoChico`, `etiqueta`, `numero`).
   Al revisar `bienvenida_registro_screen.dart` para validar los tamaños,
   apareció `fontSize: 28, fontWeight: w900` para el saludo "¡Hola!" — un
   uso claramente "hero", no cubierto por `titulo` (22/w700). Se añadió
   `tituloGrande` (28/w800 — se bajó de w900 a w800 porque ya existe w700
   para `titulo` y una escala de 3 pesos consecutivos, w500/w600/w700,
   necesitaba un salto claro arriba sin inventar un cuarto peso nuevo para
   un solo rol; los otros usos de w900/w800 sueltos de la auditoría se
   revisarán caso por caso en 032–037).
2. **Decisión de "helper equivalente" para `Theme.of(context).textTheme.<rol>`.**
   La tarea dejaba abierta la posibilidad ("o, si eso no es viable... un
   helper equivalente"). Se resolvió con una `extension` de Dart sobre
   `TextTheme`, documentada en el docstring del propio archivo — es la
   opción que literalmente cumple `Theme.of(context).textTheme.<rol>` sin
   tocar los campos nativos de `TextTheme`.
3. **Dos roles de color añadidos con evidencia, no especulativos** — ver
   tabla arriba. Se comprobó cada uno contra un uso real repetido en el
   código antes de crearlo.
4. **El mismo par defectuoso se corrigió en 3 sitios, no solo el botón**
   (`onSecondary` y `checkColor` del checkbox), tal como pedía el punto 3 de
   la tarea ("revisa si el mismo par se usa en otro sitio").
5. **No se tocaron los `TextStyle(fontSize: 16, fontWeight: w600)` de
   `elevatedButtonTheme`/`outlinedButtonTheme`.** No correspondían 1:1 a
   ningún rol nuevo (16 no es ni `cuerpo` (15) ni `subtitulo` (17)), y
   cambiarlos habría sido un cambio visual de tamaño de fuente en todos los
   botones de la app que ADR-0016 no documentó como parte del alcance de
   esta fase (solo documenta el cambio de color como visible). Se deja
   anotado para quien migre botones en 032–037.
6. **`onError` (blanco sobre `AppColores.error`, 3.76:1) no se tocó.** Es un
   hallazgo del cálculo de contraste que hice de paso, pero ADR-0016 no lo
   señaló como defecto a corregir en esta tarea y tocarlo sería alcance no
   pedido; lo anoto aquí para que quede visible.

## Qué falta (fuera de alcance de esta tarea, a propósito)

- Ninguna pantalla de `lib/funcionalidades/**/pantallas/` migró a estos
  tokens — es exactamente el trabajo de las tareas 032–037.
- Los `TextStyle` literales de `elevatedButtonTheme`/`outlinedButtonTheme`
  en `AppTema` no se tocaron (ver desvío 5).
- El posible defecto de contraste de `onError` (ver desvío 6) no se corrigió.
- El harness de captura (`lib/main_captura_tema.dart`) fue temporal y ya se
  borró; no queda en el árbol de trabajo.

## Archivos tocados

- Nuevos: `lib/nucleo/tipografia/app_tipografia.dart`,
  `lib/nucleo/espaciado/app_espaciado.dart`,
  `test/nucleo/tipografia/app_tipografia_test.dart`,
  `test/nucleo/espaciado/app_espaciado_test.dart`,
  `test/nucleo/tema/app_tema_test.dart`,
  `test/nucleo/tema/colores_por_tema_test.dart`,
  `docs/agent-reports/capturas/031-boton-antes.png`,
  `docs/agent-reports/capturas/031-boton-despues.png`.
- Modificados: `lib/nucleo/tema/app_tema.dart`,
  `lib/nucleo/tema/colores_por_tema.dart`,
  `docs/agent-tasks/031-rediseno-fundamentos-tipografia-espaciado.md`.
