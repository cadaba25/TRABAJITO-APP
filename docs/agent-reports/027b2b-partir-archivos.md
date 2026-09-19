# Tarea 027 · Parte B-2b — Partir los 6 archivos >300 de la B-2

**Rama:** `refactor/funcionalidades-b2b` (sobre `refactor/funcionalidades-b2`, sin
PR). **Agente:** `flutter-agent`. **Fecha:** 2026-09-10.
**Naturaleza:** refactor puro, cero cambios de comportamiento.

## Resultado en una línea

| | Antes (línea base B-2) | Después |
|---|---|---|
| `flutter analyze` | 37 issues, 0 errores | **36 issues, 0 errores** |
| `flutter test` | 194 | **212** (+18 tests de widget nuevos) |
| Archivos de pantalla >300 | 6 | **0** |
| Excepción de tamaño en `datos/` | — | 1 (`publicacion_service`, anotada) |

`analyze` bajó de 37 a 36 al limpiar de paso el `withOpacity` deprecado de
`editar_perfil_screen.dart:260` (estaba dentro del trozo que se movió a
`FormularioEditarPerfil`).

Verificado `flutter analyze` + `flutter test` **después de cada archivo**
(commits autocontenidos, uno por archivo o por archivo+su test).

## Qué salió de cada archivo

Convención: los widgets van a `pantallas/widgets/` de cada funcionalidad. El
estado (`setState`, controladores, futures, paginación, scroll) **se queda en el
`State` de la pantalla**; los hijos reciben datos y `VoidCallback`/`ValueChanged`
por constructor.

### 1. `trabajos/pantallas/trabajos_tab.dart` — 694 → 283

| Pieza | Ruta nueva | Líneas |
|---|---|---|
| `_tarjetaPost` + `_chip` | `widgets/tarjeta_trabajo.dart` (`TarjetaTrabajo`) | 174 |
| `_barraBusqueda` + `_filtroPlazo` | `widgets/barra_busqueda_trabajos.dart` (`BarraBusquedaTrabajos`) | 141 |
| `_abrirFiltros` (hoja inferior) | `widgets/hoja_filtros_trabajos.dart` (`abrirHojaFiltrosTrabajos`, función) | 89 |
| `_encabezado` | `widgets/encabezado_feed.dart` (`EncabezadoFeed`) | 74 |
| `_estadoError`/`_estadoVacio`/`_mensajeVacio`/`_pieDeCarga` | `widgets/estados_feed.dart` (`EstadoErrorFeed`, `EstadoVacioFeed`, `MensajeVacioFeed`, `PieDeCargaFeed`) | 113 |
| `_filtro` (toggle Trabajos / Mis publicaciones) | `widgets/toggle_feed_trabajos.dart` (`ToggleFeedTrabajos`) | 74 |

**Desvío del plan:** el plan listaba 5 cortes; añadí un 6º (`toggle_feed_trabajos`).
Con los 5 el `State` quedaba en ~317 líneas, todavía sobre el techo. El toggle es
una sección de `build` con su propio sub-widget `boton(...)`, encaja en la misma
regla. Con él, 283.

La hoja de filtros salió como **función** (`abrirHojaFiltrosTrabajos`), no como
`StatelessWidget`: es un `showModalBottomSheet` con estado local propio
(`StatefulBuilder`) mientras está abierta y despacha el resultado por callbacks
(`onAplicar(cat, depto)` / `onLimpiar`); el `setState` de los filtros aplicados
lo hace la pestaña.

**Test nuevo:** `test/funcionalidades/trabajos/widgets/tarjeta_trabajo_test.dart`
(4) — chips, rama "Ya te postulaste" vs "Postularme" vs "Ver detalles" según rol,
y que tocar la tarjeta dispara `onAbrir`.

### 2. `perfil/pantallas/perfil_tab.dart` — 520 → 197

| Pieza | Ruta nueva | Líneas |
|---|---|---|
| Cabecera (avatar + rol + estrellas + botón config) | `widgets/cabecera_perfil.dart` (`CabeceraPerfil`) | 87 |
| Botones "Mis publicaciones/postulaciones" + "Cartera" | `widgets/accesos_rapidos_perfil.dart` (`AccesosRapidosPerfil`) | 38 |
| Sección "Información" + secciones por rol + Habilidades | `widgets/info_personal_perfil.dart` (`InfoPersonalPerfil`) | 113 |
| `_avisoSinConexion` + `_avisoCvSinCargar` + `_botonReintentar` | `widgets/avisos_perfil.dart` (`AvisoSinConexionPerfil`, `AvisoCvSinCargar`, `BotonReintentarPerfil`) | 162 |
| `_seccion` + `_tarjeta` + `_fila` (helpers compartidos) | `widgets/piezas_perfil.dart` (`SeccionPerfil`, `TarjetaPerfil`, `FilaPerfil`) | 92 |

