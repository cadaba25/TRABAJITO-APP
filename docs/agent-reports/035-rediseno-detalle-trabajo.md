# Reporte — tarea 035: rediseño visual, `detalle_trabajo_screen.dart`

**Fecha:** 2026-09-11
**Agente:** flutter-agent
**Rama:** `feature/rediseno-detalle-trabajo` (sobre `feature/rediseno-trabajos`, con 031/032/033/034 mergeadas)
**Estado:** hecho

## Qué se hizo

1. Se aplicaron los tokens de la tarea 031 (ADR-0016) a
   `lib/funcionalidades/trabajos/pantallas/detalle_trabajo_screen.dart`
   (1150 líneas antes de esta tarea, el archivo Dart más grande del
   proyecto).
2. Se sacaron los `AlertDialog` inline a sus propios archivos en
   `lib/funcionalidades/trabajos/pantallas/widgets/`:
   - `dialogo_confirmacion.dart` — el diálogo Sí/No genérico (antes
     `_confirmar`), usado por `_rechazarTrabajo`.
   - `dialogo_solicitar_correccion.dart` — pedir correcciones antes de
     aceptar la entrega.
   - `dialogo_reclamar_problema.dart` — el reclamo a soporte (ADR-0007).
   - `dialogo_cancelar_contratacion.dart` — elegir entre reabrir o cerrar al
     cancelar una contratación.
   - `dialogo_agregar_evidencia.dart` — registrar un avance del trabajo.
3. Se sustituyeron las cuatro variables locales (`oscuro`, `textoPrincipal`,
   `textoSec`, `superficie`, `borde`), calculadas a mano con un `? :` en
   cuatro métodos distintos (`_contenido`, `_fila`, `_tarjetaContrato`,
   `_seccionEvidencias`), por llamadas directas a
   `colorTextoFuerte(context)`/`colorTextoSuave(context)`/
   `colorSuperficie(context)`/`colorBorde(context)` de
   `colores_por_tema.dart` — mismos valores exactos (`azulOscuro`/`principal`
   son el mismo color; `grisMedio`/`grisTexto`, `superficieOscura`/`blanco` y
   `bordeOscuro`/`grisClaro` ya eran justo lo que la pantalla calculaba a
   mano), cero cambio visual.
4. Se añadieron 7 tests de widget nuevos para los cinco diálogos extraídos
   (no tenían ninguno: vivían embebidos en una pantalla sin tests) y un
   generador de capturas (`test/manual/generar_capturas_detalle_trabajo.dart`)
   que ejercita los 6 estados del trabajo pedidos por la tarea.

**No se tocó**: la máquina de estados de negocio en `_acciones()`, ninguna
llamada a `PublicacionService`/`PostulacionService`, ni `_reservarPago()`
(la costura con el chat de Firestore) — exactamente lo que pedía la tarea.

## Corrección sobre el conteo de diálogos: eran 5, no 6

ADR-0014 (tarea 027) describe el archivo como "6 `AlertDialog` inline", y el
encargo de esta tarea 035 repite ese número. Al abrir el archivo y contar
`showDialog(` hay **cinco**:

1. `_solicitarCorreccion` → `AlertDialog` "Solicitar correcciones".
2. `_reclamarProblema` → `AlertDialog` "Reportar un problema".
3. `_cancelarContratacion` → `AlertDialog` "¿Qué hacemos con el trabajo?".
4. `_confirmar` → `AlertDialog` genérico Sí/No (el único que ya nacía
   reutilizable; solo lo llamaba `_rechazarTrabajo`, pero no estaba atado a
   "rechazar" en su implementación).
5. `_agregarEvidencia` → `AlertDialog` "Agregar avance".

No hay un sexto en ningún punto del archivo (verificado con
`grep -n "AlertDialog\|showDialog"` antes de tocar nada). Es probable que el
conteo original de ADR-0014 se hiciera de memoria al escribir la sección de
contexto de esa tarea, sin contar literalmente. Se corrige aquí, en el propio
archivo de la tarea 035 y en `repo-snapshot.md`, para que nadie vuelva a
buscar un sexto diálogo que no existe.

