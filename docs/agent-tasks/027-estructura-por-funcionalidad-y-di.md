---
id: 027
titulo: "Reestructurar lib/ por funcionalidad, inyección de dependencias y techo de tamaño por archivo"
estado: en-progreso   # A, B-1, B-2 y B-2b hechas; falta el PR a develop (revisión emulador B-2+B-2b)
agente: "flutter-agent"
creada: 2026-09-08
rama: "refactor/estructura-por-funcionalidad" (A) · "refactor/base-compartida" (B-1) · "refactor/funcionalidades-b2" (B-2, sin PR aún)
---

## Origen

Encargo directo del dueño del proyecto (2026-09-08):

> *"no quiero que el proyecto este trabajado en un solo archivo ej.
> «app.dart» con 20mil lineas de codigo, quiero que programes de una manera
> donde se le pueda dar mantenimiento y sea super escalable"*

El diseño y las alternativas descartadas están en **ADR-0014**, escrito antes
de esta tarea. **Léelo entero antes de tocar nada.** Aquí solo está el
trabajo concreto.

## Lo que NO es esta tarea

- **No se toca el backend.** Está medido y sano (65 líneas/archivo de media).
- **No se implementa Clean Architecture** de cuatro capas. Está descartada en
  el ADR con su porqué; si crees que te hace falta, para y dilo, no la metas.
- **No se migra ningún servicio de Firestore aquí.** Eso es la fase 2b-2 y va
  después, ya sobre la estructura nueva.
- **No se cambia el comportamiento de la app.** Al terminar, un usuario no
  debe notar absolutamente nada. Es un refactor puro.

## Alcance, en dos partes

### Parte A — Cimientos (hazla primero y entera)

1. **Añadir `provider`** a `pubspec.yaml`. Es la única dependencia nueva
   autorizada; está justificada en el ADR.
2. **Partir `lib/utils/constantes.dart`** (605 líneas, 15 clases sin
   relación). Reparto propuesto — ajústalo si al abrirlo ves algo mejor, y
   explica por qué en el reporte:
   - `nucleo/tema/` → `AppColores`, `AppTema`, `notificadorTema`
   - `nucleo/textos/` → `AppTextos`, `MensajesError`
   - `compartido/datos/` → `DatosHonduras`, `DatosEmpleador`
   - `nucleo/dominio/` → `EstadosTrabajo`, `EstadosPostulacion`,
     `TiposMensaje`, `MapeoEnumApi`, `RolesApi`, `CamposUsuario`,
     `ValoresDefecto`, `ReglasCuenta`
   - `FirestoreColecciones` → déjalo donde menos estorbe y **marca con un
     comentario que muere en la fase 3**.
3. **Crear el esqueleto de carpetas** de ADR-0014 y **mover una sola
   funcionalidad completa** como piloto: **`autenticacion`**. Es la que ya
   está migrada al backend y la que más test tiene, así que si algo se
   rompe, se nota.
4. **Registrar los servicios con `provider`** en el arranque, y hacer que las
   pantallas de `autenticacion` los reciban por inyección en vez de
   construirlos. `ApiClient.instancia` ya tiene `fijarInstancia()` para los
   tests — respeta ese mecanismo, no lo dupliques.

### Parte B — La base compartida primero, luego el resto

> **Orden corregido el 2026-09-08.** El plan original decía "mueve otra
> funcionalidad". Está **mal**, y lo demostró el agente que hizo la parte A:
> las pantallas de `autenticacion` dependen de `lib/widgets/` y su servicio de
> `lib/services/api/`, así que mover funcionalidades antes que la base deja
> imports como `../../../widgets/custom_textfield.dart`. **La base va
> primero.** El error era del plan, no de quien lo ejecutó.

