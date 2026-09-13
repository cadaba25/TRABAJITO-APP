# Reporte — tarea 036: rediseño visual, postulaciones

**Fecha:** 2026-09-12
**Agente:** flutter-agent
**Rama:** `feature/rediseno-postulaciones` (sobre `feature/rediseno-detalle-trabajo`, con la 031/032/033/034/035 mergeadas)
**Estado:** hecho

## Qué se hizo

Se aplicaron los tokens de la tarea 031 (ADR-0016: `AppTipografia`,
`AppEspaciado`, `AppRadios`) a los 6 archivos de
`lib/funcionalidades/postulaciones/pantallas/` que pedía la tarea:
`postulantes_screen.dart`, `mis_postulaciones_screen.dart`,
`postularse_sheet.dart`, y en `widgets/`: `cabecera_postulantes.dart`,
`estados_postulantes.dart`, `tarjeta_postulante.dart`.

**No se tocó**: el flujo de aceptar/rechazar postulantes, ninguna llamada a
`PostulacionService`, y `test/funcionalidades/trabajos/widgets/` (tarea 029,
QA). El único test existente de esta funcionalidad
(`test/funcionalidades/postulaciones/widgets/tarjeta_postulante_test.dart`)
no necesitó ningún cambio.

### Antes / después (líneas)

| Archivo | Antes | Después |
|---|---|---|
| `postulantes_screen.dart` | 192 | 200 |
| `mis_postulaciones_screen.dart` | 297 | 298 |
| `postularse_sheet.dart` | 149 | 158 |
| `widgets/cabecera_postulantes.dart` | 49 | 51 |
| `widgets/estados_postulantes.dart` | 69 | 73 |
| `widgets/tarjeta_postulante.dart` | 179 | 181 |

Los 6 archivos quedan por debajo del techo de 300 de ADR-0014.
`mis_postulaciones_screen.dart` (298) es el que queda más cerca — ya estaba a
3 líneas del techo antes de esta tarea (297); no se extrajo ningún widget
nuevo de aquí porque no había una pieza autocontenida y de bajo riesgo que
sacar sin tocar la lógica de `_cargar`/`_titulo` (a diferencia de los
`AlertDialog` que sí se extrajeron en la 035). Ver la sección "Deuda
preexistente, no resuelta" más abajo.

## Mapeo de tokens

Mismo criterio que 032/033/034/035: cada `TextStyle(fontSize:, fontWeight:)`
suelto se sustituyó por el rol de `AppTipografia` cuyo tamaño coincide exacto
o es el más cercano, con `.copyWith(color:, fontWeight:)` cuando hacía falta
preservar el color por-tema o un peso que el rol no fija.