## Patrón de extracción

Mismo patrón que `postularse_sheet.dart`/`mostrarPostularseSheet` (el único
precedente de "función que abre un `showXxx` y devuelve su resultado" en la
funcionalidad de trabajos): una función pública `mostrarDialogoXxx(context,
...)` que envuelve `showDialog<T>(...)`, y un widget privado (`_DialogoXxx`,
`StatelessWidget` o `StatefulWidget` si necesita `TextEditingController`) con
el `AlertDialog` de verdad.

La lógica de negocio alrededor de cada diálogo —qué validar, qué servicio
llamar después, qué mensaje de éxito mostrar— **no se movió**: sigue en los
mismos métodos privados de `_DetalleTrabajoScreenState`
(`_solicitarCorreccion`, `_reclamarProblema`, `_cancelarContratacion`,
`_rechazarTrabajo`, `_agregarEvidencia`), que ahora hacen `await
mostrarDialogoXxx(context, ...)` en vez de construir el `AlertDialog` inline.
Dos diálogos necesitaron un ajuste mecánico para que esto fuera cierto sin
cambiar comportamiento:

- **`_reclamarProblema`**: antes, los dos `TextEditingController` (motivo y
  detalle) vivían en el método de la pantalla y el diálogo solo devolvía
  `bool` ("¿se pulsó Enviar?"); la pantalla leía el texto de los
  controladores **después** de cerrarse el diálogo. Al mover los
  controladores dentro del widget del diálogo (donde deben vivir: son estado
  de ese formulario, no de la pantalla), `mostrarDialogoReclamarProblema`
  devuelve ahora el record `(String motivo, String descripcion)?` con el
  texto ya recortado (`trim()`), en vez de `bool`. La pantalla sigue
  validando "motivo vacío → error, sin llamar al servicio" exactamente
  igual, solo que sobre el valor que le llega en el record en vez de sobre
  un controlador que ya no le pertenece.
- **`_confirmar`**: pasó de ser un método privado de la pantalla a una
  función de nivel de archivo (`mostrarDialogoConfirmacion`) en su propio
  módulo. Se mantiene genérico (título + mensaje parametrizables), tal como
  estaba, aunque hoy solo lo use `_rechazarTrabajo`.

Los otros tres (`_solicitarCorreccion`, `_cancelarContratacion`,
`_agregarEvidencia`) no necesitaron ningún ajuste de forma: ya devolvían
justo lo que la pantalla necesitaba (`String?` o `bool?`).

## Mapeo de tokens

Mismo criterio que 032/033/034: cada `TextStyle(fontSize:, fontWeight:)`
suelto se sustituyó por el rol de `AppTipografia` cuyo tamaño coincide exacto
o es el más cercano, con `.copyWith(color:, fontWeight:)` cuando hacía falta
preservar el color por-tema o un peso que el rol no fija.

| Uso | Antes | Rol aplicado |
|---|---|---|
| Título de AppBar ("Detalle del trabajo") | `fontWeight: w800, letterSpacing: -0.5` (tamaño heredado, 22) | `titulo` (22/w700/-0.3) — mismo tratamiento que `editar_trabajo_screen.dart`/`publicar_trabajo_screen.dart`/`mis_publicaciones_screen.dart` (034), las tres pantallas hermanas de `trabajos/` |
| Título del trabajo (`pub.titulo`, el h1 del detalle) | 22/w800/-0.5 | `titulo` (22/w700/-0.3) |
| "Descripción", "Contrato", "Avances del trabajo" (cabeceras de sección) | 15/w800 | `subtitulo` (17/w600) — mismo rol que usa `hoja_filtros_trabajos.dart` para el título de su hoja ("Filtros"), precedente ya establecido en 034 |
| Nombre del autor (cabecera) | 15/w700 | `cuerpo` (15/w500) `.copyWith(fontWeight: w700)` — se conserva el tamaño 15 exacto |
| `tiempoRelativo`, badges, texto de apoyo | 10.5–12 | `etiqueta` (11/w600) — es el mismo rol que ya usa `tarjeta_trabajo.dart` para `p.tiempoRelativo` |
| Descripción del trabajo (cuerpo largo) | 14/height 1.5 | `cuerpo` (15/w500/1.4) |
| Etiqueta/valor de `_fila` y de `linea()` (contrato) | 12–13/w500–w700 | `cuerpoChico` (13/w500) `.copyWith(fontWeight: w700)` para el valor — se unificaron ambas funciones al mismo tratamiento (antes usaban tamaños ligeramente distintos, 13 vs 12/12.5, sin ninguna razón visible) |
| Avatar-inicial (círculo de autor/evidencia) | w800 sin tamaño fijo | `cuerpoChico`/`etiqueta` `.copyWith(fontWeight: w700/w800)` — mismo patrón que el avatar de `tarjeta_trabajo.dart` |
| `_infoBanner` (avisos contextuales) | `fontWeight: w600` sin tamaño fijo | `cuerpo.copyWith(fontWeight: w600)` |

