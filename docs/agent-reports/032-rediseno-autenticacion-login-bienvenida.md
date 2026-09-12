# Reporte — tarea 032: rediseño visual, autenticación (login y bienvenida)

**Fecha:** 2026-09-11
**Agente:** flutter-agent
**Rama:** `feature/rediseno-autenticacion` (sobre `feature/rediseno-fundamentos`, con la 031 mergeada)
**Estado:** hecho

## Qué se hizo

Se migraron las dos pantallas piloto de `lib/funcionalidades/autenticacion/pantallas/`
a los tokens de la tarea 031 (ADR-0016): `login_screen.dart` (278→291 líneas)
y `bienvenida_registro_screen.dart` (239→254 líneas). Ambas siguen bajo el
techo de 300 de ADR-0014.

### Tipografía

Todos los `TextStyle(fontSize:, fontWeight:)` literales se sustituyeron por
`Theme.of(context).textTheme.<rol>` (extensión de la 031), usando
`.copyWith(color: ...)` solo para el color por-tema (que no es parte del rol)
y, en un caso, `fontWeight` para un énfasis puntual (ver "Desvíos" abajo).

**Criterio de consistencia decidido (punto 4 de la tarea):** antes, el
renglón principal de cada pantalla tenía un tratamiento distinto y sin
relación entre sí:

| Elemento | Antes | Después |
|---|---|---|
| "Bienvenido a Trabajito" (login) | `headlineSmall` recompuesto a mano con `fontWeight: w800, letterSpacing: -0.5` | `tituloGrande` (28/w800) |
| "¡Hola!" (bienvenida) | `fontSize: 28, fontWeight: w900` literal | `tituloGrande` (28/w800) |
| "¿Qué te trae a Trabajito?" (bienvenida) | `fontSize: 22, fontWeight: w800` literal | `titulo` (22/w700) |

Se fijó el criterio: **el renglón "hero" de una pantalla de autenticación
usa `tituloGrande`; el renglón de apoyo inmediato usa `titulo`.** Login solo
tenía un renglón de encabezado, así que pasa directo a `tituloGrande` (era
ya visualmente lo más parecido — 28 vs. 24 del `headlineSmall` nativo que
usaba antes, con `copyWith` cambiándole el tamaño de hecho a 24→28 de forma
indirecta). El cambio visual neto es mínimo: los pesos de "¡Hola!" y "¿Qué
te trae...?" bajan un escalón (w900→w800, w800→w700) para alinearse con la
escala de 3 pesos consecutivos que define `AppTipografia` (w500/w600/w700 +
el salto a w800 de `tituloGrande`) — ver capturas antes/después, la
diferencia no es perceptible a simple vista.

Resto de mapeos de tipografía (todos con exactamente el rol cuya
descripción en `app_tipografia.dart`/el reporte 031 encaja con el uso):

| Texto | Antes | Rol usado |
|---|---|---|
| Subtítulo de login ("Inicia sesión para continuar") | sin tamaño (heredaba `bodyMedium`) | `cuerpo` |
| "¿Olvidaste tu contraseña?" | `fontSize: 13` suelto | `cuerpoChico` (13 exacto) |
| Título del diálogo "Recuperar contraseña" | solo `fontWeight: w700` | `subtitulo` (17/w600) |
| Tagline del logo ("Conecta. Contrata. Resuelve.") | `fontSize: 12` suelto | `etiqueta` (11, el más cercano; ver "Desvíos") |
| "¿No tienes cuenta?" / "¿Ya tienes una cuenta?" (footer, ambas pantallas) | sin tamaño | `cuerpo` |
| "Regístrate" / "Inicia sesión" (link del footer, ambas pantallas) | `fontWeight: w700` suelto | `cuerpo.copyWith(fontWeight: w700)` — incluye el rol para que la línea completa del footer tenga un solo tamaño de fuente |
| Título de `_TarjetaOpcion` ("Busco trabajo"/"Busco contratar") | `fontSize: 16, fontWeight: w700` | `subtitulo` (17/w600) — es literalmente "cabecera de tarjeta", el uso previsto que documenta la 031 |
| Descripción de `_TarjetaOpcion` | `fontSize: 13, height: 1.4` | `cuerpoChico` (13/w500/1.35) |
| Badge "Pronto" (código hoy inalcanzable, ver abajo) | `fontSize: 10, w600` | `etiqueta` (11, más cercano) |

### Espaciado y radios

Todos los `SizedBox(height/width: N)` y `EdgeInsets.symmetric(horizontal: 24)`
pasaron a `AppEspaciado.<rol>`. Las conversiones no exactas (la escala es
4/8/12/16/24/32 y algunos valores originales caían entre dos roles) quedaron
así, todas comentadas en el propio código:

- `SizedBox(height: 40)` (3 apariciones en `login_screen`, 1 en
  `bienvenida_registro_screen`) → `AppEspaciado.xxl` (32). Es el mismo caso
  que señaló la auditoría de la 031 ("≈19 valores de 2 a 40"); se redondea
  al vecino más cercano de la escala en vez de añadir un séptimo rol para
  un solo valor.
