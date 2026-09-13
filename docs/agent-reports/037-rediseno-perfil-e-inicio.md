# Reporte — tarea 037: rediseño visual, perfil e inicio (ADR-0016)

**Fecha:** 2026-09-12
**Agente:** flutter-agent
**Rama:** `feature/hotfixes-qa-039` (working tree compartido con 036/039/040-042 y las
tareas de iconografía 043-048, ninguna de ellas mergeada todavía)
**Estado:** hecho

## Qué se hizo

Se aplicaron los tokens de la tarea 031 (ADR-0016: `AppTipografia`,
`AppEspaciado`, `AppRadios`) a los 14 archivos que pedía la tarea:

- `lib/funcionalidades/perfil/pantallas/perfil_tab.dart`
- `lib/funcionalidades/perfil/pantallas/editar_perfil_screen.dart`
- `lib/funcionalidades/perfil/pantallas/configuracion_screen.dart`
- `lib/funcionalidades/perfil/pantallas/detalle_trabajador_screen.dart`
- `lib/funcionalidades/perfil/pantallas/trabajadores_tab.dart`
- `lib/funcionalidades/perfil/pantallas/ranking_tab.dart`
- `lib/funcionalidades/inicio/pantallas/inicio_screen.dart`
- `lib/funcionalidades/perfil/pantallas/widgets/accesos_rapidos_perfil.dart`
- `lib/funcionalidades/perfil/pantallas/widgets/aviso_perfil_no_disponible.dart`
- `lib/funcionalidades/perfil/pantallas/widgets/avisos_perfil.dart`
- `lib/funcionalidades/perfil/pantallas/widgets/cabecera_perfil.dart`
- `lib/funcionalidades/perfil/pantallas/widgets/formulario_editar_perfil.dart`
- `lib/funcionalidades/perfil/pantallas/widgets/info_personal_perfil.dart`
- `lib/funcionalidades/perfil/pantallas/widgets/piezas_perfil.dart`

Con esta tarea se cierra la cobertura de tokens de tipografía/espaciado/
radios de `lib/funcionalidades/**` completa (quedan fuera, a propósito, los
4 archivos de `lib/screens/` que siguen en Firestore — fase 2b-2).

**No se tocó**: `lib/funcionalidades/trabajos/**`, `lib/funcionalidades/postulaciones/**`,
`backend/**`, ni ninguna regla de negocio, navegación o lógica de `ADR-0013`/
`ReglasCuenta`/`cvCargado`. El vocabulario de movimiento de ADR-0015 no se
tocó (no se animó el cambio de pestaña del `BottomNav`, en su lista cerrada
de "dónde NO").

### Antes / después (líneas)

| Archivo | Antes | Después |
|---|---|---|
| `perfil_tab.dart` | 197 | 206 |
| `editar_perfil_screen.dart` | 211 | 216 |
| `configuracion_screen.dart` | 245 | 262 |
| `detalle_trabajador_screen.dart` | 163 | 156 |
| `trabajadores_tab.dart` | 268 | 274 |
| `ranking_tab.dart` | 283 | 288 |
| `inicio_screen.dart` | 218 | 227 |
| `widgets/accesos_rapidos_perfil.dart` | 38 | 39 |
| `widgets/aviso_perfil_no_disponible.dart` | 52 | 57 |
| `widgets/avisos_perfil.dart` | 162 | 168 |
| `widgets/cabecera_perfil.dart` | 96 | 99 |
| `widgets/formulario_editar_perfil.dart` | 164 | 164 |
| `widgets/info_personal_perfil.dart` | 113 | 114 |
| `widgets/piezas_perfil.dart` | 92 | 95 |

Los 14 quedan por debajo del techo de 300 de ADR-0014. `ranking_tab.dart`
(288) y `configuracion_screen.dart` (262) son los más cercanos — ninguno pasó
de 297 (el máximo que ya tenía `mis_postulaciones_screen.dart` en la 036),
así que no hizo falta partir nada.

## `cabecera_perfil.dart` — la advertencia de la tarea, respetada

Este archivo ya traía, antes de que empezara esta tarea, el arreglo de la
**039** (banding del degradado, 3 paradas en vez de 2, con
`AppColores.azulClaro` de por medio). **No se tocó ese color en ningún
momento**: se le aplicaron los mismos tokens que a los demás (`AppRadios.tarjeta`
para el borde, `tt.tituloGrande`/`tt.titulo`/`tt.etiqueta` para los tres
textos, `AppEspaciado` para los huecos), dejando el `LinearGradient` de 3
paradas exactamente como estaba. Se anotó en el docstring del archivo
("**No tocado por la tarea 037**... se conserva tal cual") para que quien lo
lea después no tenga que adivinarlo comparando diffs.