| Uso | Antes | Rol aplicado |
|---|---|---|
| Título de AppBar (3 pantallas: "Postulantes", "Mis postulaciones", y el heading "Postularme" de la hoja) | `fontWeight: w800, letterSpacing: -0.5` (22 heredado) / 20/w800 en la hoja | `titulo` (22/w700/-0.3) — mismo tratamiento que las demás pantallas de `trabajos/`/`postulaciones/`. Para "Postularme" (20/w800) se prefirió `titulo` sobre `numero` (20, tamaño exacto) por semántica: `numero` es explícitamente "montos y precios", no encabezados de hoja modal — ver detalle abajo |
| Título de la cabecera de postulantes (`pub.titulo`, fontSize 18/w800) | — | `subtitulo` (17/w600) — mismo mapeo exacto que usó 034 para "Filtros" (18/w800) |
| Nombre del trabajador/título de tarjeta (`tarjeta_postulante.dart` 16/w800, `mis_postulaciones` `_titulo(p)` 15/w800) | — | `subtitulo` (17) para el 16, `cuerpo` (15, tamaño exacto) para el 15 — ver el razonamiento del "empate" en la sección dedicada abajo |
| Avatar-inicial (círculo del postulante, radio 22, w800 sin tamaño fijo) | — | `cuerpoChico.copyWith(color: AppColores.acento, fontWeight: w700)` — mismo patrón exacto que el avatar de radio 22 en `detalle_trabajo_screen.dart` (035) |
| Metadatos pequeños ("Postuló hace...", `tiempoRelativo`, "Desliza hacia abajo para reintentar", fontSize 11–13) | — | `etiqueta` (11, el más cercano) |
| Mensaje del postulante (fontSize 13/height 1.4) | — | `cuerpoChico` (13 exacto) |
| Textos de estado vacío/error (fontSize 14/w600) | — | `cuerpo.copyWith(fontWeight: w600)` — mismo mapeo que usó 034 para "descripción introductoria del formulario" (14/height 1.5) |
| Badges de estado (`_Badge`/`_badge`, fontSize 11/w700) | — | `etiqueta.copyWith(color:, fontWeight: w700)` — mismo patrón que `_Chip` de `tarjeta_trabajo.dart` (034) |
| Botón "Retirar" (fontSize 13) | — | `cuerpoChico.copyWith(color: AppColores.error)` |
| Título/mensaje del diálogo "¿Seleccionar a este trabajador?" (título sin tamaño fijo/w700, mensaje sin estilo) | — | `subtitulo.copyWith(color: colorTextoFuerte(context))` / `cuerpo.copyWith(color: colorTextoSuave(context))` — mismo patrón que los 5 diálogos extraídos en 035 |
| Título de la publicación dentro de la hoja de postularse (fontSize 13) | — | `cuerpoChico.copyWith(color: colorTextoSuave(context))` |

### El "empate" de tamaño: `subtitulo` vs. `cuerpo` para el título de tarjeta

`tarjeta_postulante.dart` tiene el nombre del trabajador a 16/w800 (distancia
1 tanto a `cuerpo`=15 como a `subtitulo`=17 — el mismo empate exacto que
resolvió la 034 para `p.titulo` de `tarjeta_trabajo.dart`, 16/w800, a favor de
`subtitulo` por ser "cabecera de tarjeta", el uso documentado del rol). Se
aplicó el mismo criterio aquí por consistencia con el precedente ya fijado.