**B-1 — La base compartida (haz esto antes que nada): HECHA el 2026-09-08.**
Ver `docs/agent-reports/027b1-base-compartida.md`. `api_client.dart` acabó
partido en cuatro (`api_client` 260 / `transporte_http` 172 / `gestor_sesion`
314 / `guardia_escrituras` 95) y `custom_textfield.dart` en siete widgets más
`nucleo/tema/colores_por_tema.dart`. La API de `fijarInstancia` y los tres
candados **no se tocaron**; se comprobó por mutación que sus tests siguen
vigilándolos. `gestor_sesion.dart` se queda en 314 líneas a propósito
(justificado en el reporte).

1. `lib/services/api/` → `lib/nucleo/api/`. `api_client.dart` son **649
   líneas** y hay que partirlo al moverlo, no después. Candidatos de corte
   evidentes: la lógica de renovación con sus tres candados, el almacén de
   sesión, y el envío HTTP. **Cuidado**: los tres candados están documentados
   en el docstring de la clase y hay ~60 tests que dependen de
   `ApiClient.fijarInstancia`. Si el corte obliga a tocar esa API, **para y
   dilo** en vez de cambiarla.
2. `lib/widgets/` → `lib/compartido/widgets/`. `custom_textfield.dart` son
   **407 líneas** y casi seguro contiene varios widgets en un archivo:
   sepáralos, uno por archivo.

**B-2 — Las funcionalidades ya migradas al backend:**

Mueve `trabajos`, `postulaciones` y `perfil` a la estructura nueva, y **cierra
la anomalía que dejó la parte A**: hay dos instancias de `AuthService` vivas
porque 7 pantallas siguen construyendo la suya. Al terminar B-2 no debe quedar
ni un `final _x = AlgunService();` dentro de un `State`. (Verificado en la
parte A que no rompe nada hoy: el estado de sesión vive en el singleton global
`sesionActual`, no en la instancia; lo único por instancia es
`ultimoErrorPorCampo`, que son mensajes de validación de formulario.)

**`cartera`, `calificacion` y `chat` NO se mueven en esta tarea**: nacen
directamente en la estructura nueva cuando se migren (fase 2b-2). Crear sus
carpetas vacías ahora solo genera ruido.

**`detalle_trabajo_screen.dart` (1 143 líneas) y los registros (1 914) NO se
parten aquí.** El ADR lo dice: se parten cuando haya que abrirlos por otra
razón (el chat y la tarea 012 respectivamente). Partirlos ahora es un diff
enorme sin nada que lo verifique.

---

### B-2 — plan detallado (2026-09-09, decisiones del dueño vía tech-lead)

**Rama:** `refactor/funcionalidades-b2`. **Agente:** `flutter-agent`.
**Naturaleza:** refactor puro, cero cambios de comportamiento. Verificación
final en emulador `Pixel_6`.

#### Tres decisiones tomadas

1. **`AuthService` se parte en dos.** Hoy son 487 líneas con dos razones para
   cambiar: sesión (login, registro, logout, `restaurarSesion`,
   `escucharFinDeSesion`, `vigilarEscriturasSinConexion`, `darDeBajaCuenta`)
   y perfil/usuarios (`recargarPerfil`, `actualizarCampos`,
   `obtenerUsuarioPorUid`, `obtenerUsuarioActual`, `listarTrabajadores`,
   `reemplazarHabilidades`, `agregarExperiencia`, `agregarEstudio`).
   - `AuthService` se queda en `funcionalidades/autenticacion/datos/` con lo
     de sesión + registro + baja de cuenta (la baja es acción de cuenta, no
     de perfil).
   - **`PerfilService` nace** en `funcionalidades/perfil/datos/perfil_service.dart`
     con lo de perfil/usuarios. Comparte `ApiClient.instancia` igual que
     `AuthService` (mismo patrón de constructor con `{ApiClient? cliente}`).
   - Cuidado con `restaurarSesion()` / `_pedirPerfilPropio()` /
     `_guardarSesionDesde()`: el guardado de la sesión y del `Usuario` en el
     almacén es de `AuthService`. `PerfilService.recargarPerfil()` hoy
     también reescribe la sesión guardada tras `GET /api/auth/yo` — mantener
     esa responsabilidad donde esté hoy y **no duplicar** la escritura del
     almacén. Si el corte obliga a que `PerfilService` escriba el almacén de
     sesión, **para y dilo**: puede que `recargarPerfil` deba quedarse en
     `AuthService` y solo mudarse los métodos de CV y listados.
   - `auth_service_test.dart` (30 casos) se divide: los de perfil/CV/listados/
     perfil ajeno pasan a `test/funcionalidades/perfil/perfil_service_test.dart`.

