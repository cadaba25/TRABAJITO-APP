# Reporte — tarea 039: hotfixes de QA del dueño (letra del logo, degradados, scroll, tarifa)

**Fecha:** 2026-09-12
**Agente:** flutter-agent
**Rama:** `feature/hotfixes-qa-039` (sobre `feature/rediseno-postulaciones`, con la 036 sin commitear)
**Estado:** hecho

## Qué se hizo

Cuatro arreglos puntuales sin relación entre sí (el quinto punto, "íconos de
skills", quedó explícitamente fuera). Ninguno toca `backend/` ni cambia
contrato de API/modelo de datos.

### 1. Letra dorada del logo: de la "t" a la "i"

`LogoTextoSolo` y `LogoTrabajito` (`lib/compartido/widgets/logo_trabajito.dart`)
pasan el split de `TextSpan` de `'Trabaji' + 't'(dorado) + 'o'` a
`'Trabaj' + 'i'(dorado) + 'to'`. Cambio puramente de datos (qué tramo de texto
recibe el `TextStyle(color: AppColores.dorado)`), sin tocar `AppColores` ni la
paleta.

- Ningún test existente asumía el split anterior (no había ninguna cobertura
  de este widget). Se añadió `test/compartido/widgets/logo_trabajito_test.dart`,
  que inspecciona los `TextSpan` hijos del `RichText` (no solo el texto
  completo, que no distingue "la 't' dorada" de "la 'i' dorada") — es lo único
  que puede detectar en el futuro que alguien vuelva a mover el color a la
  letra equivocada.

### 2. Ocultar `BarraBusquedaTrabajos`/`ToggleFeedTrabajos` al hacer scroll

Autorizado como excepción puntual a la lista cerrada de ADR-0015 (adenda
2026-09-12 en `docs/decisions.md`, solo para estas dos barras de
`TrabajosTab`).

**Mecanismo elegido:** `SizeTransition` (`sizeFactor`, `axisAlignment: -1`)
+ `AnimationController`, envolviendo — no desmontando — las dos barras
reales, atado a `ScrollPosition.userScrollDirection` en el listener que ya
existía para paginar (`_alHacerScroll`). Se descartó `SliverAppBar`
`floating`/`snap` (habría exigido migrar `ListView.builder` a
`CustomScrollView`, un cambio de estructura mayor para un fix puntual) y
descartar el widget del árbol al colapsar (perdería el texto ya escrito en
el buscador: `BarraBusquedaTrabajos` usa un `TextField` sin `controller`
propio — el texto vive en `_TrabajosTabState`, no en el campo — así que
desmontar el widget lo habría reseteado cada vez que se colapsa).

Reglas:
- `pos.pixels <= 0` → siempre visibles (no hace falta subir deslizando si ya
  se está arriba del todo).
- `ScrollDirection.reverse` (bajando) → colapsa.
- `ScrollDirection.forward` (subiendo) → reaparece.
- `duracionMov`/`curvaMov` (ADR-0015 punto 5): con `disableAnimations` el
  colapso es instantáneo, no ausente.

**Extraído a `lib/funcionalidades/trabajos/pantallas/widgets/colapso_barras_scroll.dart`**
(no es un widget, es el controlador que alimenta el `sizeFactor`) para no
pasar de 300 líneas en `trabajos_tab.dart` al sumar esta lógica al resto de
la tarea. Por el mismo motivo se extrajo también
`widgets/lista_feed_trabajos.dart` (la `ListView` paginada con
`RefreshIndicator`, que ya vivía en `trabajos_tab.dart` como método privado).
Ninguno de los dos cambia comportamiento del feed, solo mueve código ya
existente a su propio archivo.

Ningún test de widget de `BarraBusquedaTrabajos`/`ToggleFeedTrabajos` se tocó
(los montan de forma standalone, sin el `SizeTransition` que solo existe en
`trabajos_tab.dart`).

### 3. Degradado con banding en `encabezado_feed.dart`/`cabecera_perfil.dart`

**Causa real (investigada, no asumida) — ver "Investigación del banding"
abajo para el detalle completo:** el `LinearGradient` diagonal de 2 paradas
`principal → azulProfesional` no entra por el "fast path" sin dithering de
Impeller (ese exige eje horizontal/vertical), pero con solo 2 colores cae en
`RenderUniform` si el backend de GPU no soporta SSBO — y ese shader
(`linear_gradient_uniform_fill.frag`) **no tiene ninguna llamada a
dithering**, a diferencia de `RenderSSBO` (`IPOrderedDither8x8`). Este
emulador corre confirmado **"Impeller (OpenGLES)"** (log de `flutter run`),
el backend donde eso pasa. El canal rojo, con un rango de solo 8 valores
enteros (`0x0D`→`0x15`) repartido en ~830 px de ancho, quedaba en escalones
de ~100-130 px.

**Arreglo:** una tercera parada, `AppColores.azulClaro` (ya declarado en
`app_colores.dart`, no un color de marca nuevo) a mitad de camino. No está
sobre la recta que conecta `principal` y `azulProfesional`, así que cada
canal recorre su rango en dos tramos más cortos en vez de uno largo —
verificado empíricamente (ver abajo) que el escalón más ancho del rojo baja
de ~130 px a ~50-56 px. **No se intentó "solo añadir más paradas sobre la
misma recta"**: eso no cambia nada matemáticamente (misma interpolación,
mismos valores en cualquier punto de la recta original), así que el color
intermedio tenía que salirse de esa recta a propósito.

