---
id: 050
titulo: "UI: sistema de botones compartido (hallazgo 1 de la auditoría de diseño 2026-09-13)"
estado: en-revision
agente: "flutter-agent"
creada: 2026-09-13
rama: "feature/sistema-de-botones"
---

## Objetivo

Construir el sistema de botones que pide la sección 6 de
`docs/design-system-frontend.md` (Primary/Secondary/Tertiary/Text/
Destructive/Icon, con altura/radio/tipografía/loading/disabled/pressed
consistentes) como componentes compartidos en `lib/compartido/widgets/`, y
migrar a ellos los ~21 archivos que hoy reinventan `TextButton`,
`ElevatedButton.styleFrom(backgroundColor: AppColores.error)` o `IconButton`
pantalla por pantalla.

Es el hallazgo 1 (`[ALTO — necesita plan de tech-lead]`) del reporte
`docs/agent-reports/audit-diseno-2026-09-13.md`. Se ejecuta **antes** que la
tarea 051 (barrido de contraste dorado) a propósito: varios de los archivos
que 051 tendría que tocar por tener texto dorado son en realidad botones de
texto (`TextButton` o un `GestureDetector`+`Text` que hace de enlace) — al
migrarlos aquí a `BotonTexto` con un color por defecto ya correcto en
contraste, 051 no tiene que volver a tocarlos. Ver la lista de archivos más
abajo: los marcados "(resuelve parte del hallazgo 2)" quedan fuera del
alcance de la tarea 051.

## Contexto relevante

- `docs/agent-reports/audit-diseno-2026-09-13.md`, hallazgo 1 completo (líneas
  51-112): qué existe hoy (`elevatedButtonTheme`/`outlinedButtonTheme` en
  `lib/nucleo/tema/app_tema.dart`, altura 52), qué falta (sin
  `textButtonTheme`/`iconButtonThemeData`, destructivo reimplementado en 7+
  sitios, alturas de diálogo que rompen el criterio, sin componente de ícono
  con criterio propio, loading duplicado a mano).
- `docs/design-system-frontend.md` sección 6 (Botones) y sección 9
  (ergonomía/targets táctiles) y 14 (accesibilidad).
- `lib/nucleo/tema/app_tema.dart` — el tema global actual, en particular el
  docstring de cabecera sobre el contraste blanco/`acento` (ya resuelto ahí
  para Elevated/Outlined; los componentes nuevos deben respetar el mismo
  criterio, no reintroducir el bug).
- `lib/nucleo/tema/colores_por_tema.dart` — `colorPrecio(context)` ya resuelve
  "dorado como texto sobre superficie clara" para el precio; el componente
  `BotonTexto` de esta tarea necesita el mismo criterio generalizado (ver
  "Qué hacer" punto 2).
- `lib/compartido/widgets/boton_continuar_paso.dart` — el único sitio que hoy
  encapsula loading como componente propio (solo para el registro); se
  reemplaza por dentro con `BotonPrimario`, no se borra su API pública.
- `docs/agent-tasks/049-ux-arreglos-puntuales-auditoria.md` — YA ejecutada y
  commiteada. Tocó `trabajadores_tab.dart`, `ranking_tab.dart`,
  `mis_postulaciones_screen.dart`, `login_screen.dart` (tooltips y tamaños,
  no botones nuevos) y otros. **Las líneas exactas que cita el reporte de
  auditoría para esos archivos ya no son las mismas** — vuelve a `grep` antes
  de editar, no confíes en los números de línea del reporte para esos
  archivos.
- ADR-0014 (`docs/decisions.md`) y regla 14 de `CLAUDE.md` — techo de 300
  líneas por archivo Dart. Los componentes nuevos deben nacer pequeños (se
  espera <100 líneas cada uno, mismo criterio que ya se aplicó al partir
  `custom_textfield.dart` en la tarea 027 B-1).

## Módulos afectados y orden de trabajo