2. **Los archivos >300 líneas se MUEVEN tal cual en B-2, con excepción
   anotada, y se parten en un PR aparte (B-2b).** Afecta a: `trabajos_tab`
   (693), `perfil_tab` (517), `publicacion_service` (366), `editar_perfil`
   (356), `mis_publicaciones` (356), `postulantes` (360). B-2 es «mover y
   cablear `provider`» — mecánico y verificable. B-2b los parte por
   responsabilidad. Anotar las 6 excepciones temporales en el reporte de B-2.

3. **Los modelos van a `lib/compartido/modelos/`.** `Usuario`, `Publicacion`,
   `Postulacion`, `Chat`, `Calificacion`, `Evidencia`, `Tarjeta`,
   `json_utiles.dart`. Son transversales (p. ej. `Publicacion` la usan
   trabajos, postulaciones y chat); meterlos en una feature acoplaría las
   demás. `json_utiles` es infraestructura de serialización compartida.

#### Reparto de archivos por funcionalidad

`lib/funcionalidades/trabajos/`
- `datos/publicacion_service.dart`  ← `lib/services/`
- `pantallas/trabajos_tab.dart`  ← `lib/screens/tabs/`
- `pantallas/detalle_trabajo_screen.dart`  (excepción de tamaño ya anotada)
- `pantallas/publicar_trabajo_screen.dart`
- `pantallas/editar_trabajo_screen.dart`
- `pantallas/mis_publicaciones_screen.dart`

`lib/funcionalidades/postulaciones/`
- `datos/postulacion_service.dart`  ← `lib/services/`
- `pantallas/mis_postulaciones_screen.dart`
- `pantallas/postulantes_screen.dart`
- `pantallas/postularse_sheet.dart`

`lib/funcionalidades/perfil/`
- `datos/perfil_service.dart`  (nuevo, salido de `AuthService`)
- `pantallas/perfil_tab.dart`  ← `lib/screens/tabs/`
- `pantallas/editar_perfil_screen.dart`
- `pantallas/ranking_tab.dart`
- `pantallas/trabajadores_tab.dart`
- `pantallas/configuracion_screen.dart`
- `pantallas/detalle_trabajador_screen.dart`  (es perfil de solo lectura de
  un trabajador; hoy vive en `screens/` y lo abre `postulantes_screen`)

`lib/funcionalidades/inicio/`
- `pantallas/inicio_screen.dart`  ← `lib/screens/`. Es el `Scaffold`
  post-login con las 5 pestañas y el badge de no leídos. **Puede seguir
  importando `chats_tab` desde `lib/screens/tabs/`** hasta que se migre el
  chat (fase 2b-2). `main.dart` y `test/pantalla_inicial_test.dart` apuntan
  aquí.

**Se quedan en `lib/screens/` (dependen de Firestore, se mueven en 2b-2):**
`chat_screen.dart`, `cartera_screen.dart`, `calificar_sheet.dart`,
`tabs/chats_tab.dart`. Y `firestore_colecciones.dart` +
`chat_service`/`cartera_service`/`calificacion_service` en `lib/services/`.

#### Cierre de la anomalía de DI

`proveedoresDeLaApp()` gana un parámetro `PerfilService? perfil` y registra
`Provider<PerfilService>`. Las pantallas dejan de construir servicios:

| Archivo | Cambio |
|---|---|
| `inicio_screen.dart` | `final _authService = AuthService()` → `late final _authService = context.read<AuthService>()` |
| `perfil_tab.dart`, `ranking_tab.dart`, `trabajadores_tab.dart` | `AuthService()` → `context.read<PerfilService>()` |
| `editar_perfil_screen.dart` | `_auth = AuthService()` → `context.read<PerfilService>()` |
| `configuracion_screen.dart` | 3 llamadas inline `AuthService().x()` → leer `AuthService` una vez en el `State` (`cerrarSesion`, `darDeBajaCuenta`, `enviarVerificacionCorreo`) |
| `postulantes_screen.dart` | `PostulacionService()`, `PublicacionService()`, `AuthService()` (usa `obtenerUsuarioPorUid` → `PerfilService`) → los tres por `context.read` |
| `trabajos_tab.dart` | `PublicacionService()`, `PostulacionService()` → `context.read` |
| `detalle_trabajo_screen.dart` | `PublicacionService()`, `PostulacionService()` → `context.read`. `ChatService()` inline (línea ~638) **se queda** (Firestore, sin migrar) pero se deja anotado |
| `publicar_trabajo_screen.dart`, `editar_trabajo_screen.dart`, `mis_publicaciones_screen.dart` | `PublicacionService()` → `context.read` |
| `mis_postulaciones_screen.dart` | `PostulacionService()`, `PublicacionService()` → `context.read` |
| `postularse_sheet.dart` | `PostulacionService()` → `context.read` |

Patrón a usar: el mismo de las pantallas de `autenticacion` —
`late final X _x = context.read<X>();`— salvo cuando se necesita en un
`initState`/inicializador de campo (`ranking_tab`, `trabajadores_tab` lanzan
la carga en la declaración del campo): en esos, mover la carga a
`didChangeDependencies` con guarda, o a `initState` leyendo con
`context.read` (válido en `initState` con `provider`).

`ChatService` y `CalificacionService`/`CarteraService` **no** entran en
`provider` todavía (siguen en Firestore; entran al migrarse).

#### Orden de commits (ADR-0014: mover y editar van separados)

1. `git mv` de modelos a `compartido/modelos/` + arreglar imports. `analyze`.
2. `git mv` de `trabajos` + imports. `analyze`.
3. `git mv` de `postulaciones` + imports. `analyze`.
4. `git mv` de las pantallas de `perfil` + `inicio_screen` + imports.
   `analyze`.
5. Partir `AuthService` → `AuthService` + `PerfilService` (cambio de código).
   Tests divididos.
6. Cablear `provider`: `proveedoresDeLaApp()` + pantallas dejan de construir
   servicios. Actualizar helpers de test.
7. Mover los archivos de test a `test/funcionalidades/<feature>/` + imports.

Correr `flutter analyze` **después de cada commit de movimiento**, no al
final. `flutter test` verde antes del PR (194, o +los que sумen los tests de
perfil divididos, si añaden alguno).

#### Qué NO hace B-2

- No parte ningún archivo por tamaño (eso es B-2b).
- No toca `detalle_trabajo_screen` ni los registros salvo el cambio mecánico
  de `context.read`.
- No mueve `chat`/`cartera`/`calificacion` ni sus pantallas.
- No cambia una sola regla de negocio ni un contrato de API.

#### B-2 — resultado (2026-09-09, rama `refactor/funcionalidades-b2`, sin PR)

Refactor puro. `flutter analyze`: 37 issues, 0 errores (idéntico a la línea
base tras cada uno de los 6 commits). `flutter test`: 194.

- **Modelos** → `lib/compartido/modelos/` (los 7 + `json_utiles.dart`).
- **`trabajos`, `postulaciones`, `perfil`, `inicio`** → `lib/funcionalidades/`.
  En `lib/screens/` quedan solo `calificar_sheet`, `cartera_screen`,
  `chat_screen`, `tabs/chats_tab`; en `lib/services/` solo
  `chat`/`calificacion`/`cartera`_service + `firestore_colecciones`.