- `SizedBox(height: 6)` (bajo la tagline del logo) → `AppEspaciado.sm` (8).
- `EdgeInsets.all(20)` (padding de `_TarjetaOpcion`) → `AppEspaciado.lg`
  (16) — 20 no cae exacto en la escala (16 y 24 son los vecinos), se eligió
  16 para no ensanchar la tarjeta respecto al resto de la pantalla.
- Badge "Pronto": `EdgeInsets.symmetric(horizontal: 6, vertical: 2)` →
  `horizontal: AppEspaciado.sm (8), vertical: AppEspaciado.xs (4)` — código
  hoy inalcanzable (ver abajo), aproximación razonable.

Radios: `BorderRadius.circular(16)` (tarjeta de opción, diálogo de
recuperar contraseña) → `AppRadios.tarjeta`. `BorderRadius.circular(10)`
(insignia de icono de 44×44) → `AppRadios.campo` (12, el rol más cercano;
comentado en el código que es una insignia, no un campo real, pero es el
rol de radio más parecido de los tres). `BorderRadius.circular(4)` del
badge "Pronto" se deja **literal, a propósito** — mismo criterio que el
checkbox de `AppTema` en la 031 (forma nativa muy pequeña, no un
chip/tarjeta/campo real; `AppRadios.chip` es 20, para formas casi/del todo
redondeadas, no aplica aquí).

### Lo que NO se tocó (fuera de alcance, explícito en la instrucción de la tarea)

- **Colores.** El reporte de la 031 señalaba `bienvenida_registro_screen.dart`
  como candidata a los roles nuevos `colorSuperficieAlterna` y
  `colorDeshabilitado` (7+ usos de `AppColores.acento.withOpacity(...)` con
  el mismo propósito). La instrucción de esta tarea 032 fue explícita: solo
  tipografía/espaciado/radios. No se migró ningún color role. Sí se
  limpiaron, de paso (por tocar esas líneas de todos modos para el radio),
  los 2 `withOpacity` deprecados de ese archivo a `.withValues(alpha:)`
  (mismo valor numérico, sin cambio visual, solo limpieza del `info` del
  analyzer).
- Contratos de `AuthService`/`PerfilService`, validaciones de formulario,
  navegación: cero cambios.
- Vocabulario de movimiento de ADR-0015 (`FadeTransition`/`SlideTransition`
  de `login_screen`): intacto.
- Tamaños de icono (`size: 22`, `size: 14`), `Size(0, 32)` del botón
  "¿Olvidaste tu contraseña?", `SizedBox(height/width: 20)` del spinner de
  carga, y las dimensiones `44×44`/`84`/`30`/`36` de logos e insignias: no
  son espaciado ni tipografía, son tamaños de componente — se dejaron tal
  cual.
- El parámetro `proximamente` de `_TarjetaOpcion` (y el badge "Pronto" que
  depende de él) sigue sin ningún call site que lo pase en `true` — es un
  warning preexistente del analyzer (`unused_element_parameter`), no
  introducido ni agravado por esta tarea. No se eliminó la funcionalidad
  (regla "no borrar funcionalidad existente sin autorización explícita").

## Limpieza de paso (archivos ya tocados)

Siguiendo la regla de limpiar issues preexistentes en archivos que de todos
modos se editan:

- `login_screen.dart`: `builder: (_, oscuro, __)` → `(_, oscuro, _)`
  (`unnecessary_underscores`, info preexistente).
- `bienvenida_registro_screen.dart`: 2 `withOpacity` → `withValues(alpha:)`
  (`deprecated_member_use`, info preexistente).

No se tocó el warning `unused_element_parameter` de `proximamente` (ver
arriba) ni el `unused_field` de `registro_trabajador_screen.dart` (archivo
no tocado por esta tarea).

## Verificación

- `flutter analyze`: **33 issues, 0 errores** (baseline antes de esta tarea:
  36 — confirmado corriendo `flutter analyze` con `git stash` sobre los dos
  archivos, ver metodología en la tarea 031). Los 3 issues que bajaron son
  exactamente los de la sección anterior. Ningún issue nuevo introducido.
- `flutter test`: **253/253 pasan**, mismo total que antes de esta tarea (no
  se tocó comportamiento, solo estilo/espaciado). `login_screen_test.dart`
  (el único test que monta una de estas dos pantallas) sigue en verde sin
  cambios.

## Capturas antes/después (claro y oscuro)

En `docs/agent-reports/capturas/`:

- `032-login-claro-antes.png` / `032-login-claro-despues.png`
- `032-login-oscuro-antes.png` / `032-login-oscuro-despues.png`
- `032-bienvenida-claro-antes.png` / `032-bienvenida-claro-despues.png`
- `032-bienvenida-oscuro-antes.png` / `032-bienvenida-oscuro-despues.png`

