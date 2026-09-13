---
id: 041
titulo: "Flutter: reactivar EditarTrabajoScreen contra PUT /api/trabajos/{id}"
estado: hecho
agente: "flutter-agent"
creada: 2026-09-12
rama: "feature/flutter-editar-trabajo"
---

## Objetivo

Reactivar la edición de una publicación ya guardada, ahora que el backend
(tarea 040) expone `PUT /api/trabajos/{id}`. Es la contraparte Flutter de la
petición del dueño ("habilita la edición de un trabajo — después de elegir
un postulante se deshabilita la edición").

**No hay que tocar la regla de cuándo se muestra el botón "Editar trabajo":
ya está bien.** `detalle_trabajo_screen.dart` (línea ~301) ya condiciona
`_acciones()` a `esDueno && e == EstadosTrabajo.activo` — el botón de editar
solo aparece cuando el trabajo sigue `activo`, exactamente la regla pedida.
Esta tarea es reactivar lo que hay *dentro* de `EditarTrabajoScreen`, no
tocar cuándo se llega a ella.

## Dependencias — no empezar antes de que se cumplan las dos

1. **Backend (tarea 040) en `en-revision` o `hecho`.** Necesitas el contrato
   real de `PUT /api/trabajos/{id}` (400/403/404/409 y su forma exacta) para
   no adivinar los mensajes de error. Si 040 cambia algo del contrato después
   de que empieces, avisa al `tech-lead`.
2. **Tarea 039 (`hotfixes-qa-dueno`) en `hecho`, mergeada.** Su punto 4
   reestructura el campo de pago de `editar_trabajo_screen.dart` (de un solo
   campo "Pago por hora" a un campo de tarifa + selector de unidad
   día/hora/semana/contratación) **dejando el botón deshabilitado**. Si esta
   tarea 041 empieza antes, vas a reactivar un botón sobre una estructura de
   campos que 039 va a reescribir por debajo tuyo — mismo archivo, mismo
   widget, conflicto de merge seguro. Verifica en
   `docs/agent-tasks/039-hotfixes-qa-dueno.md` que su estado sea `hecho`
   antes de tocar `editar_trabajo_screen.dart`.

## Contexto relevante

- `lib/funcionalidades/trabajos/pantallas/editar_trabajo_screen.dart` — hoy
  el botón "Guardar cambios" es `onPressed: null` (línea ~189) con un
  docstring que dice literalmente qué hacer cuando el backend tenga el
  endpoint: "basta con reactivar el botón y devolverle su implementación a
  `PublicacionService.actualizarPublicacion`".
- `lib/funcionalidades/trabajos/datos/publicacion_service.dart` —
  `actualizarPublicacion(String id, Map<String, dynamic> campos)` hoy
  devuelve `MensajesError.sinEdicionDeTrabajo` sin llamar a nada (línea
  ~208). Cambia su implementación (y probablemente su firma — ver más abajo)
  para llamar de verdad al backend.
- `lib/nucleo/api/api_client.dart` ya tiene `reemplazar()` (verbo `PUT`,
  línea ~186) — es el mismo que usa `PUT /api/usuarios/me` en
  `PerfilService`. No hace falta añadir nada a `ApiClient`.
- `lib/compartido/modelos/publicacion.dart` — `Publicacion.aJson()` (línea
  ~207) ya serializa exactamente los ocho campos que el backend va a aceptar
  en el `PUT` (decisión tomada en la tarea 040): `titulo`, `descripcion`,
  `categoria`, `departamento`, `ciudad`, `zona`, `presupuesto`, `plazo`. Por
  eso el diseño recomendado es mandar `publicacion.aJson()` de un objeto
  `Publicacion` reconstruido con los campos del formulario y el resto
  copiado del original (`widget.publicacion`), no un `Map` recortado a mano.
- `docs/api.md` (actualizado por la 040) tiene el contrato exacto de
  errores.

## Qué hacer

1. **Reescribe `PublicacionService.actualizarPublicacion`** para que llame a
   `_api.reemplazar(RutasApi.trabajo(id), cuerpo: ...)` y parsee la
   respuesta con `Publicacion.desdeJson(ApiClient.comoObjeto(json))`, con el
   mismo patrón `_intentar`/manejo de errores que el resto de la clase.
   Decide la firma que tenga más sentido — el `Map<String, dynamic> campos`
   actual es un resto de la época de Firestore (donde tenía sentido mandar
   solo los campos que cambiaron); con un backend que espera la forma
   completa de `CrearTrabajoRequest`/`Publicacion.aJson()`, probablemente
   tenga más sentido que reciba una `Publicacion` completa, igual que
   `crearPublicacion(Publicacion publicacion)`. Si cambias la firma, actualiza
   el único punto que la llama (`EditarTrabajoScreen`) y revisa que no haya
   otro caller ni test que dependa de la firma vieja
   (`grep -rn actualizarPublicacion lib test`).
2. **Reactiva el botón "Guardar cambios"** en `EditarTrabajoScreen`:
   `onPressed` valida el formulario, arma la `Publicacion` actualizada
   (título/categoría/plazo/descripción/presupuesto del formulario +
   departamento/ciudad/zona/estado/id/etc. copiados de `widget.publicacion`
   sin tocar), llama al servicio inyectado (`context.read<PublicacionService>()`
   — **no lo construyas dentro del `State`**, regla 15 de `CLAUDE.md`,
   confirma cómo llega hoy: si `EditarTrabajoScreen` no lo recibe todavía por
   constructor/`context.read`, añádelo tú, no asumas que ya está cableado) y
   usa el mismo patrón de carga/error que el resto de formularios
   (`ejecutarConCarga`, `mostrarSnackbar` — ver `compartido/widgets/`).
3. **Quita el aviso `_avisoNoSePuedeEditar()`** (o transfórmalo en el
   feedback normal de guardado — tu criterio) y el texto
   `MensajesError.sinEdicionDeTrabajo` de la pantalla, ya que dejan de ser
   ciertos. Revisa si `MensajesError.sinEdicionDeTrabajo` se usa en algún
   otro sitio antes de borrar la constante
   (`grep -rn sinEdicionDeTrabajo lib test`) — probablemente no, pero
   verifícalo en vez de asumirlo.
4. **Maneja el 409 "ya no se puede editar"** como un caso real: si el
   empleador abrió la pantalla, alguien aceptó una postulación mientras
   tanto, y al guardar el servidor responde 409, la pantalla tiene que
   enseñar ese mensaje (ya viene listo desde `_intentar`, que pasa el
   `message` del backend tal cual) y no dejar al usuario en un estado
   confuso — vuelve al detalle o deja el formulario con el error visible,
   tu criterio, documenta cuál elegiste.
5. **Actualiza el docstring de la clase** `EditarTrabajoScreen` (líneas 13-30
   hoy) — ya no describe la realidad una vez que el botón funciona.
6. Tests: añade al menos un test de `PublicacionService` para
   `actualizarPublicacion` (éxito, 403, 409, 400 con campo) siguiendo el
   patrón de `test/funcionalidades/trabajos/` (JSON de ejemplo del contrato
   documentado en `docs/api.md` por la 040, no inventado). Si el archivo de
   la pantalla lo permite dentro del techo de 300 líneas, añade también un
   test de widget mínimo (botón deshabilitado si el formulario es inválido,
   habilitado si es válido) — si no cabe sin pasar el techo, prioriza el
   test de servicio y anótalo en el reporte.

## Qué NO es esta tarea

- No cambia cuándo se muestra el botón "Editar trabajo" en
  `detalle_trabajo_screen.dart` (ya está bien, ver Objetivo).
- No reestructura el campo de pago (tarifa + unidad) — eso ya lo hace la 039,
  que tiene que estar mergeada antes de empezar esta.
- No añade edición de ubicación (departamento/ciudad/zona) a la UI aunque el
  backend ya lo acepte — se preserva el valor original sin exponer campos
  nuevos en el formulario. Si en el futuro se quiere editar ubicación, es una
  tarea de UI aparte; el backend ya no sería el bloqueante.

## Criterios de aceptación

- [x] El botón "Guardar cambios" funciona: guarda de verdad contra
      `PUT /api/trabajos/{id}` y vuelve al detalle (o donde tenga sentido)
      con el trabajo actualizado.
- [x] El 403/404/409/400 del backend se enseñan con su mensaje real, no un
      genérico.
- [x] `flutter analyze` sin errores nuevos.
- [x] `flutter test` pasa, incluidos los tests nuevos del punto 6.
- [x] Ningún archivo tocado pasa de 300 líneas sin justificarlo en el
      reporte (ADR-0014).
- [x] Verificación visual (emulador o capturas reales, mismo criterio que
      las tareas 032-036 si no hay emulador disponible).
- [x] Reporte en `docs/agent-reports/041-*.md`.

## Notas del agente que la ejecuta

- **Firma de `actualizarPublicacion` cambiada** de `(String id, Map<String,
  dynamic> campos)` a `(Publicacion publicacion)`, igual que
  `crearPublicacion`. Único caller (`EditarTrabajoScreen`) actualizado; único
  test viejo (que afirmaba el `MensajesError.sinEdicionDeTrabajo` fijo, sin
  petición) reemplazado por 4 tests de contrato nuevos.
- **`MensajesError.sinEdicionDeTrabajo` se borró**: no quedaba ningún otro
  uso tras quitarlo de la pantalla y del servicio (verificado con grep).
- **409** ("Solo se puede editar un trabajo mientras está ACTIVO..."): se
  enseña con `mostrarSnackBar` y el formulario se queda tal cual (no
  navega) — el usuario decide si reintentar o salir con el botón atrás,
  sin perder lo escrito.
- **Patrón de carga elegido**: `_cargando` (bool) + `mostrarSnackBar`, igual
  que `PublicarTrabajoScreen` (su hermana de formulario), no el diálogo modal
  de `ejecutarConCarga` que usa `DetalleTrabajoScreen` para acciones
  puntuales de un toque — esta pantalla es un formulario completo.
- **`DetalleTrabajoScreen`** también se tocó (fuera del archivo principal de
  la tarea, pero imprescindible): el botón "Editar trabajo" ahora espera el
  resultado del `Navigator.push` y llama a `_cargar()` si volvió `true`. No
  se tocó la condición de cuándo se muestra el botón (regla explícita de
  "Qué NO es esta tarea").
- **Tamaño de archivos**: `editar_trabajo_screen.dart` queda en 234 líneas
  (antes 218), `publicacion_service.dart` en 395 líneas (antes 380) — sigue
  con la excepción documentada en su propio
  encabezado desde la tarea 027 B-2b (una sola clase, una sola razón para
  cambiar: el contrato de `/api/trabajos/**`). `detalle_trabajo_screen.dart`
  ya estaba en 987 líneas **antes** de esta tarea (no introducido aquí); mi
  cambio ahí son 5 líneas netas para esperar el resultado del `Navigator.push`.
- **Widget test añadido** (`test/funcionalidades/trabajos/editar_trabajo_screen_test.dart`,
  2 casos: éxito y 409) siguiendo el patrón de `editar_perfil_screen_test.dart`
  (Provider real + `ApiClient.fijarInstancia` con `MockClient`, sin socket) —
  es el primer test de pantalla para este archivo.
- **Bloqueo temporal ajeno a esta tarea**: a mitad de sesión,
  `lib/funcionalidades/perfil/pantallas/editar_perfil_screen.dart` (fuera de
  mi dominio: perfil, no trabajos) apareció modificado en el mismo working
  tree por otro proceso, con `tt.subtitulo`/`tt.cuerpo`/`textTheme.titulo`
  sin el import de `app_tipografia.dart` — tumbó la compilación de 4 archivos
  de test (`editar_perfil_screen_test.dart`, `perfil_tab_test.dart`,
  `pantalla_inicial_test.dart`, `widget_test.dart`) durante varios minutos.
  No lo toqué (no es mi dominio); se resolvió solo antes de cerrar esta tarea
  cuando ese otro proceso terminó su edición y agregó el import que faltaba.
  El `flutter test`/`flutter analyze` final de este reporte ya reflejan el
  repo con eso resuelto.