Mismo cambio en los dos archivos (mismo degradado exacto). El docstring
completo de la investigación vive en `encabezado_feed.dart`;
`cabecera_perfil.dart` referencia ese docstring en vez de repetirlo.

### 4. Campo de pago reestructurado

`publicar_trabajo_screen.dart` y `editar_trabajo_screen.dart` (deshabilitada,
pero mantenida consistente) cambian el único campo "Pago por hora en
Lempiras (opcional)" por "Tarifa en Lempiras (opcional)" + un `Wrap` de
`ChoiceChip` ("Se cobra por": día/hora/semana/contratación completa) — mismo
patrón visual que ya usa "Plazo de contratación" en la misma pantalla (se
prefirió sobre un `CustomDropdown` por esa consistencia explícita que pedía
la tarea).

Extraído a `lib/funcionalidades/trabajos/pantallas/widgets/selector_tarifa.dart`
(el campo + los chips, más `SelectorTarifa.formatearPresupuesto` estático),
compartido entre ambas pantallas para no duplicar el `Wrap`/`ChoiceChip` dos
veces. Sigue componiendo el mismo `presupuesto: String` de siempre — **no se
tocó `PublicacionService` ni ningún endpoint**, confirmado en el contexto de
la tarea y no contradicho por nada encontrado durante la implementación.

Formato de salida (`día`/`hora`/`semana` sin cambios de forma; `contratación
completa` es formato nuevo, no había uno previo que igualar):
- `'L. 150/día'`, `'L. 150/hora'`, `'L. 5000/semana'`
- `'L. 20000 (contratación)'`

En `editar_trabajo_screen.dart` se añadió `_detectarUnidad(presupuesto)`
(best-effort, no un parser estricto) para preseleccionar el chip correcto a
partir del texto libre ya guardado (p. ej. `'L. 645/hora'` → chip "hora"
activo). Si no reconoce nada cae en "hora" (la única unidad que existía antes
de esta tarea). Verificado en vivo: un trabajo con presupuesto `'L. 645/hora'`
abre con "hora" ya seleccionado.

Se añadió `DatosEmpleador.unidadesTarifa` (lista nueva) para alimentar el
selector; no cambia el contrato con el backend.

## Investigación del banding — detalle técnico completo

1. **Captura real del emulador** (`adb exec-out screencap -p`, PNG sin
   pérdida) sobre la tarjeta "Hola, IPLEX" del feed, en una zona lisa del
   degradado (sin texto/avatar encima).