Tomadas en un emulador Android real (`sdk gphone16k x86 64`, API 36,
`emulator-5556`, AVD `Pixel_9`) corriendo la app real (`flutter run`, sin
harness) — no un widget aislado, así que las capturas incluyen efectos que
no dependen de esta tarea (el fundido/slide de entrada de `login_screen` ya
había terminado en el momento de la captura). Metodología: se corrió la app
con el código actual (tras esta tarea) para las capturas "después"; luego
`git stash push` sobre los dos archivos para volver al código pre-tarea,
`kill` + relanzar `flutter run` (hot reload no aplica a un cambio de tema
tipográfico compilado en el árbol de widgets, así que se usó reinstalación
completa) para las capturas "antes"; y `git stash pop` para restaurar. Se
verificaron `flutter analyze`/`flutter test` de nuevo tras el `stash pop`.

Ambos temas se ven correctamente contrastados — se confirma visualmente que
el arreglo de contraste de la tarea 031 (botón "Iniciar sesión" en modo
oscuro: texto marino sobre dorado) sigue vigente y estas dos pantallas lo
heredan sin tocarlo.

## Incidente de emulador — reportado en detalle, resuelto sin pérdida de datos

Antes de tocar el emulador, se corrió `adb devices` y
`adb shell pidof com.trabajito.trabajito` (siguiendo la instrucción
explícita de la tarea): había una sesión ajena viva en `emulator-5554`
(usuario "Mario Kempes", en `InicioScreen`, mostrando en ese momento un
error de conexión transitorio). Para no interferir:

1. **No se instaló nada sobre `emulator-5554`.** Se usó `flutter emulators`
   para ver los AVD disponibles y se levantó uno nuevo y propio (`Pixel_9`,
   que arrancó como `emulator-5556`) exclusivamente para las capturas de
   esta tarea, corriendo la app real (nunca un harness desechable — estas
   dos pantallas son la entrada natural de la app sin sesión, así que no
   hacía falta ningún `main_captura_*.dart`).
2. **Aun así, en algún momento durante el trabajo (con los dos emuladores
   Android corriendo a la vez sobre el mismo host), `emulator-5554` se cayó
   solo** — al terminar de usar `emulator-5556` y apagarlo explícitamente
   (`adb -s emulator-5556 emu kill`), un chequeo de `adb devices` mostró
   **ambos** emuladores caídos, con procesos `crashpad_handler` huérfanos
   (evidencia de que el proceso del emulador murió, no de que `adb` perdiera
   la conexión). No hay una causa aislada confirmada (contención de
   recursos del host es la hipótesis más probable), y no se ejecutó ningún
   comando dirigido a `emulator-5554` en ningún momento — pero el resultado
   fue el mismo: la sesión ajena se interrumpió, exactamente el escenario
   que la instrucción de la tarea pedía evitar. Se reporta sin minimizarlo.
3. **Recuperación:** se identificó que `emulator-5554` correspondía al AVD
   `Pixel_6` (por el timestamp de su `multiinstance.lock`, anterior al
   inicio de esta sesión de trabajo) y se relanzó
   (`flutter emulators --launch Pixel_6`). Volvió a asignarse el mismo
   serial `emulator-5554`, confirmando la identificación. Se abrió la app
   de nuevo (sin tocar su código ni sus datos) y **la sesión de "Mario
   Kempes" volvió a autenticarse sola** (el token quedó persistido en el
   almacenamiento seguro del dispositivo, que sobrevive a un reinicio del
   proceso igual que sobreviviría a que un teléfono real se reiniciara) y
   el feed cargó datos reales de publicaciones. **No se perdió la cuenta ni
   los datos del backend.** Lo que sí es irrecuperable, si lo había: la
   pantalla exacta en la que estuviera navegando, la posición de scroll, o
   texto sin guardar en un formulario — eso vive solo en memoria del
   proceso y no hay forma de reconstruirlo desde aquí.
4. No se volvió a tocar `emulator-5554` después de confirmarlo restaurado y
   funcional.

Se anota en `docs/agent-tasks/032-*.md` (sección de notas) y aquí para que
quede visible a quien esté detrás de esa sesión y al `tech-lead`.

## Archivos tocados

- Modificados: `lib/funcionalidades/autenticacion/pantallas/login_screen.dart`,
  `lib/funcionalidades/autenticacion/pantallas/bienvenida_registro_screen.dart`,
  `docs/agent-tasks/032-rediseno-autenticacion-login-bienvenida.md`,
  `docs/agent-context/repo-snapshot.md`.
- Nuevos: `docs/agent-reports/032-rediseno-autenticacion-login-bienvenida.md`,
  8 capturas en `docs/agent-reports/capturas/032-*.png`.
- No se tocó `backend/**`, `firestore.rules`, ni ningún archivo fuera de
  `autenticacion` (los dos registros son la tarea 033, aparte).