Toca únicamente Flutter (`lib/compartido/widgets/` + ~21 pantallas/widgets en
`lib/funcionalidades/**`). No cambia contratos de API ni modelo de datos, no
toca backend. No es una tarea "grande" en el sentido de cruzar módulos
backend/Flutter, pero sí cruza muchas funcionalidades de Flutter (trabajos,
postulaciones, perfil, autenticación, inicio) — por eso el plan lo deja el
`tech-lead` en vez de que `flutter-agent` decida el alcance sobre la marcha.

**Orden dentro de la tarea:**
1. Construir los 6 componentes nuevos y sus tests de widget primero, sin
   tocar ninguna pantalla todavía.
2. Migrar `dialogo_confirmacion.dart` (ver punto 4 de "Qué hacer") — es alto
   apalancamiento: arregla de un solo archivo el botón "No" (`TextButton` sin
   tamaño mínimo) y "Sí" (destructivo reimplementado) para todos sus
   llamadores actuales, sin tocar cada llamador.
3. Migrar el resto de archivos, agrupados por funcionalidad (autenticación,
   trabajos, postulaciones, perfil, inicio) para mantener los diffs
   revisables.
4. `flutter analyze` + `flutter test` al final.

Esta tarea debe llegar a `en-revision` o `hecho` **antes** de que se delegue
la tarea `051-barrido-contraste-dorado.md` (dependencia explícita, ver ese
archivo).

## Qué hacer

1. **Crear en `lib/compartido/widgets/` seis componentes nuevos**, uno por
   archivo (mismo criterio que ya usa la carpeta: un archivo, una razón para
   cambiar):
   - `boton_primario.dart` → `BotonPrimario` (envuelve `ElevatedButton`).
   - `boton_secundario.dart` → `BotonSecundario` (envuelve `OutlinedButton`).
   - `boton_terciario.dart` → `BotonTerciario` (envuelve un botón de énfasis
     medio — p.ej. `FilledButton.tonal` o un `ElevatedButton` con fondo
     `AppColores.acento.withValues(alpha: 0.12)` y texto de la variante
     WCAG-segura del punto 2 — no hay hoy ningún sitio que lo necesite con
     urgencia, así que puedes resolver la variante visual con tu criterio,
     pero el componente debe existir y quedar documentado en su docstring
     para que la próxima pantalla que necesite un botón de énfasis medio no
     vuelva a inventar uno).
   - `boton_texto.dart` → `BotonTexto` (envuelve `TextButton`). **Color por
     defecto**: la misma variante segura que ya usa `colorPrecio()` — claro:
     `AppColores.doradoTexto`, oscuro: `AppColores.acento` — no
     `AppColores.acento` crudo. Ver punto 2 de más abajo antes de escribir
     este archivo.
   - `boton_destructivo.dart` → `BotonDestructivo` (envuelve `ElevatedButton`
     con `backgroundColor: AppColores.error`, mismo `minimumSize` que el
     resto del sistema).
   - `boton_icono.dart` → `BotonIcono` (envuelve `IconButton`). `tooltip` es
     un parámetro **requerido, no nullable** — así ningún caso nuevo puede
     repetir el hallazgo 6 (labels semánticos ausentes) por construcción.
     Tamaño mínimo fijo de 48×48 (nunca `visualDensity: VisualDensity.compact`
     ni nada que lo reduzca). Admite `seleccionado`/`activo` opcional para los
     casos de toggle (p. ej. el ícono de filtro de
     `barra_busqueda_trabajos.dart`).

   **Props comunes a los 4 botones "grandes" (Primario/Secundario/Terciario/
   Destructivo):**
   - `texto` (`String`, requerido).
   - `onPressed` (`VoidCallback?`) — `null` = estado disabled, delegado al
     `disabledForegroundColor`/`disabledBackgroundColor` que ya define
     `app_tema.dart` (no reinventes el estilo disabled).
   - `cargando` (`bool`, default `false`) — mientras es `true`: reemplaza
     `texto` por un `CircularProgressIndicator` pequeño (mismo patrón que hoy
     está a mano en `login_screen.dart:227-235`) y fuerza `onPressed` a `null`
     para que no se pueda tocar dos veces.
   - `icono` (`IconData?`, opcional) — ícono inicial junto al texto.
   - `expandido` (`bool`, default `true` — la mayoría de usos actuales son de
     ancho completo; revisa caso por caso al migrar y pásalo en `false` donde
     no aplique, p. ej. los botones `Expanded` de `hoja_filtros_trabajos.dart`
     que van dos en una fila).
   - Altura/radio/tipografía: reutiliza lo que ya define
     `elevatedButtonTheme`/`outlinedButtonTheme` en `app_tema.dart` (52px,
     `AppRadios.campo`, `fontSize: 16, fontWeight: w600`) — no dupliques esos
     valores en el widget, apóyate en el tema.

   **`BotonTexto`:** `texto`, `onPressed`, `icono?`, altura mínima 48
   (`minimumSize: Size(0, 48)`), sin `expandido` (los enlaces de texto no
   ocupan el ancho completo).

   **`BotonIcono`:** `icono` (`IconData`), `onPressed`, `tooltip` (`String`,
   requerido), `seleccionado?` (`bool`), `color?` (override puntual si hace
   falta, pero el valor por defecto debe salir del tema, no de un color
   suelto).

