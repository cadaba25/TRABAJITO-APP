---
id: 035
titulo: "Rediseño visual — detalle_trabajo_screen.dart (ADR-0016)"
estado: hecho
agente: "flutter-agent"
creada: 2026-09-11
rama: "feature/rediseno-detalle-trabajo"   # sobre feature/rediseno-trabajos (034)
---

## Objetivo

Aplicar los tokens de la tarea 031 a `detalle_trabajo_screen.dart`
(1 150 líneas — el archivo Dart más grande del proyecto). Tarea aparte de la
034 por su tamaño y porque ADR-0014 ya lo señaló como "una sola clase `State`:
~15 métodos `_widget()`, 6 `AlertDialog` inline, y la máquina de estados del
negocio duplicada en el cliente", dejado a propósito para cuando se migre el
chat (`_reservarPago` todavía lee el acuerdo de pago del chat de Firestore).

**Depende de la 034 (para no chocar si ambas tocan `AppColores`/tokens
compartidos a la vez). No depende de que el chat se migre.**

## Contexto relevante

- ADR-0014, sección 2 de "Contexto" (por qué este archivo está donde está) y
  "Cómo se aplica" (por qué se dejó para la migración del chat).
- ADR-0016, decisión 5 (el techo de 300 sigue vigente; aquí aplica con más
  fuerza que en ningún otro archivo).
- `docs/agent-context/RETOMAR-AQUI.md` — la costura `_reservarPago` con el
  chat de Firestore: no la toques, no es esta tarea.

## Juicio que le toca a quien ejecute esta tarea (documéntalo, no lo evadas)

Este archivo es el candidato más claro para partirse, y esta tarea lo va a
abrir de todas formas para aplicar tokens visuales. La postura de ADR-0016 es
**no forzar** el refactor completo (la máquina de estados y `_reservarPago`
son alcance de la migración del chat, no de un rediseño visual), pero:

- **Los 6 `AlertDialog` inline sí deben salir a sus propios archivos** en
  `pantallas/widgets/` (mismo patrón que el resto de la app desde la 027
  B-2b) — es un cambio de organización de código de bajo riesgo que además
  reduce el archivo de forma real mientras aplicas tokens a cada diálogo.
- **No toques la lógica de la máquina de estados ni las llamadas a
  `PublicacionService`** más allá de mover código literal (extraer un
  `AlertDialog` a un widget que recibe callbacks, sin cambiar qué hace cada
  callback).
- Si tras extraer los diálogos el archivo sigue sobre 300 (es probable — solo
  los diálogos no lo resuelven del todo), **queda como excepción viva
  documentada**, igual que `gestor_sesion.dart` — no es aceptable dejarlo sin
  anotar por qué.

## Qué NO es esta tarea

- No migra el chat ni toca Firestore.
- No cambia la máquina de estados de negocio ni ningún endpoint consumido.
- No resuelve la costura `_reservarPago`.

## Criterios de aceptación

- [x] Tokens de la 031 aplicados en toda la pantalla y en los diálogos
      extraídos.
- [x] Los `AlertDialog` viven en `pantallas/widgets/`, cada uno con su
      propio archivo. **Eran 5, no 6** — ver nota abajo.
- [x] Decisión sobre el tamaño final del archivo, documentada explícitamente
      en el reporte: **excepción viva**, bajó de 1150 a 987 líneas pero
      sigue muy por encima del techo (ver reporte para el razonamiento
      completo).
- [x] `flutter analyze` sin errores nuevos (19 issues, 0 errores, línea base
      sin cambios); `flutter test` verde (261/261, +7 sobre la base de 254).
- [x] Recorrido con test de los estados visibles del trabajo (activo,
      asignado, en progreso, esperando confirmación, en disputa, completado)
      con capturas, claro/oscuro (12 PNG).
- [x] Reporte en `docs/agent-reports/035-rediseno-detalle-trabajo.md`.

## Notas del agente que la ejecuta