**Sobre `AppTipografia.numero` ("montos y precios"):** se evaluó aplicarlo al
presupuesto (`_fila`) y al monto acordado (`_tarjetaContrato`), que es
literalmente el uso que documenta el rol y que 034 ya usó en
`tarjeta_trabajo.dart`. Se decidió **no** hacerlo aquí: en las tarjetas del
feed el precio es una cifra destacada, sola, en la esquina de la tarjeta
(20/w700/tabular tiene sentido ahí); en este archivo el mismo dato vive
incrustado en una fila compacta de etiqueta+valor (`_fila`/`linea()`), junto
a otros cuatro o cinco datos con el mismo tratamiento visual — subirlo a 20px
solo a él habría roto la alineación de esas filas sin ganar legibilidad real.
Se dejó en `cuerpoChico` con `fontWeight: w700`, igual que el resto de
valores de esas mismas filas.

### Espaciado y radios

- `AppEspaciado`: mapeo directo donde el valor coincidía exacto (4→`xs`,
  8→`sm`, 12→`md`, 16→`lg`, 24→`xl`) y por redondeo donde no (18→`lg`,
  20→`xl`, 10→`sm` en los huecos icono-texto; **28→`xxl`**, el hueco antes de
  las acciones principales, que además es literalmente la descripción de
  `AppEspaciado.xxl` en su propio docstring: "espacio antes de una acción
  principal"). El `14` de los `padding: EdgeInsets.all(14)` (info banner y
  tarjetas de evidencia) se dejó literal a propósito: es el mismo caso suelto
  que la auditoría de la 031 ya documentó como excepción (no cae en ningún
  rol y no es un patrón repetido, solo redondeo entre `md` y `lg`).
- `AppRadios`: `circular(16)` → `tarjeta`, `circular(20)` → `chip`,
  `circular(12)` → `campo` (info banner y tarjetas de evidencia, que ya
  usaban 12 antes). El `_chip`/`_badgeEstado` de esta pantalla también se
  alinearon al padding exacto de `_Chip` en `tarjeta_trabajo.dart`
  (`AppEspaciado.md`/`xs` en vez del `10`/`4` suelto que traían), para que
  los dos chips visualmente equivalentes de la funcionalidad usen el mismo
  molde.
- Radios de `CircleAvatar` (22, 16, 12) e íconos (`size:`) **no se tocaron**:
  no son parte del alcance de `AppRadios`/`AppEspaciado` (mismo criterio que
  `tarjeta_trabajo.dart` en la 034, que tampoco los tocó).

### Color: `colorPrecio(context)` no aplicaba aquí

El reporte de la 034 corrigió (en un commit aparte, `aa2fd65`) el precio de
`tarjeta_trabajo.dart`/`tarjeta_mi_publicacion.dart`, que pintaba
`AppColores.acento` (dorado) como color de **texto** sobre superficie clara
(~1.63:1, falla WCAG AA) y ahora usa `colorPrecio(context)`. Se revisó
específicamente si `detalle_trabajo_screen.dart` repetía ese defecto en
alguno de los dos lugares donde muestra dinero:

- `_fila(..., 'Presupuesto', pub.presupuesto)` → el valor se pinta con
  `colorTextoFuerte(context)` (marino/blanco según tema), nunca con
  `AppColores.acento`.
- `linea(Icons.payments_rounded, 'Pago acordado', 'L. ... / hora')` dentro
  de `_tarjetaContrato` → mismo color, `colorTextoFuerte(context)`.

**No había nada que corregir.** El único sitio de este archivo que usa
`AppColores.dorado`/`acento` como color de texto es el badge de estado
(`_badgeEstado`, para `en_progreso`/`esperando_confirmacion`) y el chip de
categoría (`_chip`), ninguno de los dos es un "precio" — ver el hallazgo
lateral más abajo.

### Hallazgo lateral, no corregido (fuera de alcance)

`_badgeEstado` pinta `AppColores.dorado` como color de texto sobre un fondo
del mismo color al 15% de opacidad, para los estados `en_progreso` y
`esperando_confirmacion`. Es el mismo patrón que el chip de categoría de
`tarjeta_trabajo.dart` (`_Chip` con `color: AppColores.acento`), que la 034
tampoco tocó. **No es el mismo defecto que corrigió `colorPrecio()`** — ese
era texto dorado sobre una superficie sólida clara (blanco), aquí es texto
dorado sobre un tinte muy claro del propio dorado (`alpha: 0.15`), un
contraste distinto que ninguna tarea de ADR-0016 ha calculado todavía. Se
anota para que QA o una tarea de contraste dedicada lo revise —mismo criterio
que `onError` en la 031 y que este mismo hallazgo en la 034—, no se calculó
ni se corrigió aquí porque está fuera del alcance que pidió esta tarea
(diálogos + tokens de tipografía/espaciado/radios en la pantalla existente).

## Decisión sobre el tamaño final del archivo: excepción viva

| | Líneas |
|---|---|
| `detalle_trabajo_screen.dart` antes | 1150 |
| `detalle_trabajo_screen.dart` después | **987** |
| `dialogo_confirmacion.dart` | 52 |
| `dialogo_solicitar_correccion.dart` | 67 |
| `dialogo_reclamar_problema.dart` | 86 |
| `dialogo_cancelar_contratacion.dart` | 66 |
| `dialogo_agregar_evidencia.dart` | 84 |

Sacar los cinco diálogos y unificar las cuatro variables de color por-tema
bajó el archivo principal en 163 líneas (1150 → 987). **Sigue muy por encima
del techo de 300 de ADR-0014, y se deja así a propósito**: es exactamente la
decisión que la propia tarea pedía tomar y documentar, no evadir.

Lo que queda en el archivo y por qué no se movió:

- **La máquina de estados de `_acciones()`**: ~15 métodos `_widget()`
  (`_botonPostular`, `_botonCalificar`, `_botonChat`, `_botonCancelar`,
  `_botonReclamar`, `_tarjetaContrato`, `_seccionEvidencias`, `_fila`,
  `_chip`, `_badgeEstado`, `_infoBanner`...) que dependen unos de otros y de
  un `switch` sobre `pub.estado` cruzado con "¿soy el dueño o el asignado?".
  Partirla en widgets independientes es un refactor real de la lógica de
  presentación, no un cambio de tokens, y el criterio de la tarea era
  explícito: "no toques la lógica de la máquina de estados... más allá de
  mover código literal".
