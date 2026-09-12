# Reporte — tarea 034: rediseño visual, trabajos (feed, mis publicaciones, publicar/editar)

**Fecha:** 2026-09-11
**Agente:** flutter-agent
**Rama:** `feature/rediseno-trabajos` (sobre `feature/rediseno-registros`, con la 031/032/033 mergeadas)
**Estado:** hecho

## Qué se hizo

Se migraron los 14 archivos de `lib/funcionalidades/trabajos/` listados en la
tarea a los tokens de la 031 (ADR-0016): `trabajos_tab.dart`,
`mis_publicaciones_screen.dart`, `publicar_trabajo_screen.dart`,
`editar_trabajo_screen.dart`, y en `pantallas/widgets/`:
`tarjeta_trabajo.dart`, `tarjeta_mi_publicacion.dart`,
`barra_busqueda_trabajos.dart`, `hoja_filtros_trabajos.dart`,
`toggle_feed_trabajos.dart`, `encabezado_feed.dart`, `estados_feed.dart`,
`estados_mis_publicaciones.dart`, `fila_feed.dart` (sin cambios: no tenía
ningún literal de estilo) y `entrada_escalonada.dart` (sin cambios: su único
"8" es un desplazamiento de animación de ADR-0015, no espaciado — se deja
intacto). No se tocó `detalle_trabajo_screen.dart` (tarea 035, aparte).

### Antes / después (líneas)

| Archivo | Antes | Después |
|---|---|---|
| `trabajos_tab.dart` | 297 | 299 |
| `mis_publicaciones_screen.dart` | 217 | 218 |
| `publicar_trabajo_screen.dart` | 263 | 266 |
| `editar_trabajo_screen.dart` | 205 | 207 |
| `tarjeta_trabajo.dart` | 175 | 163 |
| `tarjeta_mi_publicacion.dart` | 163 | 152 |
| `barra_busqueda_trabajos.dart` | 145 | 148 |
| `hoja_filtros_trabajos.dart` | 89 | 94 |
| `toggle_feed_trabajos.dart` | 76 | 78 |
| `encabezado_feed.dart` | 74 | 71 |
| `estados_feed.dart` | 113 | 117 |
| `estados_mis_publicaciones.dart` | 74 | 81 |

Los 12 archivos con cambios quedan todos por debajo del techo de 300 de
ADR-0014. `trabajos_tab.dart` (299) es el más cerca — ya estaba a 3 líneas
del techo antes de esta tarea (297); se mantuvo el margen recortando
comentarios en vez de dejarlo subir más. Dos archivos (`tarjeta_trabajo.dart`,
`tarjeta_mi_publicacion.dart`, `encabezado_feed.dart`) **bajaron** de
líneas: usar `Theme.of(context).textTheme.<rol>` en vez de un `TextStyle(...)`
multilínea es, en varios casos, más corto que el literal que reemplaza.

## Mapeo de tokens

### Tipografía

Criterio general: cada `TextStyle(fontSize:, fontWeight:)` (o con solo uno de
los dos) se sustituyó por el rol de `AppTipografia` cuyo tamaño coincide
exacto o es el más cercano, usando `.copyWith(color:, fontWeight:)` cuando
hacía falta preservar el color por-tema o un peso que la propia auditoría de
ADR-0016 no fijó como parte del rol (mismo criterio que 032/033).

| Uso | Antes | Rol aplicado |
|---|---|---|
| Título de AppBar (4 pantallas: "Mis publicaciones", "Publicar trabajo", "Editar trabajo") | `fontWeight: w800, letterSpacing: -0.5` (fontSize heredado, 22) | `titulo` (22/w700/-0.3) — es literalmente "título de pantalla", el uso documentado del rol |
| **Precio/presupuesto** (`tarjeta_trabajo.dart` fontSize 15/w800, `tarjeta_mi_publicacion.dart` fontSize 14/w800) | — | **`numero`** (20/w700/tabular) — ver sección de contraste abajo, es el único caso de toda la funcionalidad donde el nombre del rol coincide literalmente ("montos y precios") |
| Título de tarjeta (`p.titulo`, ambas tarjetas, fontSize 16/w800/-0.3) | — | `subtitulo` (17/w600) — "cabecera de tarjeta", el uso documentado |
| Nombre de autor + inicial del avatar (`tarjeta_trabajo.dart`, fontSize 14/w700) | — | `cuerpoChico.copyWith(fontWeight: w700)` |
| Descripción de tarjeta (fontSize 13, ambas tarjetas) | — | `cuerpoChico` (13 exacto) |
| Metadatos pequeños (fecha relativa, ubicación, badge de estado, chips de categoría/plazo — fontSize 11/12) | — | `etiqueta` (11, el más cercano, mismo criterio que 032/033 para fontSize 12) |
| "Plazo de contratación" (publicar/editar, fontSize 13/w600) | — | `cuerpoChico.copyWith(fontWeight: w600)` — mismo mapeo exacto que usó la 033 para "Etiquetas de grupo" |
| Descripción introductoria del formulario (fontSize 14/height 1.5) | — | `cuerpo` (15/w500/1.4) — mismo mapeo exacto que usó la 033 |
| "Filtros" (hoja de filtros, fontSize 18/w800) | — | `subtitulo` (17, el más cercano) |
| "Hola, {nombre}" (`encabezado_feed.dart`, fontSize 17/w800) | — | `subtitulo` (17 exacto) |
| Aviso de "no se puede editar" (título fontSize 13/w700, cuerpo fontSize 12) | — | `cuerpoChico.copyWith(fontWeight: w700)` / `etiqueta` |