Verificado dos veces: por lectura del diff final (el bloque `gradient:` es
idéntico carácter a carácter al que traía el archivo al empezar) y por
captura real (`037-inicio-4-perfil-*` y `037-perfil-avisos-*`): el degradado
se ve suave en las cuatro combinaciones tema/momento, sin el banding que
motivó la 039.

## El aviso de "datos sin confirmar" y la tarjeta de "CV sin cargar" — contraste verificado, no asumido

Es el criterio de aceptación explícito de la tarea. Lo que se comprobó:

1. **Ningún color cambió.** ADR-0016/tarea 031 define tokens de tipografía,
   espaciado y radios; el cambio de paleta que sí trajo la 031 (el arreglo
   de contraste del botón dorado) ya estaba hecho antes de esta tarea y no
   tocaba `AppColores.advertencia`. `AvisoSinConexionPerfil` sigue con su
   fondo `AppColores.advertencia.withValues(alpha: 0.14)` y borde
   `withValues(alpha: 0.55)` (dorado), y `AvisoCvSinCargar` sigue con
   `colorSuperficie(context)`/`colorBorde(context)` (superficie neutra) más
   su icono `cloud_off_rounded` — exactamente los mismos colores de antes de
   esta tarea, solo con `TextStyle`/`EdgeInsets`/`BorderRadius` literales
   sustituidos por los tokens equivalentes.
2. **Se generó una captura real del escenario con los dos avisos a la vez**
   (perfil con `datosSinConfirmar: true` y `cvCargado: false`, el estado que
   describe `perfil_tab_test.dart`), en claro y oscuro, antes y después de
   esta tarea:
   `docs/agent-reports/capturas/037-perfil-avisos-{antes,despues}-{claro,oscuro}.png`.
   Revisadas una por una: el aviso superior se ve con fondo dorado tenue y
   borde dorado, netamente distinto del resto de la pantalla (cabecera azul,
   tarjetas blancas/oscuras neutras); la tarjeta de CV se ve con su icono de
   nube tachada y el texto "No pudimos cargar tu currículum" en negrita,
   distinguible de las tarjetas de información normales por el icono y el
   texto, igual que antes de esta tarea. Comparando antes/después del mismo
   tema: el layout es visualmente idéntico salvo el interlineado ligeramente
   distinto de `AppTipografia` (mismo efecto ya documentado por 032-036).
3. Los textos del aviso conservan las mismas constantes de `AppTextos`
   (`datosDeTuUltimaVisita`, `datosSinConfirmarDetalle`, `cvSinCargar`,
   `cvSinCargarDetalle`) — no se tocó ninguna.

**Conclusión: los dos avisos siguen siendo visualmente distinguibles como
advertencia/aviso honesto tras el cambio de tokens.** No se corrigió ningún
defecto de contraste porque no se introdujo ninguno: es la misma paleta de
antes, con tipografía/espaciado sistematizados encima.

## Mapeo de tokens

Mismo criterio que 032-036: cada `TextStyle(fontSize:, fontWeight:)` suelto
se sustituyó por el rol de `AppTipografia` cuyo tamaño coincide exacto o es
el más cercano, con `.copyWith(color:, fontWeight:)` cuando hacía falta
preservar el color por-tema o un peso que el rol no fija.

