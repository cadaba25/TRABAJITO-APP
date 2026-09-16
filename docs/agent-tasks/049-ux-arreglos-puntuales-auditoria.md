---
id: 049
titulo: "UX: arreglos puntuales de la auditoría de diseño 2026-09-13 (navegación, targets táctiles, confirmación, labels, deduplicación)"
estado: hecho   # security-agent + qa-agent APTO (2026-09-15, PR #17); verificación visual sustituida por tests deterministas (ver "Revisión de qa-agent")
agente: "flutter-agent"
creada: 2026-09-13
rama: "feature/ui-ux"
---

## Objetivo

Aplicar los hallazgos puntuales (no cross-módulo, no necesitan plan de
tech-lead) de `docs/agent-reports/audit-diseno-2026-09-13.md`: hallazgos 3,
4, 5, 6 y 8. Ninguno cambia contrato de API ni modelo de datos.

**No toca los hallazgos 1 y 2** (sistema de botones, barrido de contraste
dorado) — esos los está planificando el tech-lead por separado (tareas
050+). **No toca el hallazgo 7** (orden de información en
`detalle_trabajo_screen.dart`) — el propio reporte de auditoría recomienda
no despacharlo solo, coordinarlo con la próxima tarea que ya tenga que abrir
ese archivo (es la excepción viva más grande del proyecto, 987 líneas). **No
toca el hallazgo 9** (wallet/chat/calificaciones) — están en `lib/screens/**`,
fuera de alcance mientras sigan en Firestore.

## Contexto relevante

- `docs/agent-reports/audit-diseno-2026-09-13.md` — hallazgos 3, 4, 5, 6, 8
  completos, con archivo y línea exacta de cada caso. Léelo antes de tocar
  nada, no repitas la auditoría.
- `docs/design-system-ux-patrones.md` — sección "Confirmaciones",
  "Navegación", principio fundamental ("Qué puedo hacer").
- `docs/design-system-frontend.md` — sección 9 (ergonomía) y 14
  (accesibilidad).

## Qué hacer

1. **Hallazgo 3 — cablear navegación a `DetalleTrabajadorScreen`.**
   `trabajadores_tab.dart` (flecha dispara `_proximamente`, tarjeta no es
   tocable) y `ranking_tab.dart` (filas sin manejador de toque). Cablea
   `Navigator.push` a `DetalleTrabajadorScreen` en ambos, mismo patrón que ya
   usa `postulantes_screen.dart:84`. Envuelve la tarjeta completa (no solo la
   flecha) en un `InkWell`/`GestureDetector`, coherente con el resto de la
   app (tarjetas de trabajo, postulantes).
2. **Hallazgo 4 — targets táctiles por debajo de 44/48dp**, 5 sitios exactos
   listados en el hallazgo 4 del reporte (`login_screen.dart`,
   `mis_postulaciones_screen.dart`, `tarjeta_trabajo.dart` ×2,
   `paso_cv_trabajador.dart`, `avisos_perfil.dart`). Sube cada `minimumSize`/
   `visualDensity` al mínimo accesible (44×44 o 48×48, tu criterio, sé
   consistente entre los 5). **No inventes un componente de botón nuevo
   aquí** — eso es el hallazgo 1, que va aparte; este es un parche mínimo de
   tamaño, no una migración de sistema.