2. **Muestreo de píxeles** (decodificando el PNG con `dart:ui` dentro de un
   `flutter test` — `image.toByteData(format: rawRgba)` — no hay `image`
   package en el proyecto y no hacía falta añadirlo): con el degradado de 2
   paradas, el canal R se mantenía constante durante 14-33 muestras
   consecutivas (cada muestra cada 4 px), es decir, escalones de **56 a
   132 px de ancho**, en una secuencia estrictamente monótona sin ningún
   ruido de dithering (si hubiera dithering, los valores oscilarían ±1
   alrededor del valor "real" en vez de quedarse planos).
3. **Lectura del motor** (`engine/src/flutter/impeller/entity/contents/
   linear_gradient_contents.cc` y los shaders
   `linear_gradient_{uniform_fill,ssbo_fill}.frag`,
   `gradients/fast_gradient.frag`, todos dentro del propio SDK de Flutter
   instalado): `LinearGradientContents::Render()` prueba, en orden,
   `CanApplyFastGradient()` (exige gradiente exactamente horizontal o
   vertical — el nuestro es diagonal, topLeft→bottomRight, así que no
   califica), luego `RenderSSBO` si `SupportsSSBO()`, si no
   `RenderUniform`. `linear_gradient_uniform_fill.frag` no incluye ninguna
   llamada a `IPOrderedDither8x8`; `linear_gradient_ssbo_fill.frag` sí.
4. **Confirmación del backend real**: el log de `flutter run` sobre este
   emulador imprime literalmente
   `Using the Impeller rendering backend (OpenGLES)`. Eso es justo el tipo
   de backend donde `SupportsSSBO()` suele ser `false` (compatible con lo
   observado: sin dithering).
5. **Arreglo y verificación empírica**: se añadió la tercera parada
   (`AppColores.azulClaro`), se reconstruyó la app (`flutter run` completo,
   ver nota sobre `flutter attach` más abajo) y se repitió el mismo
   muestreo de píxeles sobre una captura nueva del mismo emulador: el
   escalón más ancho del canal rojo bajó a **~50-56 px**. Capturas:
   `docs/agent-reports/capturas/039-gradiente-{antes,despues}.png`.

**Se descartaron las otras dos hipótesis del enunciado** (antialiasing pobre
del `BorderRadius`, composición con el `CircleAvatar` semitransparente): el
muestreo se hizo en zonas sin ningún borde ni el avatar encima, y el patrón
observado (plateaus por canal de ancho variable, alineado exactamente con el
rango de cada canal entre los dos colores) es la firma de cuantización de
gradiente, no de antialiasing ni de composición alfa.

## Nota sobre la verificación en el emulador — `flutter attach` dejó código viejo

Para validar los puntos 2 y 3 en vivo hizo falta iterar con el emulador
(`emulator-5554`, la sesión de `flutter run` que ya traía esta cadena de
tareas). **`flutter attach` + hot reload/restart no fue confiable en este
entorno**: tras corregir un error de compilación real (`ScrollDirection` no
se resuelve solo con `package:flutter/material.dart` en esta versión del
SDK — hace falta `import 'package:flutter/rendering.dart' show
ScrollDirection;`, añadido en `colapso_barras_scroll.dart`), un `flutter
attach` + `R` (hot restart) reportó "Restarted application" sin error, pero
`PublicarTrabajoScreen` siguió mostrando el campo viejo ("Pago por hora")
mientras que `EditarTrabajoScreen` (mismo widget `SelectorTarifa`) sí mostró
el cambio — inconsistencia que apunta a un kernel cacheado parcialmente
stale del lado de `attach`, no a un error del código (confirmado con `grep`
sobre el archivo en disco: el código fuente era correcto). Se resolvió
haciendo un **`flutter run` completo** (build + install real), que sí
reflejó todos los cambios de la tarea de una vez. La captura
`039-tarifa-publicar-antes.png` es, de hecho, ese momento de código viejo
cacheado — coincide en contenido con el "antes" real (el campo no había
cambiado desde antes de esta tarea), así que se reusa como tal, con esta
nota de transparencia sobre cómo se obtuvo.