| Uso | Tamaño original | Rol aplicado |
|---|---|---|
| Título de `AppBar` (Perfil, Editar perfil, Configuración, título dinámico de `InicioScreen`) | sin tamaño explícito, w800/-0.5 heredado | `titulo` (22/w700/-0.3) — mismo tratamiento que trabajos/postulaciones |
| Avatar grande de cabecera (`cabecera_perfil`, `detalle_trabajador_screen`, `formulario_editar_perfil`) | 26-30/w800 | `tituloGrande` (28/w800, el más cercano/exacto) |
| Nombre en cabecera con gradiente (`cabecera_perfil`, `detalle_trabajador_screen`) | 20/w800 | `titulo` (22, distancia 2) — **no** `numero` (20, exacto): mismo criterio semántico que 035/036 (`numero` es "montos y precios", no nombres) |
| Nombre de tarjeta/avatar (16-18px, `trabajadores_tab`, `ranking_tab`) | 15-18/w700-800 | `subtitulo` (17) o `cuerpo` (15), el más cercano por tamaño, con `fontWeight` preservado vía `copyWith` |
| Título/mensaje de los 5 diálogos de confirmación (`¿Cerrar sesión?`, `¿Dar de baja tu cuenta?`, `Cambiar contraseña`) | sin tamaño explícito, w700 | `subtitulo.copyWith(color: colorTextoFuerte)` / `cuerpo.copyWith(color: colorTextoSuave)` — mismo patrón que los 5 diálogos extraídos en la 035 |
| Filas de tarjeta (`piezas_perfil.FilaPerfil`, `detalle_trabajador_screen._fila`) | 13/w500-700 | `cuerpoChico` (13, exacto) |
| Secciones ("Información", "Cuenta", "Apariencia") | 13/w800/letterSpacing 0.3 | `cuerpoChico.copyWith(fontWeight: w800, letterSpacing: 0.3)` |
| Metadatos pequeños (ubicación, especialidad, "Postuló hace...", footer de versión) | 11-12 | `etiqueta` (11) |
| Badge de rol (`EMPLEADOR`/`TRABAJADOR`) | 11/w800 | `etiqueta.copyWith(fontWeight: w800)` |
| Botón "Publicar" del FAB de `InicioScreen` | sin tamaño, w700 | `cuerpo.copyWith(fontWeight: w700)` — **mismo patrón exacto** ya usado en `mis_publicaciones_screen.dart` (034) |

### Espaciado y radios

Mismas reglas de redondeo que 034-036 para los valores que no caen exacto en
la escala 4/8/12/16/24/32 (`AppEspaciado`) ni en 12/16/20 (`AppRadios`):

- `6/8→sm`, `10/12→md`, `16/18→lg`, `20/24→xl`, `32→xxl`.
- **El 14 se dejó literal en 7 sitios** (`avisos_perfil.dart` ×1,
  `aviso_perfil_no_disponible.dart` ×1, `piezas_perfil.dart` ×1,
  `trabajadores_tab.dart` ×2, `ranking_tab.dart` ×2): mismo caso suelto de
  redondeo entre `md`(12) y `lg`(16) que ya documentaron 031/035, anotado con
  un comentario en cada sitio.
- **El 90 de reserva bajo el `BottomNavigationBar`** (`perfil_tab.dart`,
  `ranking_tab.dart`, `trabajadores_tab.dart`) **se dejó literal a
  propósito**: no es un hueco entre dos elementos visuales, es espacio
  reservado para que la lista no quede tapada por el `BottomNavigationBar`,
  y no cae en el rango que midió la auditoría de la 031 (valores de 2 a 40).
- El 40 de `configuracion_screen.dart` (el espacio final antes de cerrar la
  pantalla) está por encima del tope de la escala (`xxl`=32): se mapeó a
  `xxl`, mismo criterio que usó la 035 para un caso análogo (28 sin rol
  exacto por arriba).
- `cabecera_perfil.dart`: `BorderRadius.circular(18)` → `AppRadios.tarjeta`
  (16, -2px) — empate de distancia entre `campo`(12) y `tarjeta`(16)
  resuelto por semántica (es un contenedor de tarjeta, no un campo ni un
  chip), mismo criterio que 034-036.
- El resto de radios exactos (12→campo, 16→tarjeta, 20→chip) se mapearon
  1:1, cero cambio visual.

## Limpieza de paso (CLAUDE.md: archivo tocado con warning preexistente)

Al tocar `configuracion_screen.dart` a fondo, se limpiaron 2 issues que ya
tenía y que no eran parte del alcance de esta tarea:
`unnecessary_underscores` (`(_, oscuro, __)` → `(_, oscuro, _)`) y
`activeColor` deprecado en `SwitchListTile` → `activeThumbColor`. **No** se
tocó el tercer issue preexistente de ese archivo
(`use_build_context_synchronously` en el `showDialog` del loader de
`_eliminarCuenta`): corregirlo de verdad implica reestructurar el cierre del
diálogo de carga, un cambio de comportamiento fuera del alcance de "aplicar
tokens visuales" — se deja anotado para quien lo revise.

También se cambiaron 5 `withOpacity` → `withValues(alpha:)` en
`detalle_trabajador_screen.dart` (1), `ranking_tab.dart` (3) y
`trabajadores_tab.dart` (1): eran parte de los mismos `Container`/
`CircleAvatar` que ya se estaban tokenizando línea por línea.

## Verificación

- `flutter analyze`: **12 issues, 0 errores** — bajó de 14 (línea base antes
  de esta tarea) gracias a la limpieza de paso; ninguno nuevo, ninguno en
  los 14 archivos del alcance salvo el `use_build_context_synchronously`
  preexistente y explícitamente no tocado (ver arriba).