2. **Generalizar `colorPrecio()` antes de usarlo en `BotonTexto`.** Está en
   `lib/nucleo/tema/colores_por_tema.dart:66` y hace exactamente lo que
   `BotonTexto` necesita, pero su nombre es específico de "precio". Añade una
   función con nombre genérico (p. ej. `colorAcentoTexto(BuildContext)`) que
   contenga la lógica (`_esOscuro(c) ? AppColores.acento :
   AppColores.doradoTexto`) y haz que `colorPrecio()` la llame por dentro (no
   dupliques la lógica, no rompas la API que ya usan `tarjeta_trabajo.dart` y
   `tarjeta_mi_publicacion.dart`). `BotonTexto` usa `colorAcentoTexto()` como
   color por defecto.

3. **Refactorizar `boton_continuar_paso.dart`** para que use `BotonPrimario`
   por dentro en vez de su propio `SizedBox`+`CircularProgressIndicator` a
   mano. Su API pública (los parámetros que ya reciben los 8 pasos de
   registro que lo usan) no cambia.

4. **Migrar `dialogo_confirmacion.dart`** (`lib/funcionalidades/trabajos/
   pantallas/widgets/dialogo_confirmacion.dart`): el botón "No" pasa a
   `BotonTexto`, el botón "Sí" pasa a `BotonDestructivo`. Esto arregla de un
   solo archivo el caso "TextButton sin tamaño mínimo en diálogo" y uno de
   los 7 sitios de destructivo reimplementado, para todos sus llamadores
   actuales (hoy: rechazar asignación) sin tocar cada uno.