- **`AuthService` partido** → `AuthService` (sesión + registro + baja) +
  `PerfilService` (`funcionalidades/perfil/datos/`). El corte **no obligó a
  que `PerfilService` escriba el almacén de sesión**: la premisa del plan
  ("`recargarPerfil` reescribe la sesión guardada") no se cumplía en el
  código — `recargarPerfil` solo llama a `SesionUsuario.actualizarPerfil`
  (perfil en memoria), que ya era responsabilidad compartida vía el singleton
  `sesionActual`. Sin duplicación, sin escritura del almacén. `auth_service.dart`
  bajó de 487 a 350 líneas (sigue >300 por docstrings de ADR-0013 y renovación).
- **DI cerrada**: `proveedoresDeLaApp()` gana `PerfilService`; ninguna pantalla
  construye ya un servicio dentro de un `State`. Única excepción anotada:
  `ChatService()` inline en `detalle_trabajo_screen.dart` (~línea 640, Firestore).
- **Desvío del plan**: las dos pantallas de registro (1 042 y 920 líneas)
  llaman métodos de perfil (`actualizarCampos`, `agregarExperiencia`…) para
  completar el CV tras crear la cuenta — el plan B-2 no lo previó en su tabla
  de DI. Solución: reciben **además** `PerfilService` por inyección (unos 8
  renglones cada una; **no** se parten los archivos).
- **6 archivos >300 movidos tal cual** (excepción temporal, se parten en
  **B-2b**): `trabajos_tab` (694), `perfil_tab` (520), `publicacion_service`
  (366), `postulantes_screen` (361), `editar_perfil_screen` (359),
  `mis_publicaciones_screen` (357).
- **Tests**: `auth_service_test.dart` 30 → 17; nace
  `test/funcionalidades/perfil/perfil_service_test.dart` (13).
  `editar_perfil_screen_test` + `perfil_tab_test` → `test/funcionalidades/perfil/`;
  `trabajos_y_postulaciones_test` → `test/funcionalidades/trabajos/`.
  `registro_empleador_screen_test`: `AuthServiceFalso` + `PerfilServiceFalso`
  con una `Grabadora` compartida para seguir afirmando el orden de llamadas.

### B-2b — plan detallado (2026-09-10, tech-lead)

**Rama:** `refactor/funcionalidades-b2b` (parte de `refactor/funcionalidades-b2`,
aún sin fusionar a `develop`; el PR de B-2b se retoma sobre `develop` cuando
B-2 entre). **Agente:** `flutter-agent`. **Naturaleza:** refactor puro, cero
cambios de comportamiento. Verificación: `flutter analyze` (no sube de 37) +
`flutter test` (194) tras **cada** archivo. Emulador **no** es requisito de
B-2b (lo cubrió B-1; B-2/B-2b se revisan juntas en emulador antes del PR a
`develop`).

**Regla de corte:** una pantalla hace layout y despacha eventos (ADR-0014
punto 4). Las secciones grandes del `build` y los diálogos/hojas salen a su
propio archivo bajo `pantallas/widgets/` de la funcionalidad. **No se toca
ni una regla de negocio ni una llamada de servicio** — solo se mueve árbol
de widgets y se pasan callbacks/estado por parámetro. `git mv` no aplica
(son archivos nuevos); el commit de cada archivo es autocontenido.