**Excepciones documentadas en el código, sin token:** el `SizedBox(height/width: 20)`
del spinner de carga de `publicar_trabajo_screen.dart` (tamaño de
componente, no espaciado — mismo criterio que 032 dejó para el spinner de
login); `Size(100, 40)`/`Size(0, 42)` (`minimumSize` de botones, tamaño de
componente); `EdgeInsets.only(top: 60)` en `estados_feed.dart` (desplazamiento
de layout para centrar el estado bajo la barra de búsqueda, no un hueco entre
elementos).

### Espaciado y radios

Mismas reglas de redondeo que fijaron las tareas 032/033 para los valores
que no caen exacto en la escala 4/8/12/16/24/32 (`AppEspaciado`) ni en
12/16/20 (`AppRadios`), aplicadas sin reinventar el criterio:

- `2 → xs(4)`, `6 → sm(8)`, `10 → md(12)`, `14 → md(12)`, `18 → lg(16)`,
  `20 → lg(16)`, `28 → xl(24)`, `40 → xxl(32)` (espaciado).
- Radios: `10/14 → campo(12)/tarjeta(16)` según si el contenedor es más
  "campo" o más "tarjeta" (mismo criterio semántico que 032/033); **`24` no
  tenía precedente exacto** — aparece en la píldora de búsqueda
  (`OutlineInputBorder`) y en el radio superior de la hoja de filtros
  (`BorderRadius.vertical(top:)`). Se redondeó a `chip` (20, el más cercano
  de los tres roles) en ambos casos, documentado en el propio código: una
  píldora de búsqueda y el borde superior de una hoja modal son, de los tres
  roles disponibles, más parecidos a una forma "casi del todo redondeada"
  (`chip`) que a una tarjeta o un campo de texto estándar.

## El hallazgo de contraste — verificado, no corregido a propósito

El punto 3 de la tarea pedía verificar que el precio/presupuesto (texto en
`AppColores.acento` sobre fondo blanco/superficie) siguiera legible,
señalando que **no es el mismo caso de contraste roto que arregló la 031**
(que era texto blanco sobre fondo dorado).

Se hizo el cálculo WCAG completo (misma fórmula que documentó la 031):

```
canal_lineal(c) = c/12.92                        si c ≤ 0.03928
                 = ((c+0.055)/1.055) ^ 2.4        si no
luminancia(color) = 0.2126·lin(R) + 0.7152·lin(G) + 0.0722·lin(B)
contraste(A, B) = (L_claro + 0.05) / (L_oscuro + 0.05)
```