- `flutter test`: **268/268 pasan**. No hizo falta modificar ningún test
  existente: `perfil_tab_test.dart`, `editar_perfil_screen_test.dart`,
  `formulario_editar_perfil_test.dart` e `info_personal_perfil_test.dart`
  afirman sobre `find.text(...)`/`find.byIcon(...)`/callbacks/peticiones
  HTTP, nunca sobre `fontSize`/`EdgeInsets`/`BorderRadius` concretos.
- Verificado de punta a punta dos veces: con los 14 archivos en su estado
  "después" (tokens aplicados) y, temporalmente, en su estado "antes"
  (`git stash` para 13 de los 14; reconstrucción manual del contenido exacto
  para `cabecera_perfil.dart`, ver más abajo) — mismos resultados en ambos
  casos (0 errores de análisis propios de esta tarea; 268/268 antes de que
  esta tarea tocara nada, 268/268 después).

## Verificación visual — capturas reales, sin tocar el emulador

Mismo criterio que 032-036 (evitar pisar una sesión de `flutter run` ajena
— y en este caso había motivo real de sobra: `git status` al arrancar esta
tarea mostraba trabajo en curso de las tareas 036/039/040/041/042, y durante
la ejecución de esta tarea aparecieron además los archivos de las tareas
043-048 de iconografía en `docs/agent-tasks/`, señal de que había más de un
agente activo en el mismo árbol al mismo tiempo).

Se escribió `test/manual/generar_capturas_perfil_inicio.dart`:

- Monta **`InicioScreen` real** — no una recomposición manual — con
  `AuthService`/`PerfilService`/`PublicacionService`/`PostulacionService`
  reales inyectados vía `proveedoresDeLaApp()`, apuntando a un `MockClient`
  en memoria (`/api/trabajos` con página vacía, `/api/usuarios/ranking` con
  dos trabajadores de muestra, el resto `[]`), y navega **con toques reales**
  sobre los íconos del `BottomNavigationBar` (`find.descendant` +
  `tester.tap`) para capturar las 5 pestañas en el orden real del usuario.
- 5 pestañas (`Trabajos`/`Trabajadores`/`Chats`/`Ranking`/`Perfil`) × 2 temas
  × 2 momentos (antes/después) = 20 capturas, más 4 capturas dedicadas del
  escenario "los dos avisos a la vez" en `PerfilTab` (claro/oscuro ×
  antes/después) = **24 capturas** en total.
- La pestaña **"Chats" se capturó igual** (es una de las 5 del `BottomNav`,
  y la tarea pide las 5), pero muestra el `CircularProgressIndicator` de
  carga: su `StreamBuilder` de Firestore no está mockeado (fase 2b-2, fuera
  de alcance de ADR-0016) y su error de canal (`PlatformException:
  channel-error`) se descarta con `runZonedGuarded`, mismo criterio de
  tolerancia que ya usa `test/pantalla_inicial_test.dart` para el mismo
  problema.