| Archivo (líneas) | Corte propuesto |
|---|---|
| `trabajos/pantallas/trabajos_tab.dart` (694) | `widgets/tarjeta_trabajo.dart` (`_tarjetaPost`+`_chip`, ~130 l), `widgets/barra_busqueda_trabajos.dart` (`_barraBusqueda`+`_filtroPlazo`, ~90 l), `widgets/hoja_filtros_trabajos.dart` (`_abrirFiltros`, ~80 l), `widgets/encabezado_feed.dart` (`_encabezado`, ~55 l), `widgets/estados_feed.dart` (`_estadoError`/`_estadoVacio`/`_mensajeVacio`/`_pieDeCarga`, ~90 l). El `State` conserva carga/paginación/scroll y compone. |
| `perfil/pantallas/perfil_tab.dart` (520) | El `build` es un `ListView` de ~240 l con secciones inline. Sacar: `widgets/cabecera_perfil.dart` (avatar+rol+estrellas), `widgets/accesos_rapidos_perfil.dart` (botones Mis publicaciones/postulaciones + Cartera), `widgets/info_personal_perfil.dart` (filas de datos + CV/empresa), `widgets/avisos_perfil.dart` (`_avisoSinConexion`+`_avisoCvSinCargar`+`_botonReintentar`). Dejar `_seccion`/`_tarjeta`/`_fila` como helpers compartidos en `widgets/piezas_perfil.dart` si los usan varios. |
| `trabajos/datos/publicacion_service.dart` (366) | **No es pantalla**: aquí el techo se justifica si la clase tiene una sola razón para cambiar (CRUD de publicaciones contra la API). Medir primero: si `evidencias` (subir/listar avances) o el mapeo de escrow/estado vive aquí y es separable, sacar `evidencia_service.dart` a `trabajos/datos/`. Si es CRUD cohesivo, **se queda >300 con excepción anotada** (como `gestor_sesion` / `auth_service`). Decidir leyéndolo, no a ciegas. |
| `postulaciones/pantallas/postulantes_screen.dart` (361) | `widgets/tarjeta_postulante.dart` (`_tarjeta`+`_badge`, ~130 l), `widgets/cabecera_postulantes.dart` (`_cabecera`, ~30 l), `widgets/estados_postulantes.dart` (`_estadoError`/`_estadoVacio`). |
| `perfil/pantallas/editar_perfil_screen.dart` (359) | `widgets/formulario_editar_perfil.dart` (`_formulario`, el grueso), `widgets/aviso_perfil_no_disponible.dart` (`_sinPerfilCompleto`+`_reintentarPerfil`). El `State` conserva carga de perfil, validación y guardado. |
| `trabajos/pantallas/mis_publicaciones_screen.dart` (357) | `widgets/tarjeta_mi_publicacion.dart` (`_tarjeta`, ~130 l), `widgets/estados_mis_publicaciones.dart` (`_estadoError`/`_estadoVacio`). |

**Tests:** los widgets extraídos que tengan lógica de presentación no trivial
(badges de estado, tarjetas con ramas según rol/estado) ganan un test de
widget mínimo. Los tests de pantalla existentes (`perfil_tab_test`,
`editar_perfil_screen_test`, `trabajos_y_postulaciones_test`) **no cambian de
aserción**: si el `find` deja de encontrar algo por estar en otro archivo, es
que el corte cambió comportamiento — hay que arreglarlo, no el test.

**Trampas:** `perfil_tab` y `trabajos_tab` usan `setState` desde callbacks de
sus secciones — esos callbacks se pasan como `VoidCallback`/`ValueChanged`
al widget hijo, el estado **no** se mueve. `colorTextoFuerte(context)` y
compañía son de `nucleo/tema/colores_por_tema.dart`, no se duplican.

**Criterio de terminado B-2b:** ningún archivo nuevo o tocado >300 líneas
(salvo excepción explícita y justificada en el reporte, como puede ser
`publicacion_service`), 37 issues / 194 tests, y reporte en
`docs/agent-reports/027b2b-*.md` con qué salió de cada archivo y por qué.

#### B-2b — resultado (2026-09-10, rama `refactor/funcionalidades-b2b`, sin PR)

Refactor puro. `flutter analyze`: **36 issues, 0 errores** (bajó de 37 al limpiar
un `withOpacity` deprecado en `editar_perfil_screen`). `flutter test`: **212**
(+18 tests de widget). Verificado analyze + test tras **cada** archivo; un commit
autocontenido por archivo. Detalle en `docs/agent-reports/027b2b-partir-archivos.md`.

- **5 pantallas partidas** por responsabilidad, todas ≤300:
  `trabajos_tab` 694→**283**, `perfil_tab` 520→**197**,
  `postulantes_screen` 361→**175**, `editar_perfil_screen` 359→**211**,
  `mis_publicaciones_screen` 357→**204**. Las secciones grandes de `build`, las
  tarjetas, los estados y las hojas/diálogos salieron a
  `funcionalidades/<feature>/pantallas/widgets/`. El estado (`setState`,
  controladores, futuros, paginación, scroll) **se quedó en el `State`**; los
  hijos reciben datos y `VoidCallback`/`ValueChanged` por constructor.
