# Reporte — tarea 033: rediseño visual, registro de trabajador y de empleador

**Fecha:** 2026-09-11
**Agente:** flutter-agent
**Rama:** `feature/rediseno-registros` (sobre `feature/rediseno-autenticacion`, con la 031 y la 032 mergeadas)
**Estado:** hecho

## Qué se hizo

Se migraron los dos formularios de registro a los tokens de la tarea 031
(ADR-0016): `registro_trabajador_screen.dart` (1 042 líneas, 5 pasos) y
`registro_empleador_screen.dart` (920 líneas, 3 pasos) — las dos excepciones
vivas al techo de 300 de ADR-0014 que quedaron pendientes de la tarea 027.

Al aplicar los tokens se tocaba de todas formas casi cada línea de los
métodos `_pasoN()`, así que —siguiendo el criterio de juicio que pedía la
tarea— **se extrajo cada paso a su propio widget**, mismo patrón que usó la
027 B-2b con `trabajos_tab`/`postulantes_screen`. Eso solo no bastó para
bajar de 300 líneas (ver la sección de decisión más abajo): la lógica de
avanzar/validar/guardar se movió además a un archivo `part of`, una segunda
técnica que no hizo falta en la 027 B-2b pero que sí hacía falta aquí.

### Antes / después (líneas)

| Archivo | Antes | Después |
|---|---|---|
| `registro_trabajador_screen.dart` | 1 042 | **231** |
| `registro_trabajador_logica.dart` (nuevo, `part of`) | — | 200 |
| `registro_empleador_screen.dart` | 920 | **200** |
| `registro_empleador_logica.dart` (nuevo, `part of`) | — | 181 |
| 15 widgets nuevos en `pantallas/widgets/registro*/` | — | 33–248 c/u |

Los 19 archivos tocados/creados de esta tarea están todos por debajo de 300
líneas. El máximo es `paso_cuenta_empleador.dart` con 248.

## La decisión de partir-o-no-partir (explícita, como pedía la tarea)

**Se partieron los dos archivos, en dos niveles distintos:**

### 1. Los pasos del formulario → widgets sin estado (SÍ, es un cambio natural)

Cada `_pasoN()` era ya, antes de esta tarea, un método que solo leía
controllers/valores del `State` por clausura y llamaba `setState` a través
de callbacks — exactamente la forma que tenían `trabajos_tab`/
`postulantes_screen` antes de la 027 B-2b. Extraerlos a
`StatelessWidget`s que reciben controllers/valores + `VoidCallback`/
`ValueChanged` como parámetros no cambia una sola regla de negocio: el
`State` sigue siendo dueño de todo el estado y sigue construyendo los
closures que se le pasan a cada widget.

Además, varias piezas estaban **duplicadas byte a byte** entre los dos
registros (`_decoFecha`, la fila de fecha de nacimiento, el selector
"Honduras / Fuera del país", el checkbox de términos y condiciones, y el
patrón `ElevatedButton` con spinner de carga que se repetía 8 veces, una por
paso). Se compartieron en `pantallas/widgets/registro/` (6 widgets) en vez
de duplicar la aplicación de tokens dos veces:

- `titulo_paso_registro.dart` — título "hero" de cada paso.
- `campo_fecha_nacimiento.dart` + `decoracion_campo_fecha.dart`.
- `selector_pais_honduras.dart` (fusiona `_SelectorPaisLocal` y
  `_SelectorPaisLocalTrab`, que eran la misma clase con nombre distinto).
- `terminos_condiciones_checkbox.dart`.
- `boton_continuar_paso.dart`.

Los pasos propios de cada registro quedaron en
`pantallas/widgets/registro_trabajador/` (5 archivos) y
`pantallas/widgets/registro_empleador/` (3 archivos + `TarjetaTipoEmpleador`,
la tarjeta seleccionable "Persona"/"Empresa").

### 2. La lógica de avanzar/validar/guardar → `part of` (NO se movió a los widgets, pero SÍ se separó de físicamente del archivo de la pantalla)