Los avisos reciben `recargando` (bool) + `onReintentar` (VoidCallback): cuando
`_recargar` hace `setState(() => _recargando = true)` se reconstruye `PerfilTab`
y los hijos ven el valor nuevo por constructor. `piezas_perfil` lo usan
`InfoPersonalPerfil` y la propia pestaña (sección "Reputación"), por eso quedó
como archivo compartido como sugería el plan.

**Test nuevo:** `test/funcionalidades/perfil/widgets/info_personal_perfil_test.dart`
(3) — rama trabajador (Profesional/Habilidades) vs empleador-empresa
(Empresa/Actividad) y el CV sin cargar que no se pinta a cero. El plan pedía no
tocar las aserciones de `perfil_tab_test.dart`: no se tocaron, los 4 casos pasan
igual (los `find.text('Experiencias')`, `AppTextos.cvSinCargar`, etc. se siguen
renderizando desde `InfoPersonalPerfil`/`AvisoCvSinCargar`).

### 3. `trabajos/datos/publicacion_service.dart` — 366 → 380 (excepción anotada)

**No es pantalla.** Medido: una sola clase, un solo colaborador (`ApiClient`),
**una sola razón para cambiar** (el contrato de `/api/trabajos/**`). Dos tercios
del archivo son docstrings que documentan trampas del backend que no se deducen
(`pagina`/`tamano` en vez de `page`/`size`, `cancelar` exige `reabrir`, reglas de
ADR-0007). Las evidencias (`listarEvidencias`, `agregarEvidencia`) son un
sub-recurso del trabajo (`/api/trabajos/{id}/evidencias`) atado a la máquina de
estados de aquí (ADR-0007: no se entrega sin evidencia); un `evidencia_service`
para dos métodos sería fragmentar sin comprar cohesión — justo lo que ADR-0014
descarta.

**Decisión:** se queda >300 con la excepción **anotada en el docstring de la
clase**, misma categoría que `gestor_sesion.dart` (314) y `auth_service.dart`
(350). El único cambio es ese bloque de docstring (+14 líneas, de ahí 366 → 380);
cero cambio de código, los 31 tests de `trabajos_y_postulaciones_test.dart`
pasan sin tocarlos.

### 4. `postulaciones/pantallas/postulantes_screen.dart` — 361 → 175

| Pieza | Ruta nueva | Líneas |
|---|---|---|
| `_tarjeta` + `_badge` | `widgets/tarjeta_postulante.dart` (`TarjetaPostulante`) | 179 |
| `_cabecera` | `widgets/cabecera_postulantes.dart` (`CabeceraPostulantes`) | 49 |
| `_estadoError` + `_estadoVacio` | `widgets/estados_postulantes.dart` (`EstadoErrorPostulantes`, `EstadoVacioPostulantes`) | 69 |

`TarjetaPostulante` computa sola `esElegido`/`trabajoActivo` (presentación) y
recibe `onVerPerfil`/`onSeleccionar`. El `_seleccionar` con su `AlertDialog` de
confirmación y `ejecutarConCarga` se queda en el `State`.

**Test nuevo:** `test/funcionalidades/postulaciones/widgets/tarjeta_postulante_test.dart`
(5) — badge de estado, marco+check del elegido, botón "Seleccionar" solo con el
trabajo activo, aviso de "sin mensaje", y disparo del callback.

### 5. `perfil/pantallas/editar_perfil_screen.dart` — 359 → 211

| Pieza | Ruta nueva | Líneas |
|---|---|---|
| `_formulario` | `widgets/formulario_editar_perfil.dart` (`FormularioEditarPerfil`) | 164 |
| `_sinPerfilCompleto` | `widgets/aviso_perfil_no_disponible.dart` (`AvisoPerfilNoDisponible`) | 52 |

El formulario recibe los tres controladores, la lista `_habilidades` (que
`EntradaEtiquetas` modifica en el sitio), `cargando`, `esEmpleador`, y los
callbacks `onGuardar`/`onCambiarContrasena`/`onProximamente`. La carga del perfil
completo (`_cargarPerfilCompleto`, hallazgo de la tarea 022), la validación y el
guardado (`_guardar`) se quedan en el `State`. De paso, `withOpacity(0.15)` →
`withValues(alpha: 0.15)` (−1 issue).

**Test nuevo:** `test/funcionalidades/perfil/widgets/formulario_editar_perfil_test.dart`
(3) — rama empleador (sitio web + descripción de empresa) vs trabajador
(habilidades + CV), y "Guardar cambios" desactivado mientras `cargando`. Las
aserciones de `editar_perfil_screen_test.dart` no se tocaron; los 4 casos pasan.

### 6. `trabajos/pantallas/mis_publicaciones_screen.dart` — 357 → 204