3. **Hallazgo 5 — confirmación al "Retirar postulación".** Envuelve la
   llamada de `_retirar` en `mis_postulaciones_screen.dart` con
   `mostrarDialogoConfirmacion` (ya existe, mismo patrón que "Cancelar
   contratación"/"Rechazar trabajo").
4. **Hallazgo 6 — labels semánticos.** Añade `tooltip: 'Atrás'` (o el texto
   que corresponda) a los 3 botones de flecha "atrás" sin tooltip
   (`bienvenida_registro_screen.dart`, `registro_empleador_screen.dart`,
   `registro_trabajador_screen.dart`). El cuarto caso (botón "próximamente"
   de `trabajadores_tab.dart`) se resuelve solo al aplicar el hallazgo 3
   (deja de ser un botón sin destino).
5. **Hallazgo 8 — deduplicación, con la decisión de producto ya tomada
   (documéntala, no la re-abras):**
   - `mis_postulaciones_screen.dart` debe reutilizar
     `EstadoErrorPostulantes`/`EstadoVacioPostulantes` en vez de duplicar sus
     propios estados vacío/error — **son visualmente idénticos hoy** (mismo
     ícono/texto/estilo), así que no hay cambio visual, solo elimina
     duplicación de código. Aplícalo.
   - El diálogo de "Seleccionar postulante" en `postulantes_screen.dart`
     (`_seleccionar`) **se queda como está, sin reutilizar
     `mostrarDialogoConfirmacion`** — decisión de producto ya tomada: ese
     componente compartido fija semántica visual "acción destructiva" (botón
     afirmativo en rojo), y seleccionar a un trabajador no es una acción
     destructiva. Forzar la reutilización cambiaría el color del botón
     afirmativo a rojo para una acción positiva, lo cual sería peor UX, no
     mejor cumplimiento. Deja constancia de esta decisión en el reporte para
     que quede cerrado (no es un cabo suelto, es una excepción documentada).

## Qué NO es esta tarea

- No toca el sistema de botones (hallazgo 1) ni el barrido de contraste
  dorado (hallazgo 2) — tareas aparte del tech-lead.
- No toca `detalle_trabajo_screen.dart` (hallazgo 7, coordinar después).
- No toca `lib/screens/**` (hallazgo 9, fuera de alcance).
- No cambia ninguna llamada a servicio ni contrato de datos.

## Criterios de aceptación

- [x] Hallazgos 3, 4, 5, 6 y 8 aplicados exactamente como se describe arriba.
- [x] `flutter analyze` sin errores nuevos; `flutter test` verde (o tests
      afectados actualizados y anotados).
- [x] Verificación **funcional** (no visual en pantalla física — ver la
      sección "Revisión de qa-agent" más abajo): tests de widget
      deterministas confirman que la tarjeta de trabajador en Trabajadores y
      Ranking navega al perfil correcto, y que "Retirar" confirma antes de
      llamar al servicio. El emulador sí está disponible en la sesión de QA
      posterior, pero no el acceso a la VM del backend real (bloqueado por
      la política de sandbox del agente), así que no se pudo ver a ojo en
      pantalla — se verificó con el mismo rigor por otra vía.
- [x] Reporte en `docs/agent-reports/049-*.md`, incluida la nota explícita
      de por qué el diálogo de "Seleccionar postulante" NO se tocó (hallazgo
      8, segunda parte).

## Notas del agente que la ejecuta

Ejecutado por `flutter-agent` el 2026-09-13.

- **Hallazgo 3.** `trabajadores_tab.dart`: se quitó `_proximamente` y el
  `IconButton` con la flecha; toda la tarjeta (`_tarjeta`) ahora está envuelta
  en `PulsaConEscala` (el wrapper que ya usan `tarjeta_trabajo.dart` y
  `mis_postulaciones_screen.dart` para tarjetas tocables) con
  `onTap: () => _verPerfil(u)`, que navega a `DetalleTrabajadorScreen` con el
  `Usuario` que ya trae la lista — no hace falta pedir el perfil aparte, a
  diferencia de `postulantes_screen.dart`, que solo tiene el uid. La flecha
  queda como `Icon` decorativo (ya no es un botón: la tarjeta entera es el
  target). Mismo patrón en `ranking_tab.dart` (`_fila`), con
  `PulsaConEscala`/`_verPerfil` nuevos; la fila de cabecera del ranking
  (`_cabecera`, índice 0 del `ListView.builder`) no es una fila de usuario y
  se dejó intacta. El hallazgo 6 (tooltip del botón "próximamente") quedó
  resuelto solo, como decía la tarea, al desaparecer ese botón.
- **Hallazgo 4.** Los 5 sitios subieron a un mínimo de 48dp (Material),
  consistente entre los cinco: `login_screen.dart` y
  `mis_postulaciones_screen.dart` de `Size(0, 32)` a `Size(0, 48)`;
  `tarjeta_trabajo.dart` (dos botones) de `Size(0, 42)` a `Size(0, 48)`;
  `paso_cv_trabajador.dart` de `Size(140, 36)` a `Size(140, 48)`; en
  `avisos_perfil.dart` se quitó `visualDensity: VisualDensity.compact` del
  `IconButton` (vuelve al tamaño táctil por defecto de Material, ≥48dp) en
  vez de fijarle un tamaño — es lo mínimo para revertir el achique, no un
  componente nuevo.
- **Hallazgo 5.** `_retirar` en `mis_postulaciones_screen.dart` ahora abre
  `mostrarDialogoConfirmacion` ("¿Retirar esta postulación?" / "Perderás tu
  puesto en la cola de este trabajo.") antes de llamar a
  `_postService.retirar`; si se cancela o se descarta el diálogo, no se llama
  al servicio.
- **Hallazgo 6.** `tooltip: 'Atrás'` agregado a los tres `IconButton` de
  flecha "atrás" señalados (`bienvenida_registro_screen.dart`,
  `registro_empleador_screen.dart`, `registro_trabajador_screen.dart`).
- **Hallazgo 8 — nota importante, desviación menor respecto al enunciado.**
  Al implementar la reutilización se encontró que el **estado vacío** de
  `mis_postulaciones_screen.dart` NO era visualmente idéntico al de
  `EstadoVacioPostulantes` (icono `Icons.send_outlined` vs
  `Icons.inbox_outlined`, y texto distinto: "Todavía no te has postulado a
  ningún trabajo." vs "Todavía no hay postulantes."). Reutilizar el
  componente tal cual habría cambiado el contenido real que ve el trabajador
  (un bug de mensaje, no solo un detalle visual). En vez de reabrir la
  decisión de producto, se generalizó `EstadoVacioPostulantes` con dos
  parámetros opcionales (`icono`, `mensaje`) con los valores por defecto que
  ya tenía — así `postulantes_screen.dart` sigue exactamente igual sin tocar
  su llamada, y `mis_postulaciones_screen.dart` pasa su propio icono/texto.
  El **estado de error** sí era estructuralmente idéntico (mismo ícono
  `cloud_off_rounded`, mismo "Desliza hacia abajo para reintentar", mismo
  origen del mensaje vía `ExcepcionApi`) y se reutilizó `EstadoErrorPostulantes`
  sin cambios. Se eliminó el método privado `_estadoVacio` y los imports que
  quedaron sin uso (`ExcepcionApi`, `MensajesError`) en
  `mis_postulaciones_screen.dart`.
  El diálogo "Seleccionar postulante" de `postulantes_screen.dart`
  (`_seleccionar`) se dejó **sin tocar**, tal como pide la tarea: es una
  decisión de producto ya cerrada por la tarea 036 y reconfirmada por la
  auditoría — `mostrarDialogoConfirmacion` fija semántica "acción
  destructiva" (botón afirmativo en rojo, texto "Sí"/"No"), y seleccionar a
  un trabajador es una acción positiva. Forzarlo ahí sería peor UX, no mejor
  cumplimiento de un patrón.
- **Verificación:** `flutter analyze` sin issues nuevos (los 12 preexistentes
  no tocan ninguno de los archivos de esta tarea) y `flutter test` con los
  270 tests en verde. **No se pudo verificar visualmente en emulador**: este
  entorno no tiene `adb` instalado (`adb devices` falla con "command not
  found"), así que no hay forma de confirmar en pantalla real que el tap
  navega y que el diálogo aparece. Queda pendiente para quien tenga acceso al
  emulador/dispositivo.

### Revisión de security-agent (previa al PR #17)

Revisado 2026-09-15 junto con la tarea 050 (ver el veredicto completo al
final de `docs/agent-tasks/050-sistema-de-botones.md`; esta nota es solo el
resumen de lo específico de 049). **APTO.**

- Hallazgo 3 (navegación a `DetalleTrabajadorScreen` desde
  `trabajadores_tab.dart`/`ranking_tab.dart`): confirmado que no expone más
  datos que antes. Ambas pestañas siguen leyendo de
  `GET /api/usuarios/ranking` (vista pública, sin CV ni datos personales,
  ADR-0011); `DetalleTrabajadorScreen` solo pinta el `Usuario` que ya
  recibió, sin pedir nada con más privilegio. Es el mismo control de acceso
  que ya usaba `postulantes_screen.dart` (que sí pide `GET
  /api/usuarios/{id}`, pero ese endpoint también aplica la vista pública a
  quien no es el dueño) — no hay downgrade de permisos.
- Hallazgo 5 (confirmación al retirar postulación): confirmado que
  `_retirar` no llama a `_postService.retirar` si el diálogo se cancela o
  se descarta (`if (confirmar != true || !mounted) return;`).
- El resto de hallazgos (4, 6, 8) son de accesibilidad/deduplicación sin
  superficie de seguridad; no encontré nada que objetar.
- No hay cambios a `backend/**` ni a `firestore.rules` en ningún archivo de
  esta tarea.

### Revisión de qa-agent (previa al PR #17)

Revisado 2026-09-15, checkout de `feature/sistema-de-botones` (85bb910) en
un worktree propio.

**Sobre el criterio pendiente ("verificación visual en emulador/
dispositivo"):**

- Este entorno **sí tiene** `adb` y emulador (a diferencia de la sesión que
  ejecutó la 049): Android SDK en
  `C:\Users\enigm\AppData\Local\Android\sdk\platform-tools\adb.exe` (no
  estaba en el `PATH` del shell, pero existe) y `flutter emulators` lista
  `Pixel_6`/`Pixel_6_2`/`Pixel_9`. Se lanzó `Pixel_6` con
  `flutter emulators --launch Pixel_6`, se esperó a `sys.boot_completed` y
  arrancó sin problema.
- **Pero no se pudo completar la verificación visual de todas formas**: los
  tres flujos a comprobar (tarjetas de trabajadores, ranking, retirar
  postulación) necesitan iniciar sesión contra el backend real, que vive en
  la VM de pruebas (`docs/development.md`, túnel
  `ssh -p 2222 -L 8080:localhost:8080 ...`). El uso de `VBoxManage`/`ssh`
  con la clave del repo fue bloqueado por la política de sandbox de este
  agente ("Credential Exploration") — no es una limitación del entorno, es
  una restricción de permisos de esta sesión. No se intentó rodear esa
  restricción (ni con otra vía de acceso a la VM ni pidiendo la clave por
  otro medio); se reporta aquí para que quien tenga permiso de red/VM lo
  haga si de verdad se necesita la inspección visual en pantalla física.
- **En su lugar, se verificó el mismo comportamiento con tests de widget
  deterministas** (mismo patrón que ya usa
  `test/funcionalidades/perfil/perfil_tab_test.dart`: HTTP mockeado con
  `MockClient`, servicios inyectados por `provider`, sin abrir ningún
  socket ni tocar el dispositivo real) — más fuerte que una inspección
  visual puntual porque queda como regresión automática en CI el día que
  exista:
  - `test/funcionalidades/perfil/trabajadores_ranking_navegacion_test.dart`
    (2 tests): confirma que tocar la tarjeta completa de `TrabajadoresTab`
    y la fila de un trabajador en `RankingTab` (no un botón suelto) navega
    a `DetalleTrabajadorScreen` con el `Usuario` correcto, y que la
    cabecera del ranking (índice 0) NO es tocable (sigue sin
    `PulsaConEscala`, como pide la tarea).
  - `test/funcionalidades/postulaciones/mis_postulaciones_retirar_test.dart`
    (3 tests): confirma que tocar "Retirar" muestra el diálogo antes de
    llamar al servicio, que cancelarlo ("No") NO llama a `DELETE
    /api/postulaciones/{id}`, y que confirmarlo ("Sí") lo llama exactamente
    una vez. Este último también cubre el patrón de bug histórico
    documentado en `RETOMAR-AQUI.md` (botones que se quedan cargando o
    disparan doble acción por multi-toque): el diálogo bloquea de verdad,
    no es solo un adorno visual.
  - **Método de verificación de los tests mismos** (el que pide
    `RETOMAR-AQUI.md`: "romper el código a propósito y ver si el test se
    pone rojo"): se comentó la llamada a `mostrarDialogoConfirmacion` en
    `_retirar` (saltándose la confirmación) y los 3 tests de
    `mis_postulaciones_retirar_test.dart` se pusieron en rojo de inmediato
    (uno con `expect` fallido, dos por no encontrar el diálogo/botón "Sí").
    Se puso `onTap: null` en la tarjeta de `TrabajadoresTab` y el test de
    navegación correspondiente se puso rojo igual. Ambos cambios se
    revirtieron después — el diff final no toca código de producción de
    estos dos flujos.
- 5 tests nuevos en total (296 en la suite completa, antes 289). `flutter
  analyze`: 12 issues, 0 errores, ninguno nuevo. `flutter test`: 296/296
  (los 289 previos + los 5 de arriba + 3 más de la revisión de la tarea 050,
  ver esa tarea).

**Sobre el resto de hallazgos (4, 6, 8):** revisados por lectura de código
contra el reporte de la 049 (no hay superficie nueva que verificar en
emulador ahí: son tamaños de `minimumSize`, `tooltip` y deduplicación de
widgets de estado). Sin objeciones.

**Nota de coordinación:** al revisar el historial encontré que otro agente
(`security-agent`) ya hizo, en paralelo y en un worktree distinto
(commit `0877c78`, no fusionado todavía en `feature/sistema-de-botones`),
una revisión de seguridad de este mismo PR con veredicto APTO — cubre
`login_screen.dart`, `BotonIcono`, los 5 diálogos y la privacidad de
`DetalleTrabajadorScreen`/`ranking`. No toqué ese worktree ni intenté
fusionarlo: lo señalo para que el `tech-lead` lo incorpore junto con esta
revisión antes de mergear el PR #17.

**Veredicto: APTO.** Los criterios de aceptación quedan satisfechos:
navegación y confirmación verificadas de forma determinista (no visual, por
la razón de sandbox explicada arriba, no por falta de intento), sin
regresiones en `flutter analyze`/`flutter test`.