Extraer los pasos por sí solo dejó `registro_trabajador_screen.dart` en
**397** líneas y no bastaba. La causa es exactamente la que anticipaba la
tarea: `_avanzarPaso1/2/4`, `_finalizarRegistro` y `_esMayor18` **dependen
unos de otros** (edad mínima antes de guardar en el paso 2, orden estricto
`registrar` → `actualizarCampos` en el paso 1 del empleador, la rama
persona/empresa que decide si hay paso 3) y llaman a `AuthService`/
`PerfilService` con efectos reales. Convertir eso en widgets sin estado
habría sido un refactor de comportamiento, no de presentación — la tarea lo
prohibía explícitamente, y aquí se respeta.

Pero esa lógica **sí se pudo sacar del archivo físico** sin tocar su
comportamiento, usando el mecanismo de Dart para esto:
`registro_trabajador_logica.dart` / `registro_empleador_logica.dart` son
`part of 'registro_*_screen.dart'` — comparten biblioteca con la pantalla,
así que una `extension _LogicaRegistroXScreen on _RegistroXScreenState`
declarada ahí tiene acceso completo a los campos privados del `State`
(`_p1Form`, `_authService`, `setState`, `context`, `mounted`...) exactamente
igual que si el método estuviera escrito dentro de la clase. No es una clase
nueva, no expone nada público nuevo, y **no cambia ni una regla de negocio**
— es un corte físico de archivo, no arquitectónico.

**Efecto secundario del `part`/`extension` y cómo se resolvió:** el
analizador marca `invalid_use_of_protected_member` en cada llamada a
`setState()` desde dentro de la `extension`, porque no reconoce los métodos
de una extensión como "instance members of subclasses of `State`" aunque
compartan biblioteca. En tiempo de ejecución es exactamente
`_RegistroTrabajadorScreenState` (un `State` de verdad) llamando a su propio
`setState`, así que se suprime con
`// ignore_for_file: invalid_use_of_protected_member` **en esos dos archivos
nada más**, con el razonamiento completo en un comentario al inicio de cada
uno. Se prefirió esto a probar un `mixin` con `on` circular (referenciar la
propia clase concreta en su cláusula `on`), que es un patrón frágil y no
estándar en Dart para este caso.

**Por qué esto no es lo mismo que "ADR-0014 sigue sin excepciones nuevas":**
el archivo de la pantalla SÍ terminó bajo 300 sin ninguna excepción — el
`part` es una herramienta de organización de un único archivo/clase
demasiado grande, exactamente lo que ADR-0014 pide resolver, solo que con
una técnica de Dart que la 027 B-2b no necesitó porque sus pantallas no
tenían tanta lógica de avanzar por paso encadenada.

## Mapeo de tokens (tipografía)

Mismo criterio de consistencia que fijó la tarea 032 para login/bienvenida:
**el renglón "hero" de cada paso usa `AppTipografia.tituloGrande`** (28/w800/
-0.5) — el `_titulo()` de cada paso ("Crea tu cuenta", "Datos Personales",
"Añadir estudios"...) tenía ya `fontSize: 24, fontWeight: w800,
letterSpacing: -0.5`, y `tituloGrande` es 28/w800/-0.5: mismo peso, mismo
tracking, tamaño ligeramente mayor (24→28). Es el mismo rol que login/
bienvenida usan para su renglón principal, y aquí cada paso funciona como la
"pantalla" de facto (junto al indicador de pasos).

Resto de mapeos, todos con el rol cuya descripción en `app_tipografia.dart`
encaja con el uso (no se repite aquí el detalle campo por campo — está en
los propios archivos, con comentario donde el mapeo no es 1:1):

| Uso | Antes | Rol |
|---|---|---|
| Subtítulo bajo el título ("Cuéntanos quién...", "Sube tu CV...") | `fontSize: 14, height: 1.5` suelto | `cuerpo` (15/w500/1.4) |
| Etiquetas de grupo ("Fecha de nacimiento *", "Ubicación", "Datos de la persona de contacto") | `fontSize: 13, w600` suelto | `cuerpoChico.copyWith(fontWeight: w600)` — mismo patrón que 032 usó para "Regístrate"/"Inicia sesión" |
| Checkbox de términos (texto + enlaces) | `fontSize: 13` suelto | `cuerpoChico` (13 exacto) + `.copyWith(fontWeight: w600, color: acento)` en los enlaces |
| Título de `TarjetaTipoEmpleador` | `fontSize: 15, w700` | `subtitulo` (17/w600) — mismo mapeo que 032 usó para `_TarjetaOpcion` |
| Descripción de `TarjetaTipoEmpleador`, hint del CV, "Cursando actualmente" | `fontSize: 11–14` sueltos | `cuerpoChico` o `cuerpo` según longitud del texto |
| "Fuera del país" / "Pronto" del selector de país | `fontSize: 12/w600` y `10/w700` | `etiqueta` (11/w600) — mismo criterio de "más cercano" que 032 |