El proceso de `flutter run` que queda corriendo al terminar es uno nuevo
(pid de la app en el dispositivo: `19964`, reemplaza al `18625` que ya
existía) — sigue siendo la app real (`lib/main.dart`), con la sesión de
`IPLEX` (empleador) ya iniciada, mostrando el feed.

## ⚠️ Detectado durante la tarea: trabajo concurrente de otros agentes en el mismo directorio de trabajo

Al hacer `git stash push -- lib/compartido/widgets/logo_trabajito.dart` /
`git stash pop` para capturar el "antes"/"después" del logo (operación
acotada a ese único archivo), `git status` reveló que el working tree de
`C:\Users\enigm\Desktop\EquipoAgentes` — el mismo directorio en el que
estuve trabajando toda la tarea, en la rama `feature/hotfixes-qa-039` —
tiene también cambios sin commitear que **no son míos ni de la tarea 036**:

- `backend/README.md`, `backend/src/main/java/com/trabajito/modules/trabajos/{TrabajoController,TrabajoService}.java`, `backend/src/test/java/.../TrabajoServiceTest.java`, `docs/api.md` (modificados).
- `backend/src/test/java/.../EditarTrabajoHttpTest.java`, `docs/agent-tasks/040-backend-editar-trabajo.md`, `docs/agent-tasks/041-flutter-editar-trabajo.md`, `docs/agent-tasks/042-seguridad-editar-trabajo.md`, `docs/agent-reports/040-backend-editar-trabajo.md`, `docs/agent-reports/042-seguridad-editar-trabajo.md` (sin trackear).