5. **Migrar el resto de sitios.** Lista de partida (verifica con tu propio
   `grep` de `TextButton\(|ElevatedButton\.styleFrom|IconButton\(|
   OutlinedButton\.styleFrom` en `lib/funcionalidades/**` antes de dar la
   migración por completa — esta lista es la que encontró el tech-lead el
   2026-09-13, después de la tarea 049, pero un archivo nuevo pudo cambiar
   desde entonces):

   - `lib/funcionalidades/autenticacion/pantallas/login_screen.dart` —
     `TextButton` "¿Olvidaste tu contraseña?" → `BotonTexto`. El
     `GestureDetector`+`Text` de "Regístrate" (línea ~255) **también** pasa a
     `BotonTexto` — no es un `TextButton` hoy, pero es funcionalmente un
     enlace de texto, y así queda con área táctil correcta y color
     WCAG-seguro sin que la tarea 051 tenga que tocar esta línea
     *(resuelve parte del hallazgo 2)*. El botón primario de "Iniciar
     sesión" (con su `_cargando` a mano) → `BotonPrimario` con `cargando:
     _cargando`. El `OutlinedButton` "Crear cuenta" → `BotonSecundario`.
   - `lib/funcionalidades/autenticacion/pantallas/bienvenida_registro_screen.dart`
     — el `GestureDetector`+`Text` de "Inicia sesión" (línea ~114) →
     `BotonTexto` *(resuelve parte del hallazgo 2 — el título "¡Hola!" en la
     misma pantalla NO es un botón y se queda para la tarea 051)*.
   - `lib/funcionalidades/autenticacion/pantallas/registro_trabajador_screen.dart`
     y `registro_empleador_screen.dart` — revisa sus botones de navegación
     entre pasos y el `IconButton` de "atrás" (ya tiene `tooltip` desde la
     049; solo falta pasar por `BotonIcono` si aplica el criterio de tamaño).
   - `lib/funcionalidades/perfil/pantallas/configuracion_screen.dart` —
     los 2 `ElevatedButton.styleFrom(backgroundColor: AppColores.error)`
     (líneas ~41-44, ~83-86 antes de esta tarea) → `BotonDestructivo`.
   - `lib/funcionalidades/trabajos/pantallas/mis_publicaciones_screen.dart` —
     mismos 2 destructivos (líneas ~84-86, ~116-118 antes de esta tarea) →
     `BotonDestructivo`.
   - `lib/funcionalidades/inicio/pantallas/inicio_screen.dart` — destructivo
     (línea ~86-88 antes de esta tarea) → `BotonDestructivo`.
   - `lib/funcionalidades/trabajos/pantallas/widgets/dialogo_reclamar_problema.dart`
     — destructivo (línea ~77-79 antes de esta tarea) → `BotonDestructivo`.
   - `lib/funcionalidades/trabajos/pantallas/widgets/dialogo_cancelar_contratacion.dart`,
     `dialogo_agregar_evidencia.dart`, `dialogo_solicitar_correccion.dart` —
     revisa sus botones (`TextButton`/`ElevatedButton`) y migra a
     `BotonTexto`/`BotonPrimario`/`BotonDestructivo` según corresponda a la
     semántica de cada acción.
   - `lib/funcionalidades/postulaciones/pantallas/mis_postulaciones_screen.dart`
     y `postulantes_screen.dart` — revisa sus botones de acción ("Retirar",
     "Ver perfil", etc.).
   - `lib/funcionalidades/trabajos/pantallas/widgets/tarjeta_trabajo.dart` y
     `tarjeta_mi_publicacion.dart` — los botones con `minimumSize` ajustado en
     la tarea 049 (antes `Size(0,42)`, ahora `Size(0,48)`) → migran al
     componente que corresponda según su semántica (probablemente
     `BotonTexto` o `BotonSecundario`, revisa el texto/acción real).
   - `lib/funcionalidades/perfil/pantallas/widgets/avisos_perfil.dart` — el
     `IconButton` de "Actualizar" (visualDensity ya corregido en la 049) →
     `BotonIcono` con `tooltip: 'Actualizar'`.
   - `lib/funcionalidades/trabajos/pantallas/widgets/barra_busqueda_trabajos.dart`
     — el `IconButton` de filtro → `BotonIcono` con `seleccionado: activo`.
   - `lib/funcionalidades/perfil/pantallas/widgets/cabecera_perfil.dart` —
     revisa su(s) `IconButton`.
   - `lib/funcionalidades/trabajos/pantallas/detalle_trabajo_screen.dart` —
     revisa sus botones de acción (aceptar/rechazar/marcar terminado/reportar
     problema) y sus `IconButton`, si los tiene. Archivo grande (987 líneas,
     excepción viva anotada en ADR-0014): esta migración debe **reducir**
     líneas (delega estilo al componente), no sumarle nada más.
   - `lib/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_cv_trabajador.dart`
     — el botón con `Size(140, 48)` (ajustado en la 049) → el componente que
     corresponda.

   Si al hacer el `grep` aparece algún archivo más con `TextButton`/
   `ElevatedButton.styleFrom`/`IconButton`/`OutlinedButton.styleFrom` que no
   esté en esta lista, mígralo también y anótalo en tu reporte — esta lista
   es de partida, no un techo.

6. **Tests.** Añade `test/compartido/widgets/` con al menos: `BotonPrimario`
   cambia su contenido a spinner cuando `cargando: true` y no dispara
   `onPressed`; `BotonPrimario`/`Secundario`/`Destructivo` con `onPressed:
   null` no disparan nada al tocar; `BotonIcono` sin `tooltip` no compila (o,
   si Dart no lo permite verificar por tipo, un test que confirme que el
   `Tooltip` widget envuelve el ícono con el texto pasado). No hace falta un
   test de pantalla por cada uno de los ~21 archivos migrados — los tests de
   pantalla existentes ya deberían seguir pasando si el comportamiento
   (`onPressed`, texto) no cambió; si alguno se rompe por buscar un
   `find.byType(TextButton)` que ya no existe, actualiza el matcher del test,
   no el comportamiento.

## Qué NO es esta tarea

- No toca el hallazgo 2 (barrido de contraste dorado) salvo los dos casos
  explícitamente marcados arriba como "(resuelve parte del hallazgo 2)" —
  el resto (avatares con inicial, chips de categoría, medallas de ranking,
  el checkbox de términos, el `ChoiceChip` blanco-sobre-dorado) es la tarea
  051, que empieza después de esta.
- No toca el hallazgo 7 (orden de información de `detalle_trabajo_screen.dart`)
  más allá de lo estrictamente necesario para migrar sus botones — no
  reordenes el `Column`.
- No cambia ningún texto visible, ninguna llamada a servicio ni ningún
  contrato de datos — es una migración de estilo/estructura, no de
  comportamiento ni de copy.
- No introduce `Tertiary` con un caso de uso real si no existe hoy — basta
  con que el componente exista y esté documentado.

## Criterios de aceptación

- [x] Los 6 componentes existen en `lib/compartido/widgets/`, cada uno <300
      líneas (se espera bastante menos), con el contrato de props descrito
      arriba.
- [x] `colorAcentoTexto(context)` existe en `colores_por_tema.dart` y
      `colorPrecio()` la reutiliza sin duplicar lógica.
- [x] `boton_continuar_paso.dart` usa `BotonPrimario` por dentro; su API
      pública no cambió (los 8 pasos de registro que lo llaman no se tocan).
- [x] `dialogo_confirmacion.dart` migrado a `BotonTexto`/`BotonDestructivo`.
- [x] Los ~21 archivos listados (o los que resulten del `grep` propio)
      migrados; ningún `ElevatedButton.styleFrom(backgroundColor:
      AppColores.error)` ni `TextButton`/`IconButton` sin pasar por los
      componentes nuevos queda en `lib/funcionalidades/**` salvo excepción
      justificada y anotada en el reporte.
- [x] `flutter analyze` sin errores nuevos; `flutter test` verde (tests
      existentes actualizados si su matcher buscaba el widget de Material
      directo).
- [x] Tests nuevos de los 6 componentes en `test/compartido/widgets/`.
- [x] Ningún archivo Dart de los tocados queda por encima de 300 líneas sin
      que ya estuviera antes y sin que la tarea lo haya *reducido* (si un
      archivo grande gana líneas netas con esta migración, algo salió mal:
      el objetivo es delegar estilo al componente, no añadir código). —
      **Excepción justificada**: `detalle_trabajo_screen.dart` (987→1226
      líneas) es la única que gana líneas netas, y es 100% reformateo de
      `dart format` sobre código no tocado semánticamente, no negocio nuevo.
      Ver detalle en el reporte.
- [x] Reporte en `docs/agent-reports/050-*.md`: lista final de archivos
      migrados, qué componente usó cada uno, y qué casos (si los hubo) se
      dejaron fuera con su justificación.

## Notas del agente que la ejecuta

Cerrada 2026-09-15. Verificado en sesión: `flutter analyze` 12 issues/0
errores (todas preexistentes), `flutter test` 289/289, `grep` de los 4
patrones sobre `lib/funcionalidades/**` da cero resultados. Único hallazgo
pendiente de criterio: el crecimiento neto de `detalle_trabajo_screen.dart`
(+236 líneas), resuelto como excepción justificada — ver
`docs/agent-reports/050-sistema-de-botones.md` para el razonamiento completo
y la recomendación de partir ese archivo en una tarea futura (no en esta,
que prohibía reordenar el `Column`).

Pasa a `en-revision`. Desbloquea la tarea 051.

### Revisión de security-agent (previa al PR #17)

Revisado 2026-09-15 contra `origin/feature/sistema-de-botones` (85bb910) vs
`origin/develop`, en un checkout aparte (detached HEAD, mismo commit), sin
tocar los otros worktrees que ya tenían la rama abierta. Cubre las 7 tareas
apiladas en el PR (036, 037, 039, 041, 043, 049, 050) porque todas viajan
juntas; el foco fue 049/050 por tocar login y diálogos de acción.

**Qué verifiqué:**

- `git diff --stat origin/develop...origin/feature/sistema-de-botones -- backend/ firestore.rules firestore.indexes.json`
  → sin salida. Cero cambios a `backend/**` (ninguno de los dos sistemas de
  auth) ni a las reglas de Firestore. El `TODO` sin resolver de
  `WebSocketConfig` (CONNECT sin validar JWT propio) no lo toca esta rama.
- `login_screen.dart`: diff línea por línea. "Iniciar sesión" sigue llamando
  a `_iniciarSesion` (mismo método); ahora se pasa `onPressed: _iniciarSesion`
  sin ternario porque `BotonPrimario.build()` hace
  `onPressed: cargando ? null : onPressed` — confirmado leyendo
  `boton_primario.dart`: el gateo por `_cargando` se mueve adentro del
  componente pero sigue existiendo, no hay ventana de doble submit. "Crear
  cuenta" (`BotonSecundario`) y "¿Olvidaste tu contraseña?"/"Regístrate"
  (`BotonTexto`) conservan sus callbacks (`_irARegistro`,
  `_recuperarContrasena`) sin cambios de lógica. El diálogo "Entendido" pasa
  de `ElevatedButton` a `BotonPrimario` sin tocar `Navigator.pop`.
- `BotonIcono` (`lib/compartido/widgets/boton_icono.dart`): `tooltip` es
  `required String` (no `String?`), así que un caso nuevo sin tooltip no
  compila — no es un default silencioso. `constraints: BoxConstraints(minWidth:
  48, minHeight: 48)` está fijo dentro de `build()`, sin parámetro expuesto
  para sobrescribirlo (no hay `visualDensity` ni `constraints` en el
  constructor), así que no se puede reducir por accidente desde fuera.
  Confirmé los 9 call sites reales (`git grep BotonIcono\(`) y los 9 pasan un
  `tooltip` real y no vacío.
- Los 5 diálogos de acción (`dialogo_confirmacion.dart`,
  `dialogo_cancelar_contratacion.dart`, `dialogo_reclamar_problema.dart`,
  `dialogo_solicitar_correccion.dart`, `dialogo_agregar_evidencia.dart`) y
  además `postulantes_screen.dart` (`_seleccionar`) y
  `configuracion_screen.dart` (cerrar sesión / dar de baja): en los siete,
  el `Navigator.pop(context, true/false/...)` de cada botón es idéntico
  antes/después del diff — no hubo swap de callbacks entre el botón
  afirmativo y el negativo. La decisión de producto de NO forzar
  `BotonDestructivo` en "Seleccionar" de `postulantes_screen.dart` (una
  acción positiva) se respetó tal como documenta la tarea 049.
- `detalle_trabajo_screen.dart` (el diff más grande, 901 líneas): revisé
  cada `onPressed` reformateado — `_reservarPago`, `_accion(() =>
  _pubService.iniciarTrabajo/aceptarTrabajo/marcarTerminado/...)`,
  `_cancelarContratacion`, `_reclamarProblema`, `_solicitarCorreccion` — el
  cuerpo de cada callback es idéntico, solo cambió el widget contenedor y el
  `dart format`. El único cambio de comportamiento real en este archivo es
  de la tarea 041 (declarada como hotfix, no como 050): "Editar trabajo"
  ahora espera el resultado de `EditarTrabajoScreen` y recarga si
  `guardado == true`; no es un cambio de 049/050 y está fuera del alcance de
  esta revisión puntual, pero no vi nada sensible en él (no toca pagos, solo
  refresca datos tras editar).
- `boton_continuar_paso.dart`: cambio de comportamiento menor y
  autodocumentado en el propio diff — antes, en los pasos 4/5 del registro
  de trabajador, el botón se veía habilitado durante `cargando` (el
  bloqueo real era el `if (_cargando) return` dentro de `_avanzar()`); con
  `BotonPrimario` ahora también se ve deshabilitado durante la carga. Es una
  capa extra de protección contra doble toque, no una pérdida de
  funcionalidad ni una apertura de ventana de reintento — lo doy por
  aceptable y bien señalizado en el docstring del propio archivo.
- Hallazgo 3 de la tarea 049 (`trabajadores_tab.dart`/`ranking_tab.dart` →
  `DetalleTrabajadorScreen`): ambas pestañas usan
  `PerfilService.listarTrabajadores()` → `GET /api/usuarios/ranking`, la
  vista **pública** del backend (sin CV, sin datos personales) según
  ADR-0011. `DetalleTrabajadorScreen` es `StatelessWidget` de solo lectura
  que pinta exactamente el `Usuario` que ya se le pasó — no hace ningún
  fetch adicional ni privilegiado. `postulantes_screen.dart` navega igual
  pero con `obtenerUsuarioPorUid` → `GET /api/usuarios/{id}`, que también
  aplica la vista pública para quien no es el dueño (mismo ADR-0011). No hay
  fuga de datos nueva ni control de acceso más permisivo que el que ya
  existía: es el mismo backend, la misma vista pública, dos rutas de
  frontend distintas hacia la misma pantalla de solo lectura.
- Secretos: `git diff origin/develop...origin/feature/sistema-de-botones |
  grep -inE "api[_-]?key|secret|password|token\s*[:=]|Bearer |AIza|-----BEGIN"`
  solo encontró `token: 't'`/`refreshToken: 'r'` en tests (valores de
  prueba, no reales). Sin secretos en el diff.
- Dependencia nueva (`lucide_icons_flutter`, tarea 043, no 050): justificada
  en ADR-0017 con la comparación de alternativas; no es un riesgo de
  seguridad, la anoto solo por la regla 5 de `CLAUDE.md` (dependencias
  nuevas se justifican).
- Build local en esta sesión (Flutter 3.41.9): `flutter analyze` → 12
  issues, 0 errores, todas preexistentes (mismas rutas/líneas ya conocidas,
  ninguna en archivos que 049/050 tocan salvo el
  `use_build_context_synchronously` ya existente de
  `configuracion_screen.dart`, no introducido por esta rama). `flutter test`
  → 289/289 verdes. Coincide con lo que reportan las "Notas del agente" de
  esta misma tarea.

**Veredicto: APTO.** No encontré cambios de lógica de negocio, de auth, de
control de acceso ni de manejo de dinero escondidos detrás del reestilado.
Los dos desvíos de comportamiento que sí existen (el gateo interno de
`cargando` en `BotonPrimario` y el disabled visual de
`boton_continuar_paso.dart` en los pasos 4/5) son estrictamente más
restrictivos que antes (menos ventana de doble submit, no más), y el
segundo ya viene autodocumentado en el propio diff. No se tocó
`backend/**`, `firestore.rules` ni el WebSocket. No hay secretos en el
diff. Doy el visto bueno para mergear el PR #17 a `develop` en lo que
respecta a seguridad.