**Excepciones documentadas, sin token (mismo criterio que 032 dejó para
tamaños de componente):** el separador "/" entre los campos DD/MM/AAAA
(`fontSize: 20`, decorativo, no es texto semántico) se deja literal.

## Espaciado y radios

Escala 4/8/12/16/24/32 (`AppEspaciado.xs..xxl`) y 3 radios
(`AppRadios.campo/tarjeta/chip`). Valores medidos en los dos archivos antes
de tocar nada: `SizedBox(height:...)` en {4,6,8,10,12,14,16,20,24,28,32,40},
`EdgeInsets` en los mismos vecinos, `BorderRadius.circular(...)` en
{10,12,14,16}.

**Regla de redondeo aplicada, documentada aquí porque no hay un único
"vecino más cercano" para varios valores:**

- Los exactos (4,8,12,16,24,32) van directo a xs/sm/md/lg/xl/xxl.
- `10` → `md` (12): más cerca de 12 que de 8.
- `14` → `md` (12), **no** `lg` (16), aunque la distancia es la misma (2 en
  ambos casos): es el valor dominante entre campos de un mismo formulario, y
  el propio docstring de `AppEspaciado.md` lo describe como "separación por
  defecto entre elementos de un formulario o de una tarjeta" — exactamente
  este uso.
- `20` → `lg` (16): distancia empatada con `xl` (24); se redondeó hacia
  abajo para no ensanchar más de lo necesario un hueco que ya funcionaba
  bien visualmente (mismo criterio que 032 usó con `EdgeInsets.all(20) →
  lg`).
- `28` → `xl` (24): mismo razonamiento de redondear hacia abajo en un
  empate.
- `40` → `xxl` (32): mismo mapeo que ya fijó la 032.
- Radios: `10` → `campo` (12, "más cercano", mismo criterio que 032 usó para
  la insignia de icono de login). `14` (tarjeta de tipo empleador) → `tarjeta`
  (16): es literalmente una tarjeta seleccionable, encaja con la descripción
  del rol más que con `campo`.

## Bug de layout encontrado y corregido de paso

Al escribir el widget compartido `SelectorPaisHonduras` (que unifica
`_SelectorPaisLocal`/`_SelectorPaisLocalTrab`) apareció un
`RenderFlex overflowed` real al generar las capturas: los `Text` de
"Honduras" y "Fuera del país" no tenían ningún `Flexible`/`Expanded` en su
`Row` interior, así que cualquier combinación de ancho de pantalla estrecho
+ métrica de fuente que ensanche el texto un poco (division de idioma,
tamaño de letra del sistema más grande, o —como pasó aquí— el sustituto de
fuente que usa `flutter test` sin fuentes cargadas) los desbordaba en
silencio (Flutter solo pinta la franja de rayas amarillas/negras; no
revienta la app). **Esto ya existía en el código original** (ninguno de los
dos registros lo tenía envuelto en `Flexible`) y nunca se había detectado
porque ningún test llega al paso 2 de ninguno de los dos registros
(`registro_empleador_screen_test.dart` solo cubre el paso 1). Se corrigió
envolviendo "Honduras" y "Fuera del país" en `Flexible(overflow:
TextOverflow.ellipsis)` — cero cambio visual en el caso normal, y ya no
revienta en pantallas angostas o con texto más grande. No es parte del
alcance formal de "aplicar tokens", pero se corrige de paso por estar
tocando exactamente esas líneas y ser un bug real, no cosmético.

## Limpieza de paso (archivos ya tocados)

`flutter analyze` bajó de **33 a 19 issues** (0 errores en ambos casos). Lo
que se limpió, todo en los dos archivos de pantalla que esta tarea reescribe
por completo:

- `registro_trabajador_screen.dart`: el campo `_contrasenaValor` (se
  escribía en un `alTerminar` y nunca se leía en ningún sitio —
  `unused_field`, señalado explícitamente como pendiente en el reporte de la
  032) se eliminó junto con el `alTerminar` que lo escribía: no tenía efecto
  observable. 2 `curly_braces_in_flow_control_structures` en `_retroceder`.
  2 `unnecessary_underscores` en el `ValueListenableBuilder` de la
  contraseña. 3 `withOpacity` → `withValues(alpha:)`.