- **"Antes"**: para 13 de los 14 archivos, `git stash push -- <archivo>`
  (revierte exactamente al estado previo a esta tarea, porque ninguna otra
  tarea pendiente los tocaba). **Para `cabecera_perfil.dart` no se pudo usar
  `git stash` sin más**: el archivo ya traía sin commitear el arreglo de
  gradiente de la 039, y un `stash` normal habría revertido también ese
  arreglo (dejando un "antes" que no es "antes de la 037" sino "antes de la
  039 y la 037" a la vez). Se reconstruyó a mano el contenido exacto que
  tenía el archivo al empezar esta tarea (capturado al leerlo antes de
  tocarlo) y se escribió temporalmente, se corrió el generador con
  `--dart-define=SUFIJO=antes`, y se restauró el archivo "después" desde una
  copia de seguridad (`cp` a un temporal antes de sobrescribir). Se
  reverificó `flutter analyze`/`flutter test` tras la restauración: mismos
  268/268 y 12 issues.
- Archivos: `docs/agent-reports/capturas/037-inicio-{0-trabajos,1-trabajadores,2-chats,3-ranking,4-perfil}-{antes,despues}-{claro,oscuro}.png`
  y `037-perfil-avisos-{antes,despues}-{claro,oscuro}.png`.

**Revisadas una por una:** las 5 pestañas se ven correctamente en ambos
temas; el degradado de 3 paradas de `cabecera_perfil.dart`/`ranking_tab.dart`
se ve suave (sin banding) en las cuatro combinaciones; el `BottomNavigationBar`
resalta la pestaña activa en dorado sin ninguna animación nueva (ADR-0015
intacto); comparando antes/después del mismo escenario, el layout es
visualmente casi idéntico — el cambio perceptible es el interlineado
ligeramente distinto de `AppTipografia`, igual que documentaron 032-036.
Limitación conocida y ya documentada por tareas anteriores: el texto de
`ElevatedButton`/`OutlinedButton`/algunos glifos sale como recuadro
("tofu") en estas capturas porque el entorno de `flutter test` headless no
rasteriza la fuente real sin un display; no es un defecto de esta tarea ni
afecta lo que hay que verificar (estructura, color, contraste entre
elementos), y no es visible en un dispositivo real.

## Coordinación con otras tareas

- `docs/agent-tasks/047-iconografia-perfil-e-inicio.md` ya existe (creada
  por el `tech-lead` mientras esta tarea estaba en curso), en estado
  `bloqueada`, y depende explícitamente de que la 037 esté `hecho`/mergeada
  antes de tocar estos mismos 12 archivos (mapa `Icons.*` → `LucideIcons.*`,
  ADR-0017). No se tocó nada de esa tarea ni de su rama.
- No se tocó `backend/**` (tareas 040-042, en curso en paralelo) ni
  `lib/funcionalidades/trabajos/**`/`postulaciones/**` (fuera de alcance
  explícito de esta tarea).
- Durante la ejecución aparecieron en el árbol compartido archivos de otras
  tareas (`lib/compartido/widgets/logo_trabajito.dart`,
  `lib/funcionalidades/trabajos/pantallas/widgets/selector_tarifa.dart`,
  `docs/agent-tasks/043-048-*.md`, etc.) — ninguno se tocó; el `git stash`
  usado para las capturas "antes" se limitó explícitamente a los 13 archivos
  de esta tarea (con `git stash push -- <lista de archivos>`, nunca `git
  stash` a secas) para no arrastrar cambios ajenos.

## Archivos tocados

**Modificados (14, alcance de la tarea):**
- `lib/funcionalidades/inicio/pantallas/inicio_screen.dart` (218 → 227)
- `lib/funcionalidades/perfil/pantallas/configuracion_screen.dart` (245 → 262)
- `lib/funcionalidades/perfil/pantallas/detalle_trabajador_screen.dart` (163 → 156)
- `lib/funcionalidades/perfil/pantallas/editar_perfil_screen.dart` (211 → 216)
- `lib/funcionalidades/perfil/pantallas/perfil_tab.dart` (197 → 206)
- `lib/funcionalidades/perfil/pantallas/ranking_tab.dart` (283 → 288)
- `lib/funcionalidades/perfil/pantallas/trabajadores_tab.dart` (268 → 274)
- `lib/funcionalidades/perfil/pantallas/widgets/accesos_rapidos_perfil.dart` (38 → 39)
- `lib/funcionalidades/perfil/pantallas/widgets/aviso_perfil_no_disponible.dart` (52 → 57)
- `lib/funcionalidades/perfil/pantallas/widgets/avisos_perfil.dart` (162 → 168)
- `lib/funcionalidades/perfil/pantallas/widgets/cabecera_perfil.dart` (96 → 99)
- `lib/funcionalidades/perfil/pantallas/widgets/formulario_editar_perfil.dart` (164 → 164)
- `lib/funcionalidades/perfil/pantallas/widgets/info_personal_perfil.dart` (113 → 114)
- `lib/funcionalidades/perfil/pantallas/widgets/piezas_perfil.dart` (92 → 95)

**Nuevo — herramienta de verificación (no se ejecuta en la suite normal):**
- `test/manual/generar_capturas_perfil_inicio.dart`

**Nuevas — 24 capturas:**
- `docs/agent-reports/capturas/037-inicio-{0-trabajos,1-trabajadores,2-chats,3-ranking,4-perfil}-{antes,despues}-{claro,oscuro}.png`
- `docs/agent-reports/capturas/037-perfil-avisos-{antes,despues}-{claro,oscuro}.png`

**Documentación:**
- `docs/agent-tasks/037-rediseno-perfil-e-inicio.md` (estado → hecho,
  checkboxes, notas)
- `docs/agent-context/repo-snapshot.md`
- `docs/agent-reports/037-rediseno-perfil-e-inicio.md` (este archivo)

No se tocó `backend/**`, `firestore.rules`, ni ningún archivo fuera del
alcance declarado de esta tarea. No se hizo commit: los cambios quedan en el
working tree para revisión del usuario.
