---
tarea: 049
titulo: "UX: arreglos puntuales de la auditoría de diseño 2026-09-13"
agente: "flutter-agent"
fecha: 2026-09-13
rama: "feature/ui-ux"
---

# Reporte de cierre — tarea 049

## Qué se hizo

Se aplicaron los hallazgos 3, 4, 5, 6 y 8 de
`docs/agent-reports/audit-diseno-2026-09-13.md`, exactamente como los
describe `docs/agent-tasks/049-ux-arreglos-puntuales-auditoria.md`. No se
tocaron los hallazgos 1, 2, 7 ni 9 (fuera de alcance explícito), ni
`backend/`, ni ningún contrato de servicio/datos.

### Hallazgo 3 — navegación a `DetalleTrabajadorScreen`

- `lib/funcionalidades/perfil/pantallas/trabajadores_tab.dart`: se eliminó
  `_proximamente` (el `SnackBar` de "función disponible próximamente") y el
  `IconButton` de flecha que lo disparaba. Se añadió `_verPerfil(Usuario u)`
  y toda la tarjeta (`_tarjeta`) quedó envuelta en `PulsaConEscala` (el mismo
  wrapper de feedback táctil que ya usan `tarjeta_trabajo.dart` y
  `mis_postulaciones_screen.dart`) con `onTap: () => _verPerfil(u)`. Como la
  lista ya trae objetos `Usuario` completos, no hace falta una petición
  extra — a diferencia de `postulantes_screen.dart`, que solo tiene el uid y
  sí necesita pedir el perfil aparte.
- `lib/funcionalidades/perfil/pantallas/ranking_tab.dart`: mismo patrón en
  `_fila` (fila del ranking). La fila de cabecera (`_cabecera`, índice 0 del
  `ListView.builder`) no es una fila de usuario y no se tocó.
- El hallazgo 6 sobre el botón "próximamente" de `trabajadores_tab.dart`
  quedó resuelto solo, tal como anticipaba la tarea: ese botón ya no existe.

### Hallazgo 4 — targets táctiles

Los 5 sitios subieron a 48dp (Material), consistente entre todos:

- `lib/funcionalidades/autenticacion/pantallas/login_screen.dart`:
  `Size(0, 32)` → `Size(0, 48)` en "¿Olvidaste tu contraseña?".
- `lib/funcionalidades/postulaciones/pantallas/mis_postulaciones_screen.dart`:
  `Size(0, 32)` → `Size(0, 48)` en "Retirar".
- `lib/funcionalidades/trabajos/pantallas/widgets/tarjeta_trabajo.dart`:
  los dos `Size(0, 42)` → `Size(0, 48)`.
- `lib/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_cv_trabajador.dart`:
  `Size(140, 36)` → `Size(140, 48)`.
- `lib/funcionalidades/perfil/pantallas/widgets/avisos_perfil.dart`: se quitó
  `visualDensity: VisualDensity.compact` del `IconButton` de "Actualizar" (no
  se le fijó un tamaño nuevo; sin ese override vuelve al tamaño táctil por
  defecto de Material, ≥48dp). Es el parche mínimo que pide la tarea, no un
  componente nuevo (eso es el hallazgo 1, aparte).

### Hallazgo 5 — confirmar "Retirar postulación"

`_retirar` en `mis_postulaciones_screen.dart` ahora abre
`mostrarDialogoConfirmacion(context, titulo: '¿Retirar esta postulación?',
mensaje: 'Perderás tu puesto en la cola de este trabajo.')` antes de llamar
a `_postService.retirar(p.id)`. Si el usuario cancela o descarta el diálogo,
no se llama al servicio — mismo patrón que "Cancelar contratación"/"Rechazar
trabajo".

### Hallazgo 6 — labels semánticos

Se añadió `tooltip: 'Atrás'` a los tres `IconButton` de flecha "atrás" sin
tooltip: `bienvenida_registro_screen.dart`, `registro_empleador_screen.dart`,
`registro_trabajador_screen.dart`.

### Hallazgo 8 — deduplicación

**Desviación menor respecto al enunciado de la tarea, documentada aquí a
propósito.** Al implementar la reutilización se encontró que el *estado
vacío* de `mis_postulaciones_screen.dart` **no era visualmente idéntico** al
de `EstadoVacioPostulantes`:

| | Icono | Texto |
|---|---|---|
| `mis_postulaciones_screen.dart` (antes) | `Icons.send_outlined` | "Todavía no te has postulado a ningún trabajo." |
| `EstadoVacioPostulantes` (antes) | `Icons.inbox_outlined` | "Todavía no hay postulantes." |

Reutilizar el componente tal cual habría sido un bug de contenido real (un
trabajador viendo "no hay postulantes" en su propia lista de postulaciones),
no solo un detalle visual — contradice la premisa de "sin cambio visual" del
enunciado de la tarea. En vez de reabrir la decisión de producto o dejar la
duplicación, se generalizó
`lib/funcionalidades/postulaciones/pantallas/widgets/estados_postulantes.dart`
con dos parámetros opcionales en `EstadoVacioPostulantes` (`icono`,
`mensaje`), con los valores por defecto que ya tenía. Así:

- `postulantes_screen.dart` sigue exactamente igual, sin tocar su llamada
  (`EstadoVacioPostulantes(oscuro: oscuro)` sigue mostrando lo mismo de
  siempre).
- `mis_postulaciones_screen.dart` pasa su propio `icono`/`mensaje` y
  conserva su contenido actual, solo que ahora comparte la estructura visual
  (layout, estilo de texto) en vez de duplicarla.

El **estado de error** sí era estructuralmente idéntico (mismo ícono
`cloud_off_rounded`, mismo "Desliza hacia abajo para reintentar", mismo
origen del mensaje vía `ExcepcionApi`/`MensajesError.errorGeneral`) y se
reemplazó directamente por `EstadoErrorPostulantes`, sin cambios en el
componente. Se eliminó el método privado `_estadoVacio` de
`mis_postulaciones_screen.dart` y los imports que quedaron sin uso
(`ExcepcionApi`, `MensajesError`).

**Por qué el diálogo "Seleccionar postulante" de `postulantes_screen.dart`
(`_seleccionar`) NO se tocó — nota explícita pedida por la tarea:** es una
decisión de producto ya tomada por la tarea 036 y reconfirmada por esta
auditoría (hallazgo 8, segunda parte). `mostrarDialogoConfirmacion` fija una
semántica visual de "acción destructiva": botón afirmativo en rojo, textos
"Sí"/"No". Seleccionar a un trabajador es una acción **positiva**, no
destructiva; forzar la reutilización ahí pintaría de rojo un botón de
confirmación de algo bueno, lo cual sería peor UX, no mejor cumplimiento de
un patrón. Se deja como excepción documentada, no como cabo suelto.

## Archivos tocados

- `lib/funcionalidades/perfil/pantallas/trabajadores_tab.dart`
- `lib/funcionalidades/perfil/pantallas/ranking_tab.dart`
- `lib/funcionalidades/postulaciones/pantallas/mis_postulaciones_screen.dart`
- `lib/funcionalidades/postulaciones/pantallas/widgets/estados_postulantes.dart`
- `lib/funcionalidades/autenticacion/pantallas/login_screen.dart`
- `lib/funcionalidades/trabajos/pantallas/widgets/tarjeta_trabajo.dart`
- `lib/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_cv_trabajador.dart`
- `lib/funcionalidades/perfil/pantallas/widgets/avisos_perfil.dart`
- `lib/funcionalidades/autenticacion/pantallas/bienvenida_registro_screen.dart`
- `lib/funcionalidades/autenticacion/pantallas/registro_empleador_screen.dart`
- `lib/funcionalidades/autenticacion/pantallas/registro_trabajador_screen.dart`
- `docs/agent-tasks/049-ux-arreglos-puntuales-auditoria.md` (notas y
  criterios de aceptación)

Ningún archivo supera las 300 líneas (`ranking_tab.dart` queda exacto en
300, el resto por debajo).

## Qué se probó

- `flutter analyze`: 12 issues, todos preexistentes y en archivos que esta
  tarea no tocó (verificado línea por línea contra la salida). Cero errores
  o warnings nuevos.
- `flutter test`: **270 tests, todos en verde.** No se modificó ni se borró
  ningún test existente; no hizo falta actualizar ninguno porque ninguno de
  los tres archivos de pantalla tocados (`trabajadores_tab.dart`,
  `ranking_tab.dart`, `mis_postulaciones_screen.dart`) tenía cobertura de
  widget previa (confirmado con `Glob` sobre `test/funcionalidades/perfil/**`
  y `test/funcionalidades/postulaciones/**`).
- **No se agregaron tests de widget nuevos para el comportamiento cambiado**
  (tap-para-navegar, diálogo de confirmación). Es una deuda preexistente
  (estas tres pantallas ya no tenían cobertura antes de esta tarea) que esta
  tarea no cierra por su alcance puntual; queda anotado aquí para que quede
  explícito y no se lea como "ya probado".
- **Verificación visual: NO realizada.** Este entorno no tiene `adb`
  instalado (`adb devices` → `command not found`), así que no hay forma de
  levantar el emulador ni confirmar en pantalla que el tap navega al perfil
  correcto en "Trabajadores"/"Ranking" ni que el diálogo de "Retirar
  postulación" aparece como se espera. Queda pendiente para quien tenga
  acceso a un emulador/dispositivo — la lógica se revisó por lectura de
  código y los tests automatizados existentes siguen en verde, pero eso no
  sustituye la comprobación visual pedida por la tarea.

## Qué queda pendiente

1. Verificación visual en emulador de los tres flujos tocados (tap en
   tarjeta de trabajador → perfil correcto en Trabajadores y en Ranking;
   diálogo de confirmación al retirar postulación).
2. Cobertura de widget nueva para `trabajadores_tab.dart`, `ranking_tab.dart`
   y `mis_postulaciones_screen.dart` (deuda preexistente, no introducida por
   esta tarea, pero que sigue sin cerrarse).
3. Hallazgos 1, 2 y 7 de la auditoría, fuera de alcance de esta tarea por
   diseño (necesitan plan del `tech-lead` o coordinación con la próxima
   tarea que abra `detalle_trabajo_screen.dart`).