- **El archivo tenía 5 `AlertDialog` inline, no 6.** ADR-0014 (tarea 027) y
  el propio encargo de esta tarea repiten "6" de memoria; al abrir el
  archivo y contar `showDialog(` hay cinco: `_solicitarCorreccion`,
  `_reclamarProblema`, `_cancelarContratacion`, `_confirmar` (genérico,
  usado por `_rechazarTrabajo`) y `_agregarEvidencia`. Se extrajeron los
  cinco a `lib/funcionalidades/trabajos/pantallas/widgets/`
  (`dialogo_confirmacion.dart`, `dialogo_solicitar_correccion.dart`,
  `dialogo_reclamar_problema.dart`, `dialogo_cancelar_contratacion.dart`,
  `dialogo_agregar_evidencia.dart`), cada uno con una función
  `mostrarDialogoXxx(context, ...)` que devuelve exactamente lo mismo que
  devolvía el `showDialog` inline (mismo patrón que
  `postularse_sheet.dart`/`mostrarPostularseSheet`). La lógica de negocio
  que rodea a cada diálogo (qué se hace con el motivo, cuándo se valida que
  no esté vacío, qué servicio se llama después) **no se movió ni se
  cambió**: sigue en los mismos métodos privados de
  `_DetalleTrabajoScreenState`, que ahora solo llaman a la función del
  diálogo en vez de construir el `AlertDialog` inline.
- **Decisión sobre el tamaño: excepción viva, documentada, no resuelta.**
  1150 → 987 líneas (-163: los cinco diálogos sumaban ~150 líneas de UI que
  se movieron a sus archivos, más ~15 líneas por unificar las cuatro
  variables locales `oscuro`/`textoPrincipal`/`textoSec`/`superficie`/
  `borde` —repetidas en `_contenido`, `_fila`, `_tarjetaContrato` y
  `_seccionEvidencias`— en llamadas directas a
  `colorTextoFuerte(context)`/`colorTextoSuave(context)`/
  `colorSuperficie(context)`/`colorBorde(context)`). Sigue **muy** por
  encima de 300: quedan la máquina de estados de `_acciones()` (~15 métodos
  `_widget()` contextuales según rol × estado del trabajo) y
  `_reservarPago()` (la costura con el chat de Firestore), que ADR-0014 deja
  explícitamente para la migración del chat — tocarlas aquí habría sido
  hacer esa migración a medias, sin la pieza del backend de chat que la
  sostiene, exactamente lo que la tarea pide no hacer. Se documentó como
  excepción viva en el propio docstring de la clase, igual que
  `gestor_sesion.dart`/`publicacion_service.dart`/`auth_service.dart`.
- **`colorPrecio(context)` (034) no aplicaba aquí.** Se revisó a propósito
  cada lugar donde la pantalla pinta el presupuesto (`_fila`) y el monto
  acordado (`_tarjetaContrato`): los dos siempre usaron el color de texto
  normal (`colorTextoFuerte`), nunca `AppColores.acento` como color de
  texto — el defecto de contraste que corrigió `colorPrecio()` en
  `tarjeta_trabajo.dart`/`tarjeta_mi_publicacion.dart` no existía en este
  archivo. Sí se aplicó `AppTipografia.numero`-equivalente donde tenía
  sentido semántico... en realidad no: se decidió NO forzar el rol `numero`
  (20/w700/tabular) en los montos de esta pantalla porque aparecen
  incrustados en filas compactas (`_fila`/`linea()`), no como una cifra
  destacada de tarjeta; se dejaron en `cuerpoChico` con `fontWeight: w700`
  para no des-balancear esas filas — ver razonamiento completo en el
  reporte.
- **Hallazgo lateral, no corregido (fuera de alcance de esta tarea):** el
  badge de estado (`_badgeEstado`) para `en_progreso`/
  `esperando_confirmacion` sigue pintando `AppColores.dorado` como color de
  texto sobre un fondo con el mismo tono al 15% de opacidad — mismo patrón
  que el chip de categoría en `tarjeta_trabajo.dart` (034), que tampoco se
  tocó. No es el defecto que corrigió `colorPrecio()` (ese era texto sobre
  superficie sólida clara, ~1.63:1); este es texto sobre un tinte muy claro
  del mismo color, un caso distinto que ninguna tarea de ADR-0016 ha
  calculado todavía. Anotado para que QA o una tarea de contraste dedicada
  lo revise, mismo criterio que `onError` en la 031.