| Pieza | Ruta nueva | Líneas |
|---|---|---|
| `_tarjeta` | `widgets/tarjeta_mi_publicacion.dart` (`TarjetaMiPublicacion`) | 162 |
| `_estadoError` + `_estadoVacio` | `widgets/estados_mis_publicaciones.dart` (`EstadoErrorMisPublicaciones`, `EstadoVacioMisPublicaciones`) | 74 |

`TarjetaMiPublicacion` computa sola `sePuedeCerrar` (lista de estados de
ADR-0007) y desactiva el botón "Cerrar" en consecuencia; recibe
`onAbrir`/`onCerrar`/`onEliminar`. Los `AlertDialog` de `_cerrar` y `_eliminar`
(con su rama "Cerrarla" según estado) se quedan en el `State`.

**Test nuevo:** `test/funcionalidades/trabajos/widgets/tarjeta_mi_publicacion_test.dart`
(3) — etiqueta real del estado, rama "Ya no se puede cerrar" con el botón
desactivado, y disparo del callback.

## Tests nuevos — total +18

| Archivo | Casos |
|---|---|
| `test/funcionalidades/trabajos/widgets/tarjeta_trabajo_test.dart` | 4 |
| `test/funcionalidades/trabajos/widgets/tarjeta_mi_publicacion_test.dart` | 3 |
| `test/funcionalidades/postulaciones/widgets/tarjeta_postulante_test.dart` | 5 |
| `test/funcionalidades/perfil/widgets/formulario_editar_perfil_test.dart` | 3 |
| `test/funcionalidades/perfil/widgets/info_personal_perfil_test.dart` | 3 |

Ninguno abre socket ni toca almacenamiento: son `pumpWidget` sobre el widget
suelto con datos y callbacks de mentira.

## Desvíos del plan (resumen)

1. **`trabajos_tab`**: 6 cortes en vez de 5 — el toggle Trabajos/Mis
   publicaciones salió a `toggle_feed_trabajos.dart` para bajar el `State` de
   ~317 a 283. Misma regla (sección de `build` con sub-widget propio).
2. **`hoja_filtros_trabajos`**: función, no `StatelessWidget` — es un
   `showModalBottomSheet` con estado local mientras está abierta.
3. **`publicacion_service`**: no se partió. Medido como CRUD cohesivo con una
   razón para cambiar; excepción anotada en el docstring (como `gestor_sesion` /
   `auth_service`). El plan lo contemplaba explícitamente como salida posible.

## Revisión antes del PR (2026-09-10, tech-lead)

- **Emulador Pixel_6** contra el backend real de la VM: login, feed +
  filtros + toggle (los 6 widgets de `trabajos_tab`), detalle de trabajo,
  y `perfil_tab` completo (cabecera, accesos rápidos, info personal,
  actividad, reputación) renderizan sin fallos. Capturas en el scratchpad
  de la sesión.
- **`security-agent` — APTO.** El ciclo de sesión y los 3 candados de
  renovación no se tocaron (byte-idénticos a B-1); `PerfilService` no tiene
  ninguna ruta al almacén seguro; la DI no crea instancias divergentes; sin
  secretos ni logging nuevo de datos sensibles. Corrección de redacción: la
  frase "única excepción anotada" (`ChatService()` inline) debe leerse
  **"única excepción dentro del conjunto migrado"** — siguen existiendo
  `ChatService()`/`CarteraService()`/`CalificacionService()` inline en
  `lib/screens/` (Firestore, fuera de alcance de B-2/B-2b, previstas para la
  fase 2b-2).
- **`qa-agent` — APTO**, tras romper el código a propósito: los 13 tests de
  perfil movidos son byte-idénticos al original (sin aserciones aguadas);
  `PerfilService` no escribía el almacén ni antes del split (confirmado
  contra `b04a234~1`); dos cortes sin vigilar por mutación — los botones de
  `TarjetaTrabajo` y los mensajes de `estados_feed.dart` — se cerraron con
  **+6 tests** (212→**218**), verificados en rojo antes de la corrección.
  `publicacion_service` sin partir: justificación sostenida al leer el
  archivo completo.
- `flutter analyze`: **36, 0 errores**. `flutter test`: **218**.

## Qué queda para el PR

- ~~Revisión en emulador~~ — hecha.
- ~~`security-agent` / `qa-agent`~~ — hechas, APTO en ambas.
- PR de `refactor/funcionalidades-b2` + `refactor/funcionalidades-b2b` contra
  `develop`.
- Tarea de seguimiento (no bloqueante, hallazgo de `qa-agent`): sin test de
  pantalla `trabajos_tab`/`mis_publicaciones_screen`/`postulantes_screen`,
  así que varias piezas extraídas (`barra_busqueda_trabajos`,
  `hoja_filtros_trabajos`, `toggle_feed_trabajos`, `encabezado_feed`,
  `estados_mis_publicaciones`, `estados_postulantes`,
  `cabecera_postulantes`) quedan sin cobertura transitiva. Las piezas de
  `perfil` sí están cubiertas por `perfil_tab_test`/`editar_perfil_screen_test`.