`AppColores.acento` (#FFC107): luminancia ≈ 0.5944. Blanco: luminancia = 1.0.

**Contraste = (1.0 + 0.05) / (0.5944 + 0.05) ≈ 1.63:1.**

Es **el mismo número exacto** que calculó la 031 para blanco-sobre-dorado —
y no es casualidad: el contraste WCAG es una razón entre las dos luminancias
más clara/más oscura, **simétrica respecto a cuál de las dos hace de texto y
cuál de fondo**. Dorado-sobre-blanco y blanco-sobre-dorado son el mismo par
de colores con los papeles intercambiados, así que dan el mismo 1.63:1 —
muy por debajo del mínimo AA (4.5:1), y también por debajo del mínimo AA
para texto grande (3:1) aunque el precio use `numero` (20/w700).

Confirmado visualmente en las capturas: en modo claro el precio en dorado
sobre tarjeta blanca es legible pero notablemente menos nítido que el resto
del texto (ver `034-feed-con-resultados-despues-claro.png`); en modo oscuro
el mismo dorado sobre el navy oscuro de la superficie (`#14273A`) se ve bien
—ese par sí tiene contraste alto, como ya demostró la 031 con el botón—.

**No se corrigió**, por dos razones explícitas:

1. Es un cambio de **color**, no de tipografía/espaciado/radios — fuera del
   alcance declarado de esta tarea (punto "Qué hacer" de la 034), y del
   patrón que ya siguieron 032/033 ("Colores: fuera de alcance de esta
   tarea", incluso cuando había roles de color ya definidos y aplicables).
2. ADR-0016 decisión 1 es explícita: los tres colores de marca (marino,
   dorado, verde) no cambian sin instrucción explícita del dueño; cambiar a
   qué texto se le aplica `AppColores.acento` directamente (o introducir un
   "dorado seguro para texto") sí es una decisión de identidad de marca, no
   de tipografía.

Se deja anotado aquí, en `docs/agent-tasks/034-*.md` y en el snapshot para
que `tech-lead`/QA decida si abre una tarea de contraste específica —
exactamente el mismo tratamiento que la 031 le dio al hallazgo de `onError`.

## Rol `numero`: primer uso real en el proyecto

Hasta esta tarea ningún archivo usaba `AppTipografia.numero` (7 roles
definidos por la 031, 6 ya en uso por 032/033). Al revisar
`tarjeta_trabajo.dart`/`tarjeta_mi_publicacion.dart` para el punto 3 de la
tarea, el precio/presupuesto es exactamente el caso que el rol describe
("Montos y precios — cifras tabulares para que un monto no cambie de anchura
al actualizarse"). Se aplicó ahí, subiendo el tamaño del precio de 15→20
(`tarjeta_trabajo`) y 14→20 (`tarjeta_mi_publicacion`) — un cambio visual
perceptible pero deliberado: es el precio de una tarjeta de feed, el dato
que más rápido necesita leer quien navega, y es literalmente el uso que
documenta el rol. Verificado en las capturas que el salto de tamaño no
produce overflow (el precio no está en un `Expanded`; la fila crece de alto
sin problema).

## Verificación

- `flutter analyze`: **19 issues, 0 errores** — idéntico a la línea base de
  la 033, ninguno nuevo, ninguno en los 12 archivos tocados.
- `flutter test`: **253/253 pasan**, mismo total que antes de la tarea.
  **Ningún test necesitó cambios**: los de
  `test/funcionalidades/trabajos/widgets/` (`tarjeta_trabajo_test.dart`,
  `tarjeta_mi_publicacion_test.dart`, `barra_busqueda_trabajos_test.dart`,
  `toggle_feed_trabajos_test.dart`, `estados_feed_test.dart`,
  `entrada_escalonada_test.dart`) solo afirman sobre texto visible y
  callbacks (`find.text(...)`, `onPressed`/`onTap`), no sobre valores
  concretos de `fontSize`/`EdgeInsets`/`BorderRadius`, así que ninguna
  aserción dependía de un número que este cambio tocara.

## Verificación visual — capturas reales, sin tocar el emulador

Siguiendo el patrón que evitó el incidente de la 032 (instalar sobre una
sesión ajena) y que ya usó la 033 con éxito (widget test en vez de
emulador), se escribió `test/manual/generar_capturas_trabajos.dart`:

- Monta **las pantallas reales** (`TrabajosTab`, `MisPublicacionesScreen`) —
  no una recomposición manual de sus widgets — con `PublicacionService`/
  `PostulacionService` de verdad, inyectados vía `MultiProvider` (mismo
  mecanismo de inyección que usa la app, ADR-0014), apuntando a un
  `MockClient` en memoria que responde según la ruta pedida
  (`/api/trabajos`, `/api/trabajos/mios`, cualquier otra ruta con `[]`) —
  mismo patrón exacto que
  `test/funcionalidades/trabajos/trabajos_y_postulaciones_test.dart`.
- Es un paso más fiel que el de la 033 (que renderizaba los widgets de paso
  extraídos, aislados): aquí se prueba el `State` completo de la pantalla —
  su `initState`, su carga async, el stagger de la primera carga (ADR-0015)
  — no solo la capa de presentación.
- 4 escenarios × 2 temas = 8 capturas "después": feed con resultados, feed
  sin resultados, "Mis publicaciones" con resultados, "Mis publicaciones"
  sin resultados.
- **"Antes"**: se hizo `git stash push` sobre los 12 archivos de `lib/`
  tocados por esta tarea (sin tocar el generador, que no cambió ninguna
  firma pública de los widgets que monta) y se corrió el mismo generador con
  `--dart-define=SUFIJO=antes`; luego `git stash pop` para restaurar. Se
  verificó `flutter analyze`/`flutter test` de nuevo tras el `pop` (mismos
  resultados que antes del stash).
- No termina en `_test.dart` a propósito (mismo criterio que la 033):
  `flutter test` sin argumentos no lo descubre; se invoca a mano.

16 archivos en `docs/agent-reports/capturas/034-*.png`:
`feed-con-resultados`, `feed-sin-resultados`,
`mis-publicaciones-con-resultados`, `mis-publicaciones-sin-resultados`, cada
uno en `antes`/`despues` × `claro`/`oscuro`.

**Revisadas una por una:** el feed y "Mis publicaciones" se ven correctos en
ambos temas, con y sin resultados; los badges de estado (verde "Publicado",
gris "En progreso"), los chips de categoría/plazo, la insignia de bienvenida
con gradiente y el precio en `numero` se leen bien. Comparando antes/después
del mismo escenario (`feed-con-resultados-claro`): el precio se ve
notablemente más grande y legible (`numero`, 20px, vs. el 15px anterior), y
el chip "Largo plazo" que en la versión "antes" quedaba cortado por el borde
de la pantalla se ve completo en "después" (efecto lateral del ajuste de
`etiqueta`/padding en los chips de la barra de búsqueda). Limitación conocida
y ya documentada por la 033: el texto de `ElevatedButton`/`OutlinedButton`
sale como bloque opaco en estas capturas porque `AppTema` no fija
`fontFamily: 'Sora'` en sus temas de botón — preexistente, no de esta tarea,
no visible en un dispositivo real.

## Qué NO se tocó (fuera de alcance, explícito en la instrucción de la tarea)

- `detalle_trabajo_screen.dart` (tarea 035).
- El contrato de `PublicacionService`/`PostulacionService` y la paginación
  (`pagina`/`tamano`): cero cambios.
- El vocabulario de movimiento de ADR-0015 (`PulsaConEscala`, el
  `AnimatedContainer` del flip de color de los chips de filtro, el stagger
  de `EntradaEscalonada`): intacto, no se añadió ni se duplicó ninguna
  animación.
- Colores (salvo el hallazgo de contraste documentado arriba, que se dejó
  sin tocar a propósito).
- `fila_feed.dart` y `entrada_escalonada.dart`: no tenían ningún literal de
  tipografía/espaciado/radio que tokenizar (el único número de
  `entrada_escalonada.dart`, el desplazamiento `8` del `Transform.translate`,
  es una distancia de animación de ADR-0015, no espaciado de layout).

## Archivos tocados

**Modificados (12):**
- `lib/funcionalidades/trabajos/pantallas/trabajos_tab.dart`
- `lib/funcionalidades/trabajos/pantallas/mis_publicaciones_screen.dart`
- `lib/funcionalidades/trabajos/pantallas/publicar_trabajo_screen.dart`
- `lib/funcionalidades/trabajos/pantallas/editar_trabajo_screen.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/tarjeta_trabajo.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/tarjeta_mi_publicacion.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/barra_busqueda_trabajos.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/hoja_filtros_trabajos.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/toggle_feed_trabajos.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/encabezado_feed.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/estados_feed.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/estados_mis_publicaciones.dart`

**Sin cambios (revisados, sin literales que tokenizar):**
- `lib/funcionalidades/trabajos/pantallas/widgets/fila_feed.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/entrada_escalonada.dart`

**Nuevo — herramienta de verificación (no se ejecuta en la suite normal):**
- `test/manual/generar_capturas_trabajos.dart`

**Nuevas — 16 capturas:**
- `docs/agent-reports/capturas/034-{feed,mis-publicaciones}-{con,sin}-resultados-{antes,despues}-{claro,oscuro}.png`

**Documentación:**
- `docs/agent-tasks/034-rediseno-trabajos.md` (estado → hecho, notas)
- `docs/agent-context/repo-snapshot.md`
- `docs/agent-reports/034-rediseno-trabajos.md` (este archivo)

No se tocó `backend/**`, `firestore.rules`, `detalle_trabajo_screen.dart`,
ni ningún archivo fuera de `trabajos`/`test/manual`.