- `registro_empleador_screen.dart`: mismos 2 `curly_braces` en `_retroceder`,
  mismos 2 `unnecessary_underscores`, mismos 2 `withOpacity`.

No se tocó el `unused_element_parameter` de `bienvenida_registro_screen.dart`
(archivo no tocado por esta tarea, ya señalado como preexistente por la 032).

## Qué NO se tocó (fuera de alcance, explícito en la instrucción de la tarea)

- Ningún campo del formulario, ningún rol elegible, ningún orden de paso.
- Ninguna validación (`ReglasCuenta`, edad mínima, formatos de DNI/teléfono,
  regex de correo/sitio web).
- Contratos de `PerfilService`/`AuthService`: mismos métodos, mismos
  parámetros, mismo orden de llamadas.
- Colores: fuera de alcance de esta tarea (igual que en la 032); no se migró
  ningún color a un rol semántico nuevo.
- La subida de archivos del paso 3 del trabajador sigue siendo solo UI
  ("disponible en la próxima versión") — no es parte de esta tarea.

## Verificación

- `flutter analyze`: **19 issues, 0 errores** (baseline antes de esta tarea:
  33). Ningún issue nuevo introducido; 14 preexistentes limpiados (ver
  arriba).
- `flutter test`: **253/253 pasan**, mismo total que antes de la tarea (no
  se tocó comportamiento). `registro_empleador_screen_test.dart` (los únicos
  4 tests que montan una de estas dos pantallas) sigue en verde sin tocar
  sus aserciones — confirma que el paso 1 del empleador (creación de cuenta
  + guardado de campos de empresa, en ese orden, con y sin error) se sigue
  comportando igual tras la extracción a `PasoCuentaEmpleador` +
  `registro_empleador_logica.dart`.

## Verificación visual — por qué widget test y no el emulador

Antes de tocar nada se corrió, como pide la tarea:

```
adb devices
adb shell pidof com.trabajito.trabajito
```

Resultado: **un único emulador disponible** (`emulator-5554`), con
`com.trabajito.trabajito` corriendo de verdad (`pidof` devolvió un PID) y
`dumpsys activity activities` mostrando su `MainActivity` como actividad
resumida y visible — es decir, alguien tiene la app real abierta y en
primer plano en este momento, igual que el escenario que ya describió el
reporte de la 032.