`mis_postulaciones_screen.dart` tiene el título del trabajo (`_titulo(p)`) a
**15**/w800 — no es un empate: `cuerpo` (15) es tamaño exacto, `subtitulo`
(17) queda a distancia 2. El criterio general de estas tareas ("el rol cuyo
tamaño coincide exacto o es el más cercano") prioriza distancia sobre
semántica cuando no hay empate, así que se aplicó `cuerpo.copyWith(fontWeight:
w800)` en vez de forzar `subtitulo` por analogía con la tarjeta hermana. Se
documenta aquí porque es una decisión de juicio, no un mapeo mecánico.

### `AppTipografia.numero` no se usó — "Postularme" no es un monto

Se evaluó aplicar `numero` (20/w700/tabular) al encabezado "Postularme"
(20/w800 en el original), que coincide en tamaño exacto. Se descartó: el
docstring del rol es explícito ("Montos y precios — cifras tabulares para
que un monto no cambie de anchura al actualizarse"), y aplicarlo a un
encabezado de texto habría sido forzar un rol semánticamente equivocado por
coincidencia de tamaño. Se usó `titulo` (22, distancia 2) en su lugar —
mismo tipo de decisión ("semántica sobre tamaño puro cuando el rol más
cercano es el de un dato monetario") que tomó la 035 al no aplicar `numero`
al presupuesto/monto acordado de `detalle_trabajo_screen.dart`.

### Espaciado y radios

Mismas reglas de redondeo que fijaron 032/033/034/035 para los valores que no
caen exacto en la escala 4/8/12/16/24/32 (`AppEspaciado`) ni en 12/16/20
(`AppRadios`):

- `4→xs`, `6/8→sm`, `10/12→md`, `16/18→lg`, `20/24→xl`, `32→xxl` (espaciado),
  aplicados sin excepción nueva sobre los valores ya vistos en tareas
  anteriores.
- Radios: `circular(16)→tarjeta`, `circular(12)→campo` (contenedor de
  mensaje del postulante — mismo criterio que el info-banner de 035),
  `circular(20)→chip` (badges de estado), `circular(24)` (esquina superior
  de la hoja de postularse) `→chip` (20) — mismo redondeo exacto que hizo 034
  para la píldora de búsqueda y el borde superior de la hoja de filtros
  ("una hoja modal es, de los tres roles, más parecida a `chip` que a
  `tarjeta` o `campo`").
- **`circular(2)` de la barra de agarre de `postularse_sheet.dart` se dejó
  literal a propósito**: es la misma clase de excepción que ya documentó la
  031 para el checkbox de `AppTema` (una forma nativa muy pequeña, no un
  patrón de card/chip/campo). Se anotó en el propio código.
- El `SizedBox(height/width: 20)` del spinner de carga del botón "Enviar
  postulación" no se tocó: tamaño de componente, no espaciado (mismo
  criterio que 032/034 dejaron para spinners análogos).

### Badges alineados al molde de `_Chip` (034/035)

El badge de estado de `tarjeta_postulante.dart` (`_Badge`) y el de
`mis_postulaciones_screen.dart` (`_badge`) pasaban de `EdgeInsets.symmetric(
horizontal: 10, vertical: 4)` sueltos a `AppEspaciado.md`/`AppEspaciado.xs` —
mismo ajuste (2px menos de padding horizontal) que hizo la 035 con
`_chip`/`_badgeEstado` de `detalle_trabajo_screen.dart`, para que los tres
badges/chips visualmente equivalentes de `trabajos`/`postulaciones` usen el
mismo molde en vez de tres valores sueltos coincidentes por casualidad.

## Reutilización de diálogo — decisión de NO reusar `mostrarDialogoConfirmacion`

`postulantes_screen.dart._seleccionar` construye un `AlertDialog` de
confirmación Sí/No ("¿Seleccionar a este trabajador?") que, por forma, es
exactamente lo que ya resuelve `mostrarDialogoConfirmacion` (extraído en la
035 desde `detalle_trabajo_screen.dart`). Se evaluó reemplazarlo por el
componente compartido y **se decidió no hacerlo**, por dos razones:

1. `mostrarDialogoConfirmacion` fija los textos de botón "No"/"Sí"; aquí son
   "Cancelar"/"Seleccionar" — cambiarlos habría sido una modificación de
   texto visible, no de tokens.
2. El botón afirmativo de `mostrarDialogoConfirmacion` usa
   `ElevatedButton.styleFrom(backgroundColor: AppColores.error)` (pensado
   para "rechazar trabajo", una acción destructiva). "Seleccionar a un
   postulante" no lo es; pintarlo en rojo habría sido un cambio de
   comportamiento visual incorrecto, no solo de estilo.

Se tokenizó el diálogo **in-place** (mismo patrón visual que los 5 diálogos
de la 035, sin extraerlo a su propio archivo porque esta tarea no pedía
extracción de diálogos, a diferencia de la 035): `AppRadios.tarjeta` para el
`shape`, `textTheme.subtitulo.copyWith(color: colorTextoFuerte(context))`
para el título, `textTheme.cuerpo.copyWith(color: colorTextoSuave(context))`
para el mensaje.

## Hallazgo lateral, no corregido (mismo patrón que 034/035 dejaron anotado)

`tarjeta_postulante.dart` pinta `AppColores.acento` (dorado) como color de
texto (inicial del avatar) e ícono (`format_quote_rounded`) sobre un fondo
que es un **tinte muy claro del propio dorado** (`alpha: 0.06–0.15`), no
sobre una superficie sólida blanca. **No es el mismo defecto que corrigió
`colorPrecio()`** (034: dorado sobre blanco sólido, ~1.63:1) — es el mismo
tipo de hallazgo que la 035 dejó sin corregir en el badge de estado de
`detalle_trabajo_screen.dart` (dorado sobre tinte de sí mismo), un contraste
distinto que ninguna tarea de ADR-0016 ha calculado todavía. Se anota aquí,
en `docs/agent-tasks/036-*.md` y en el snapshot, para que QA o una tarea de
contraste dedicada lo revise. No se corrigió porque:

1. Es un cambio de color, no de tipografía/espaciado/radios — fuera del
   alcance declarado de esta tarea.
2. No coincide con el patrón exacto que ya tiene una solución conocida
   (`colorPrecio`, que es específicamente "texto sobre superficie sólida
   clara"), así que aplicarlo aquí habría sido inventar una solución nueva
   sin que el dueño la pidiera.

## Deuda preexistente, no resuelta (fuera de alcance)

`mis_postulaciones_screen.dart` tiene su propio bloque de estado vacío/error
inline (`_estadoVacio`, y el `Center`/`Column` del error dentro de
`_listaConEstado`) que **duplica casi literalmente**
`EstadoVacioPostulantes`/`EstadoErrorPostulantes` (extraídos de
`postulantes_screen.dart` en la tarea 027 B-2b) en vez de reusarlos. Esta
tarea tokenizó ambas copias por separado, sin deduplicarlas: unificarlas es
un cambio estructural (mover código entre pantallas, generalizar los dos
widgets para los textos que difieren) fuera del alcance de "aplicar tokens
de tipografía/espaciado/radios" que pedía la 036. Se anota para que una
tarea de limpieza futura lo considere.

## Verificación

- `flutter analyze`: **19 issues, 0 errores** — idéntico a la línea base de
  la 035, ninguno nuevo, ninguno en los 6 archivos tocados.
- `flutter test`: **261/261 pasan**, mismo total que antes de la tarea.
  Ningún test necesitó cambios: el único test de widget de esta
  funcionalidad (`tarjeta_postulante_test.dart`) solo afirma sobre
  `find.text(...)`/`find.byIcon(...)`/callbacks, no sobre valores concretos
  de `fontSize`/`EdgeInsets`/`BorderRadius`.
- Verificado con `git stash push -- <los 6 archivos>` + `flutter analyze`/
  `flutter test` sobre el código "antes", y de nuevo tras `git stash pop`
  restaurando "después": mismos resultados en ambos casos (19/0 y 261/261).

## Verificación visual — capturas reales, sin tocar el emulador

Mismo criterio que 032-035 (evitar pisar una sesión de `flutter run` ajena):
se escribió `test/manual/generar_capturas_postulaciones.dart`.

- Monta **la pantalla real** (`PostulantesScreen`) — no una recomposición
  manual de sus widgets — con `PublicacionService`/`PostulacionService`/
  `PerfilService` reales, inyectados vía `MultiProvider`, apuntando a un
  `MockClient` en memoria que responde `/api/trabajos/trab-1` (el trabajo
  fijo) y `/api/postulaciones` (la lista de postulantes según el escenario)
  — mismo patrón exacto que `generar_capturas_trabajos.dart` (034) y
  `generar_capturas_detalle_trabajo.dart` (035).
- 3 escenarios (0, 1 y 3 postulantes, con estados pendiente/aceptada/
  rechazada mezclados en el de "varios") × 2 temas = 6 capturas "después".
- **"Antes"**: `git stash push -- <los 6 archivos>` (sin tocar el
  generador), se corrió con `--dart-define=SUFIJO=antes`, luego
  `git stash pop` para restaurar; se reverificó `flutter analyze`/
  `flutter test` después del `pop` (mismos resultados).
- No termina en `_test.dart` a propósito: `flutter test` sin argumentos no
  lo descubre. Se invoca a mano.

12 archivos en `docs/agent-reports/capturas/036-postulantes-{0,1,varios}-
{antes,despues}-{claro,oscuro}.png`.

**Revisadas una por una:** la bandeja de postulantes se ve correcta en ambos
temas y en los tres escenarios; el estado vacío ("Todavía no hay
postulantes"), las tarjetas con el avatar dorado, el badge de estado
(gris/verde/rojo según pendiente/aceptada/rechazada), el marco verde y el
check del elegido (no ejercitado en este set porque ningún escenario asigna
`trabajadorAsignadoId`, pero cubierto por `tarjeta_postulante_test.dart`), y
el cuadro de mensaje en dorado tenue se leen bien. Comparando antes/después
del mismo escenario (`postulantes-varios-claro`): el layout es visualmente
casi idéntico (cambio esperado, tokens con los mismos valores numéricos en
la mayoría de los casos), con el único cambio perceptible siendo el
interlineado ligeramente distinto de `AppTipografia` frente a los
`TextStyle` sueltos anteriores. Limitación conocida y ya documentada por
032-035: el texto de `ElevatedButton`/`OutlinedButton` sale como bloque
opaco en estas capturas porque `AppTema` no fija `fontFamily: 'Sora'` en sus
temas de botón — preexistente, no de esta tarea, no visible en un
dispositivo real.

No se generaron capturas separadas de `mis_postulaciones_screen.dart` ni
`postularse_sheet.dart`: el criterio de aceptación de la tarea pide
explícitamente capturas de "la lista de postulantes con 0, 1 y varios
candidatos", que es lo que cubre `PostulantesScreen`. Los otros dos archivos
se verificaron por lectura de código + `flutter analyze`/`flutter test`
(sin cambios de comportamiento, solo sustitución de `TextStyle`/`EdgeInsets`/
`BorderRadius` literales por los tokens de valor numérico equivalente o el
redondeo ya documentado).

## Qué NO se tocó (fuera de alcance, explícito en la instrucción de la tarea)

- El flujo de aceptar/rechazar postulantes y las llamadas a
  `PostulacionService` (`aceptar`, `retirar`, `postular`, `postulantesDe`,
  `misPostulaciones`): cero cambios.
- `test/funcionalidades/trabajos/widgets/` (tarea 029, QA).
- Colores (salvo el hallazgo de contraste documentado arriba, dejado sin
  tocar a propósito).
- El vocabulario de movimiento de ADR-0015 (`PulsaConEscala` en
  `mis_postulaciones_screen.dart`, el `EstadoExito` de `postularse_sheet.dart`):
  intacto, no se añadió ni se duplicó ninguna animación.

## Archivos tocados

**Modificados (6):**
- `lib/funcionalidades/postulaciones/pantallas/postulantes_screen.dart` (192 → 200)
- `lib/funcionalidades/postulaciones/pantallas/mis_postulaciones_screen.dart` (297 → 298)
- `lib/funcionalidades/postulaciones/pantallas/postularse_sheet.dart` (149 → 158)
- `lib/funcionalidades/postulaciones/pantallas/widgets/cabecera_postulantes.dart` (49 → 51)
- `lib/funcionalidades/postulaciones/pantallas/widgets/estados_postulantes.dart` (69 → 73)
- `lib/funcionalidades/postulaciones/pantallas/widgets/tarjeta_postulante.dart` (179 → 181)

**Nuevo — herramienta de verificación (no se ejecuta en la suite normal):**
- `test/manual/generar_capturas_postulaciones.dart`

**Nuevas — 12 capturas:**
- `docs/agent-reports/capturas/036-postulantes-{0,1,varios}-{antes,despues}-{claro,oscuro}.png`

**Documentación:**
- `docs/agent-tasks/036-rediseno-postulaciones.md` (estado → hecho, checkboxes y notas)
- `docs/agent-context/repo-snapshot.md`
- `docs/agent-reports/036-rediseno-postulaciones.md` (este archivo)

No se tocó `backend/**`, `firestore.rules`, ni ningún archivo fuera de
`postulaciones/`/`test/manual`. No se hizo commit: los cambios quedan en el
working tree para revisión del usuario.