- **`publicacion_service.dart` NO se partió** (366→380): CRUD cohesivo contra
  `/api/trabajos/**`, una sola razón para cambiar, dos tercios docstrings de
  contrato; las evidencias son un sub-recurso atado a la máquina de estados de
  ADR-0007. Excepción **anotada en el docstring de la clase**, misma categoría
  que `gestor_sesion` (314) y `auth_service` (350). Único cambio: ese bloque de
  docstring.
- **Widgets nuevos con lógica de presentación no trivial** (badges de estado,
  tarjetas con ramas según rol/estado) ganaron test de widget mínimo:
  `tarjeta_trabajo`, `tarjeta_mi_publicacion`, `tarjeta_postulante`,
  `formulario_editar_perfil`, `info_personal_perfil`.
- **Tests de pantalla existentes sin tocar aserciones**: `perfil_tab_test` (4),
  `editar_perfil_screen_test` (4), `trabajos_y_postulaciones_test` (31) pasan
  igual.
- **Desvíos**: `trabajos_tab` salió con 6 cortes (no 5) — el toggle
  Trabajos/Mis publicaciones fue a `toggle_feed_trabajos.dart` para bajar de
  ~317 a 283; la hoja de filtros salió como **función**
  (`abrirHojaFiltrosTrabajos`), no `StatelessWidget`, por su estado local
  mientras está abierta.

## Criterios de aceptación

- [x] `flutter analyze` **no introduce errores nuevos**. Los 37 avisos
      actuales pueden bajar, no subir. → **37, las mismas, 0 errores** tras A
      y B-1.
- [x] `flutter test` sigue en **190 pasando**. Si un test cambia de ruta,
      cambia el import, no el test. → **194** (190 + los 4 de la parte A);
      la B-1 no toca ningún test salvo sus `import`.
- [x] **Ningún archivo Dart nuevo o movido pasa de 300 líneas.** Los tres
      monstruos conocidos quedan como están, con excepción anotada. → una
      excepción nueva y justificada: `nucleo/api/gestor_sesion.dart`, 314.
- [x] Al menos **una pantalla que hoy no tiene test** gana uno que use un
      servicio falso inyectado. → `RegistroEmpleadorScreen` (parte A).
- [x] La app **arranca y se recorre en el emulador** (`Pixel_6`, no
      `Pixel_9`). Con capturas. → hecho en la B-1, con el backend apagado:
      arranca, restaura sesión, feed, perfil, ranking, chats, tema oscuro,
      formulario de publicar y ADR-0013. Capturas en
      `docs/agent-reports/capturas/027b1-*.png`. **Login no se probó**: la
      sesión guardada se restauró y no había forma de llegar al login sin
      cerrar sesión (y sin backend no se podría volver a entrar).
- [x] `docs/architecture.md` refleja la estructura nueva. → actualizado
      también para la B-2 (tabla de carpetas + diagrama).
- [x] El reporte dice **qué se movió, qué no, y por qué**. → A y B-1 en
      `docs/agent-reports/`; el de B-2 va en el mensaje del agente al
      orquestador (verificación en emulador y PR pendientes).

## Trampas conocidas

- **Mover archivos en Dart rompe imports en silencio hasta que compilas.**
  Corre `flutter analyze` después de cada funcionalidad movida, no al final.
- Usa **`git mv`**, no borrar y crear: si no, el historial se pierde y el
  diff se vuelve ilegible para revisar.
- `notificadorTema` es un `ValueNotifier` **global**. Al moverlo, comprueba
  quién lo escucha (`grep`) — es estado compartido disfrazado de constante.
- El commit de mover archivos y el de cambiar código **van separados**. Un
  commit que mueve y edita a la vez no se puede revisar.