Instalar el build de esta tarea encima habría reemplazado esa sesión (el
mismo incidente de la 032, primer punto: "nunca instalar sobre una sesión
que no arrancaste tú"). Levantar un segundo emulador para no tocar el
primero es exactamente lo que la instrucción de esta tarea pide evitar
—fue la causa más probable de que la 032 tumbara el emulador ajeno por
contención de recursos—. **No se hizo ninguna de las dos cosas**: no se
tocó `emulator-5554` en ningún momento de esta tarea, y no se levantó ningún
otro emulador.

En su lugar, y amparado explícitamente por el criterio de aceptación ("se
probaron manualmente **o con test de widget** ... si es más práctico y lo
justifica"), se escribió `test/manual/generar_capturas_registro.dart`:

- Pumpa cada uno de los 8 widgets de paso (ya extraídos, sin estado propio)
  con datos de ejemplo válidos, dentro de un `MaterialApp` con
  `AppTema.temaClaro()`/`AppTema.temaOscuro()` y `themeMode` fijo.
- Carga la fuente real (`assets/fonts/Sora.ttf` vía `FontLoader`) antes de
  renderizar — sin esto, `flutter test` sustituye cualquier texto por
  bloques opacos y las capturas no servirían para juzgar la tipografía.
- Captura cada combinación con `RenderRepaintBoundary.toImage()` y la guarda
  como PNG real en `docs/agent-reports/capturas/033-<paso>-<claro|oscuro>.png`
  (16 archivos: 5 trabajador + 3 empleador, × 2 temas).
- **No termina en `_test.dart`** a propósito: `flutter test` (sin
  argumentos) descubre `test/**_test.dart`, así que este generador **no
  corre en la suite normal** (confirmado: 253/253 antes y después de
  crearlo). Se invoca a mano con
  `flutter test test/manual/generar_capturas_registro.dart`.
- No hace ningún `expect()`: no es un test de regresión ni un golden test de
  comparación, es una herramienta de generación de capturas — si se quiere
  volver a generarlas tras un cambio futuro, se vuelve a correr igual.

**Limitación conocida y documentada de este método:** el texto de los
botones (`ElevatedButton`/`OutlinedButton`) sale como bloques opacos en las
capturas, no como texto legible. Causa: `AppTema.elevatedButtonTheme`/
`outlinedButtonTheme` fijan `textStyle: TextStyle(fontSize: 16, fontWeight:
w600)` **sin** `fontFamily: 'Sora'` explícito (a diferencia del resto del
`TextTheme`, que sí lo hereda vía `.apply(fontFamily: 'Sora')`). En un
dispositivo real esto no se nota (cae al font por defecto de la plataforma,
que sí está instalado), pero en el entorno de test sin ese fallback
disponible se ve como bloque. **Es un comportamiento preexistente de
`AppTema`, no introducido por esta tarea** (no se tocó `app_tema.dart`) y
está fuera de su alcance corregirlo — se anota aquí para que quien revise
las capturas no lo confunda con un defecto de los tokens de tipografía de
esta tarea.

Las 16 capturas se revisaron una por una: los 5 pasos del trabajador y los 3
del empleador se ven correctos en ambos temas — jerarquía de título/
subtítulo, campos, checkbox de términos, tarjeta seleccionable "Persona/
Empresa", indicador de fuerza de contraseña, selector de país (ya sin el
overflow) y el botón primario invirtiendo correctamente a dorado con texto
oscuro en modo oscuro (el arreglo de contraste de la tarea 031, heredado sin
tocarlo).

## Archivos tocados

**Reescritos por completo:**
- `lib/funcionalidades/autenticacion/pantallas/registro_trabajador_screen.dart`
- `lib/funcionalidades/autenticacion/pantallas/registro_empleador_screen.dart`

**Nuevos — lógica (`part of`):**
- `lib/funcionalidades/autenticacion/pantallas/registro_trabajador_logica.dart`
- `lib/funcionalidades/autenticacion/pantallas/registro_empleador_logica.dart`

**Nuevos — widgets compartidos entre los dos registros:**
- `lib/funcionalidades/autenticacion/pantallas/widgets/registro/titulo_paso_registro.dart`
- `.../widgets/registro/campo_fecha_nacimiento.dart`
- `.../widgets/registro/decoracion_campo_fecha.dart`
- `.../widgets/registro/selector_pais_honduras.dart`
- `.../widgets/registro/terminos_condiciones_checkbox.dart`
- `.../widgets/registro/boton_continuar_paso.dart`

**Nuevos — pasos del registro de trabajador:**
- `.../widgets/registro_trabajador/paso_cuenta_trabajador.dart`
- `.../widgets/registro_trabajador/paso_datos_personales_trabajador.dart`
- `.../widgets/registro_trabajador/paso_cv_trabajador.dart`
- `.../widgets/registro_trabajador/paso_experiencia_trabajador.dart`
- `.../widgets/registro_trabajador/paso_estudios_trabajador.dart`

**Nuevos — pasos del registro de empleador:**
- `.../widgets/registro_empleador/tarjeta_tipo_empleador.dart`
- `.../widgets/registro_empleador/paso_cuenta_empleador.dart`
- `.../widgets/registro_empleador/paso_contacto_empleador.dart`
- `.../widgets/registro_empleador/paso_info_empresa_empleador.dart`

**Nuevo — herramienta de verificación (no se ejecuta en la suite normal):**
- `test/manual/generar_capturas_registro.dart`

**Nuevas — 16 capturas:**
- `docs/agent-reports/capturas/033-{trabajador,empleador}-*-{claro,oscuro}.png`

**Documentación:**
- `docs/agent-tasks/033-rediseno-autenticacion-registros.md` (estado → hecho)
- `docs/agent-context/repo-snapshot.md`
- `docs/agent-reports/033-rediseno-autenticacion-registros.md` (este archivo)

No se tocó `backend/**`, `firestore.rules`, `PerfilService`/`AuthService`,
ni ningún archivo fuera de `autenticacion`/`test/manual`.