Por las fechas de modificación (17:41–17:56, dentro de la ventana en la que
yo estaba trabajando en esta misma tarea) y porque **mi propia tarea 039 ya
anticipaba esto** ("No habilita la edición de una publicación ya guardada
(PUT `/api/trabajos/{id}`) — eso es una tarea aparte, cross-módulo, que el
`tech-lead` está planificando por separado"), todo indica que
`backend-agent` (tarea 040) y `security-agent` (tarea 042) — y
presumiblemente `flutter-agent` en la tarea 041, "flutter-editar-trabajo",
que muy probablemente vuelve a tocar `editar_trabajo_screen.dart` — han
estado trabajando **en paralelo, en el mismo directorio de trabajo físico**,
mientras yo trabajaba en él.

**No toqué ninguno de esos archivos** (confirmado con `git diff --stat`
acotado a `lib/`/`test/`/mis dos archivos de `docs/`: solo aparecen los
archivos de mi propia tarea) y mi `git stash`/`git stash pop` estuvo acotado
a un único path, así que no debería haber pisado nada de lo suyo. Pero
**un directorio de trabajo compartido entre agentes que corren en paralelo
es una condición de carrera esperando pasar** (un `git checkout`/`reset`/
`stash` sin pathspec de cualquiera de los agentes involucrados podría perder
el trabajo de otro) — lo marco aquí explícitamente para que el `tech-lead`
lo evalúe; no es algo que me corresponda resolver a mí (regla 13 de
`CLAUDE.md`). No hice nada para "limpiar" ni ocultar esos archivos: siguen
exactamente como los encontré.

## Verificación

- `flutter analyze`: **19 issues, 0 errores** — idéntico a la línea base de
  la 036, ninguno nuevo, ninguno en los archivos tocados por esta tarea.
- `flutter test`: sube de 261 a **263/263** (+2: el nuevo
  `logo_trabajito_test.dart`). Ningún test existente necesitó cambios.
- **Verificación visual: sí se usó el emulador real** (`emulator-5554`),
  para los puntos 2 y 3 en concreto (gestos reales con
  `adb shell input swipe`/`tap`, capturas con `adb exec-out screencap`, y el
  muestreo de píxeles descrito arriba). El punto 1 se verificó con el test
  de widget nuevo (y con una captura widget-test aparte, ver abajo, ya que
  el `RichText` con la letra dorada no es visualmente distinguible a simple
  vista en una captura de pantalla completa sin acercarse mucho). El punto 4
  se verificó en vivo en ambas pantallas (`PublicarTrabajoScreen` con
  formulario vacío, `EditarTrabajoScreen` con la unidad detectada
  correctamente desde un presupuesto ya guardado).

## Capturas

Todas en `docs/agent-reports/capturas/`:

- **Punto 1 (logo):** `039-logo-{antes,despues}-{claro,oscuro}.png` — widget
  test aislado (`test/manual/generar_capturas_logo.dart`, "antes" con
  `git stash push -- lib/compartido/widgets/logo_trabajito.dart`, "después"
  tras `git stash pop`).
- **Punto 2 (scroll):** `039-scroll-arriba.png` (barras visibles, arriba del
  todo) → `039-scroll-abajo.png` (barras colapsadas tras deslizar hacia
  abajo) → `039-scroll-vuelve-arriba.png` (barras de vuelta tras deslizar
  hacia arriba). Las tres son capturas reales del emulador.
- **Punto 3 (degradado):** `039-gradiente-{antes,despues}.png` — capturas
  reales del emulador, mismo trabajo/misma posición de scroll en ambas.
- **Punto 4 (tarifa):** `039-tarifa-publicar-{antes,despues}.png` (formulario
  de publicar, vacío) y `039-tarifa-editar-despues.png` (formulario de
  editar, con "hora" ya detectado desde `'L. 645/hora'`) — capturas reales
  del emulador. Ver la nota sobre `flutter attach` arriba para el origen del
  "antes" de publicar.

## Archivos tocados

**Modificados:**
- `lib/compartido/widgets/logo_trabajito.dart` — split de `TextSpan` (punto 1)
- `lib/funcionalidades/trabajos/pantallas/trabajos_tab.dart` — usa
  `ColapsoBarrasScroll`/`ListaFeedTrabajos`, `SizeTransition` en el build
  (punto 2)
- `lib/funcionalidades/trabajos/pantallas/widgets/encabezado_feed.dart` —
  degradado de 3 paradas + docstring de la investigación (punto 3)
- `lib/funcionalidades/perfil/pantallas/widgets/cabecera_perfil.dart` —
  mismo degradado de 3 paradas (punto 3)
- `lib/funcionalidades/trabajos/pantallas/publicar_trabajo_screen.dart` —
  usa `SelectorTarifa` (punto 4)
- `lib/funcionalidades/trabajos/pantallas/editar_trabajo_screen.dart` — usa
  `SelectorTarifa` + `_detectarUnidad` (punto 4)
- `lib/compartido/datos/datos_empleador.dart` — `unidadesTarifa` (punto 4)

**Nuevos:**
- `lib/funcionalidades/trabajos/pantallas/widgets/colapso_barras_scroll.dart`
  (punto 2)
- `lib/funcionalidades/trabajos/pantallas/widgets/lista_feed_trabajos.dart`
  (extracción de `trabajos_tab.dart`, sin cambio de comportamiento, para no
  pasar de 300 líneas — punto 2)
- `lib/funcionalidades/trabajos/pantallas/widgets/selector_tarifa.dart`
  (punto 4)
- `test/compartido/widgets/logo_trabajito_test.dart` (punto 1)
- `test/manual/generar_capturas_logo.dart` — herramienta de verificación, no
  se ejecuta en la suite normal (punto 1)
- 15 capturas en `docs/agent-reports/capturas/039-*.png`

**Documentación:**
- `docs/agent-tasks/039-hotfixes-qa-dueno.md` (estado → hecho, checkboxes y notas)
- `docs/agent-context/repo-snapshot.md`
- `docs/agent-reports/039-hotfixes-qa-dueno.md` (este archivo)

No se tocó `backend/**`, `firestore.rules`, ni ningún archivo de la tarea 036
(`postulaciones/**`) ni de las tareas 040/041/042 detectadas en paralelo (ver
sección de arriba). No se hizo commit: los cambios quedan en el working tree
para revisión del usuario.