- **`_reservarPago()`**: sigue construyendo `ChatService()` inline (la única
  excepción documentada a "ningún servicio se construye dentro de un
  `State`", anotada desde la parte B-2 de la tarea 027) porque el acuerdo de
  pago todavía vive en el chat de Firestore. Tocar esta pantalla más allá de
  visual sin la migración del chat sería dejar una pieza a medio camino: el
  propio ADR-0014 lo señala como el momento correcto para partir el archivo
  del todo, precisamente porque ahí ya hay que reescribir esta costura de
  todas formas.

**Conclusión explícita, tal como pide la tarea**: el archivo queda **partido
parcialmente** (los diálogos, que era bajo riesgo y no tocaba negocio) y el
resto **queda como excepción viva documentada** en el docstring de la propia
clase (`_DetalleTrabajoScreenState`), en el archivo de la tarea 035 y aquí —
mismo criterio que `gestor_sesion.dart` (314), `auth_service.dart` (350) y
`publicacion_service.dart` (380): una razón de negocio real para no partir
todavía, no "no dio tiempo".

## Verificación

- `flutter analyze`: **19 issues, 0 errores** — igual que la línea base antes
  de esta tarea. Ninguna issue nueva en `detalle_trabajo_screen.dart`, en los
  cinco `dialogo_*.dart` nuevos, ni en los tests nuevos.
- `flutter test`: **261/261** (254 preexistentes en esta rama + **7 nuevos**
  en `test/funcionalidades/trabajos/widgets/dialogos_detalle_trabajo_test.dart`,
  uno por diálogo salvo `mostrarDialogoReclamarProblema` y
  `mostrarDialogoCancelarContratacion`, que tienen dos cada uno para cubrir
  sus dos ramas de contenido condicional —motivo vacío permitido, "sin
  escrow no menciona el reembolso"—). No se tocó ninguna aserción de un test
  existente.
- No existía ningún test de estos cinco diálogos antes de esta tarea (vivían
  embebidos en una pantalla sin tests de widget); tampoco existe test de
  `postularse_sheet.dart` ni de `hoja_filtros_trabajos.dart` en el resto del
  proyecto, así que añadir cobertura mínima aquí sube el estándar de la
  funcionalidad en vez de simplemente igualarlo.

## Verificación visual: capturas, sin usar el emulador

Mismo criterio que las tareas 033 y 034 (hubo dos incidentes reales de
sesión de emulador pisada/tumbada en esta cadena de tareas): se generaron 12
capturas reales —los 6 estados que pide la tarea (activo, asignado, en
progreso, esperando confirmación, en disputa, completado) × claro/oscuro—
con `test/manual/generar_capturas_detalle_trabajo.dart`. No termina en
`_test.dart` a propósito, así que `flutter test` sin argumentos no lo
descubre ni lo ejecuta (confirmado: el conteo de 261 no lo incluye). Se
invoca a mano con `flutter test test/manual/generar_capturas_detalle_trabajo.dart`.

Monta `DetalleTrabajoScreen` real con `PublicacionService`/
`PostulacionService` reales sobre un `MockClient` en memoria (mismo patrón
que `generar_capturas_trabajos.dart` de la 034 y que
`trabajos_y_postulaciones_test.dart`), no una recomposición manual de
widgets sueltos:

| Estado | Rol de quien mira | Qué enseña |
|---|---|---|
| `activo` | un trabajador que no participa | botón "Postularme" |
| `asignado` | el trabajador asignado | banner "acuerden el pago..." + "Rechazar trabajo" |
| `en_progreso` | el trabajador, con un avance ya subido | "Marcar como terminado" habilitado + "Reportar problema" |
| `esperando_confirmacion` | el empleador | "Aceptar y pagar L. 350" + "Solicitar correcciones" |
| `en_disputa` | el trabajador | solo el aviso de soporte, sin ninguna acción (a propósito: ofrecer una sería mentir) |
| `completado` | el empleador | "Calificar al trabajador" |

Capturas en `docs/agent-reports/capturas/035-<estado>-<claro\|oscuro>.png`
(12 archivos). Revisadas a mano las seis en modo claro y dos en oscuro
(`en-progreso`, `activo`): tarjeta de contrato, badges de estado, chips,
avances y banners se ven con los tokens aplicados, sin overflow, y el
contraste de los banners informativos (azul, verde, dorado de advertencia,
error) se mantiene legible en ambos temas.

**Limitación conocida de este método de captura, no nueva de esta tarea**
(ya está en el reporte de la 034): en el entorno de `flutter_test` sin
`MaterialIcons` cargado, los íconos salen como recuadros vacíos y el texto de
los botones (`ElevatedButton`/`OutlinedButton`/`TextButton`) sale como un
bloque sólido en vez de glifos — se ve en las capturas de esta tarea igual
que en las de la 034 (comparado directamente). No afecta lo que se está
verificando (layout, color, tipografía del cuerpo, espaciado): el texto de
cuerpo, que sí usa la fuente `Sora` cargada explícitamente con `FontLoader`,
se ve correctamente en todas las capturas.

## Desvíos de criterio propio (anotados, no se paró a preguntar)

1. **El conteo de "6 diálogos" se corrigió a 5** — ver sección dedicada
   arriba. No se inventó un sexto diálogo para cuadrar el número.
2. **`_reclamarProblema` cambió de forma interna** (el diálogo devuelve un
   record `(motivo, descripcion)` en vez de `bool`) para poder mover sus dos
   `TextEditingController` al widget que los usa. El comportamiento
   observable —qué se envía, cuándo se valida, qué mensaje se ve— es
   idéntico; se documenta porque técnicamente no es "mover código literal
   sin ningún cambio", aunque el resultado sea el mismo.
3. **Se añadieron 7 tests de widget nuevos** para los diálogos, no pedidos
   explícitamente por los criterios de aceptación (que piden capturas, no
   tests unitarios de los diálogos) pero sí por la regla 8 de `CLAUDE.md`
   ("cambios importantes requieren tests; si tocas algo sin cobertura,
   añade la cobertura mínima"): estos cinco diálogos no tenían ningún test
   antes, y ahora viven en su propio archivo público.
4. **`_chip`/`_badgeEstado` de esta pantalla se alinearon al padding de
   `tarjeta_trabajo.dart`** (`AppEspaciado.md`/`xs` en vez del `10`/`4`
   suelto original) en vez de solo tokenizar el valor que ya tenían. Es un
   cambio visual mínimo (2px menos de padding horizontal) que unifica dos
   chips visualmente equivalentes de la misma funcionalidad; se documenta
   por transparencia aunque el criterio de "redondear al valor de escala más
   cercano" ya lo cubre.
5. **No se aplicó `AppTipografia.numero` al presupuesto/monto acordado** —
   ver razonamiento en la sección de mapeo de tokens. Es una decisión de NO
   aplicar un rol que sí se aplicó en la pantalla hermana (034), documentada
   con su porqué en vez de aplicarlo por consistencia ciega.

## Qué falta (fuera de alcance de esta tarea, a propósito)

- `detalle_trabajo_screen.dart` sigue por encima del techo de 300 líneas —
  excepción viva, no una tarea pendiente: se resuelve cuando se migre el
  chat (fase 2b-2, fuera del alcance de ADR-0016).
- El hallazgo lateral del badge de estado (dorado como texto sobre tinte
  claro del mismo dorado) no se corrigió — ver sección dedicada.
- `_reservarPago()` sigue leyendo el acuerdo de pago del chat de Firestore
  (`ChatService()` construido inline) — no es esta tarea, está anotado en
  `docs/agent-context/RETOMAR-AQUI.md` y no se tocó.

## Archivos tocados

- Modificado:
  `lib/funcionalidades/trabajos/pantallas/detalle_trabajo_screen.dart`
  (1150 → 987 líneas).
- Nuevos (`lib/`):
  `lib/funcionalidades/trabajos/pantallas/widgets/dialogo_confirmacion.dart`,
  `dialogo_solicitar_correccion.dart`, `dialogo_reclamar_problema.dart`,
  `dialogo_cancelar_contratacion.dart`, `dialogo_agregar_evidencia.dart`.
- Nuevos (`test/`):
  `test/funcionalidades/trabajos/widgets/dialogos_detalle_trabajo_test.dart`
  (7 tests), `test/manual/generar_capturas_detalle_trabajo.dart` (no
  descubierto por `flutter test` sin argumentos).
- Nuevos (capturas): `docs/agent-reports/capturas/035-*.png` (12 archivos).
- Documentación: `docs/agent-tasks/035-rediseno-detalle-trabajo.md` (estado
  → `hecho`, checkboxes y notas), `docs/agent-context/repo-snapshot.md`
  (sección de la tarea 035 + corrección de la nota de contraste de la 034,
  que no se había actualizado tras el commit de arreglo `aa2fd65`).
