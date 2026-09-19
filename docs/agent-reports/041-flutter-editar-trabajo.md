---
tarea: 041
titulo: "Flutter: reactivar EditarTrabajoScreen contra PUT /api/trabajos/{id}"
agente: "flutter-agent"
fecha: 2026-09-12
---

## Resumen

Se reactivó `EditarTrabajoScreen` contra el `PUT /api/trabajos/{id}` que
expuso la tarea 040 (backend, revisada por security-agent en la 042). El
botón "Guardar cambios" ahora guarda de verdad, el aviso "todavía no se puede
editar" desapareció, y el 403/404/409/400 del backend se enseñan con su
mensaje real.

## Archivos tocados

- `lib/funcionalidades/trabajos/datos/publicacion_service.dart` —
  `actualizarPublicacion` reescrito por completo (ver "Cambio de firma"
  abajo). Docstring de la clase actualizado (la sección "Lo que el backend NO
  sabe hacer" ya no incluye editar).
- `lib/funcionalidades/trabajos/pantallas/editar_trabajo_screen.dart` —
  reescrito: servicio inyectado (`context.read<PublicacionService>()`), aviso
  y botón deshabilitado quitados, `_guardar()` nuevo con validación + llamada
  al servicio + `mostrarSnackBar`, docstring de la clase actualizado.
- `lib/funcionalidades/trabajos/pantallas/detalle_trabajo_screen.dart` —
  cambio mínimo: el botón "Editar trabajo" ahora espera (`await`) el
  resultado del `Navigator.push` y recarga (`_cargar()`) si volvió `true`.
  **No se tocó** la condición de cuándo se muestra el botón (línea ~301,
  `esDueno && e == EstadosTrabajo.activo`), tal como pedía la tarea.
- `lib/nucleo/textos/mensajes_error.dart` — se borró la constante
  `sinEdicionDeTrabajo` (verificado con `grep -rn sinEdicionDeTrabajo lib
  test` que no quedaba ningún otro uso tras los cambios de arriba).
- `test/funcionalidades/trabajos/trabajos_y_postulaciones_test.dart` — se
  quitó el test viejo que afirmaba que editar no mandaba nada; se añadió un
  grupo nuevo "PublicacionService — editar" con 4 tests (éxito, 403, 409,
  400 con campo).
- `test/funcionalidades/trabajos/editar_trabajo_screen_test.dart` (nuevo) —
  2 tests de widget: guardar con datos válidos hace `PUT` con los 8 campos y
  vuelve a la pantalla anterior; un 409 se enseña y no se pierde el
  formulario. Primer test de pantalla para este archivo.
- `test/manual/generar_capturas_editar_trabajo.dart` (nuevo) — generador de
  capturas reales (no es parte de la suite de `flutter test` normal, mismo
  patrón que `generar_capturas_trabajos.dart` de la 034), usado para la
  verificación visual sin emulador (ver abajo).
- `docs/agent-context/repo-snapshot.md` — nueva sección para las tareas
  040/041, y se corrigió el bullet que decía "no se puede editar un trabajo
  publicado" (ya no es cierto).
- `docs/agent-tasks/041-flutter-editar-trabajo.md` — `estado: hecho`,
  checkboxes marcados, notas del agente.

## Cambio de firma de `actualizarPublicacion`

De `Future<String?> actualizarPublicacion(String id, Map<String, dynamic>
campos)` (resto de la época de Firestore: siempre devolvía
`MensajesError.sinEdicionDeTrabajo` sin llamar a nada) a:

```dart
Future<String?> actualizarPublicacion(Publicacion publicacion)
```

Igual que `crearPublicacion(Publicacion publicacion)`. Razones:

1. El backend espera la misma forma completa que `POST /api/trabajos`
   (`CrearTrabajoRequest`), no un parche parcial — un `Map` con "solo lo que
   cambió" no tiene sentido contra este contrato.
2. `Publicacion.aJson()` ya recorta a los ocho campos editables, así que
   pasar el objeto completo evita reinventar un `Map` a mano en la pantalla.
3. Consistencia: es el mismo patrón que ya usa `crearPublicacion`.

Implementación:

```dart
Future<String?> actualizarPublicacion(Publicacion publicacion) {
  return _intentar(() async {
    final json = await _api.reemplazar(
      RutasApi.trabajo(publicacion.id),
      cuerpo: publicacion.aJson(),
    );
    Publicacion.desdeJson(ApiClient.comoObjeto(json));
    return null;
  });
}
```

El trabajo que devuelve el servidor se parsea (para validar que la forma es
la esperada — si el backend mandara algo irreconocible, `Publicacion.desdeJson`
lo haría explotar en vez de fallar en silencio) pero se **descarta a
propósito**, igual que ya hace `_transicion` con las otras nueve operaciones
de la clase: la pantalla vuelve al detalle y este relee el trabajo entero,
así lo que se ve siempre viene de la misma fuente.

Único caller actualizado: `EditarTrabajoScreen._guardar()`. Único test que
dependía de la firma vieja (`trabajos_y_postulaciones_test.dart` línea ~296,
"editar un trabajo no llega a pedir nada y lo dice claro") reemplazado por
el grupo nuevo. Confirmado con `grep -rn actualizarPublicacion lib test` que
no queda ningún otro caller.

## Manejo del 409

Cuando el empleador tiene la pantalla abierta y, mientras tanto, alguien
acepta una postulación (el trabajo pasa de `ACTIVO` a `ASIGNADO`), guardar
responde `409` con el mensaje real del backend ("Solo se puede editar un
trabajo mientras está ACTIVO (sin postulante elegido)"), que llega tal cual
a través de `_intentar` (mismo mecanismo que ya usan `marcarTerminado`,
`cancelarContratacion`, etc.).

**Decisión tomada**: se enseña con `mostrarSnackBar(context, error, esError:
true)` y **el formulario se queda como está** — no se navega a ciegas. El
usuario conserva lo que escribió y decide: reintentar (si fue un error
pasajero improbable) o volver atrás con el botón de la `AppBar` para ver el
estado real del trabajo en el detalle. La alternativa (forzar el pop y volver
al detalle automáticamente) se descartó porque el mensaje de error ya explica
qué pasó y sacar a la persona de la pantalla sin que lo lea sería peor UX que
dejarla decidir. `EditarTrabajoScreen` no vuelve a comprobar el estado del
trabajo antes de guardar (sería una carrera de todas formas): confía en que
el servidor es la fuente de verdad, como en el resto de la clase.

Cubierto por el test de servicio "un trabajo ya asignado... devuelve el 409
con la explicación" y el test de widget "un 409 (ya hay postulante elegido)
se enseña y no se pierde el formulario".

## `flutter analyze` / `flutter test`

- `flutter analyze`: **0 errores, 14 issues** (info/warning preexistentes de
  otros archivos — ninguno nuevo en los archivos de esta tarea).
- `flutter test`: **268/268** (todo el repo).
- `flutter test test/funcionalidades/trabajos/`: **61/61** (incluye los 6
  tests nuevos de esta tarea).

### Incidente durante la sesión (no relacionado con esta tarea)

A mitad de la sesión, `lib/funcionalidades/perfil/pantallas/editar_perfil_screen.dart`
(fuera de mi alcance: funcionalidad de perfil, no de trabajos) apareció
modificado en el mismo working tree por otro proceso — probablemente
tokenización ADR-0016 en curso (la tarea 039 ya avisaba de que "037 va a
reabrir `cabecera_perfil.dart` e `inicio_screen.dart` para tokens"; esto
parece la misma familia de trabajo extendiéndose a `editar_perfil_screen.dart`).
Ese cambio usaba `tt.subtitulo`/`tt.cuerpo`/`Theme.of(context).textTheme.titulo`
sin importar `nucleo/tipografia/app_tipografia.dart`, así que durante varios
minutos `flutter analyze`/`flutter test` de todo el repo fallaban con 3
errores de compilación que tumbaban 4 archivos de test
(`editar_perfil_screen_test.dart`, `perfil_tab_test.dart`,
`pantalla_inicial_test.dart`, `widget_test.dart`). **No toqué ese archivo**:
esperé, y el otro proceso terminó su edición y agregó el import que faltaba
antes de que yo cerrara esta tarea. Los resultados de arriba (`0
errores`/`268/268`) son del estado final, ya con eso resuelto. Lo dejo
anotado por si alguien ve ese archivo en el historial de esta sesión y se
pregunta por qué cambió sin que esta tarea lo pidiera — no fui yo.

Pasó algo parecido, más brevemente, con `lib/compartido/widgets/estado_exito.dart`
y su test (también fuera de mi alcance): una corrida de `flutter test`
completa reportó 1 fallo transitorio en `estado_exito_test.dart` mientras ese
archivo estaba a medio guardar por otro proceso; una corrida posterior, unos
segundos después, ya pasaba. Tampoco lo toqué.

## Techo de 300 líneas (ADR-0014)

- `editar_trabajo_screen.dart`: **234 líneas** (antes 218). Sin excepción
  necesaria.
- `publicacion_service.dart`: **395 líneas** (antes 380). Sigue con la
  excepción ya documentada en su propio encabezado desde la tarea 027 B-2b
  (una sola clase, una sola razón para cambiar: el contrato completo de
  `/api/trabajos/**`); las ~15 líneas que agregué son docstring del método
  reescrito, no una razón nueva de cambio.
- `detalle_trabajo_screen.dart`: ya estaba en **987 líneas antes** de esta
  tarea (confirmado con `git show HEAD:... | wc -l`), no introducido por mí.
  Mi cambio ahí son 5 líneas netas (esperar el resultado del `Navigator.push`
  y recargar si volvió `true`). No es una excepción nueva que yo esté
  introduciendo, es un archivo que ya excedía el techo por trabajo de tareas
  anteriores (035/036); lo señalo por transparencia, no lo "arreglé" porque
  no es el alcance de esta tarea.

## Verificación visual

No hay emulador disponible en este entorno (`adb` no existe). Se generaron
capturas reales con `test/manual/generar_capturas_editar_trabajo.dart`
(mismo patrón que `generar_capturas_trabajos.dart` de la tarea 034:
`EditarTrabajoScreen` real + `PublicacionService` real sobre un `MockClient`,
`RenderRepaintBoundary.toImage`):

- `docs/agent-reports/capturas/041-editar-trabajo-claro.png`
- `docs/agent-reports/capturas/041-editar-trabajo-oscuro.png`

Ambas muestran el formulario prellenado con los datos de la publicación de
ejemplo y el botón "Guardar cambios" ya activo (antes: `onPressed: null`).
Nota: el texto del botón y los íconos de los campos aparecen como
rectángulos ("tofu") en las capturas — es un artefacto conocido del arnés de
capturas (solo se carga la fuente `Sora` regular vía `FontLoader`, no
`MaterialIcons` ni los pesos que usa el estilo por defecto de
`ElevatedButton`; el mismo artefacto ya existe en capturas previas del repo,
p. ej. `034-feed-sin-resultados-antes-claro.png`). No refleja nada real de la
app: los tests de widget confirman con `find.text('Guardar cambios')` que el
texto y el comportamiento son correctos.

## Qué NO se hizo (documentado, no un olvido)

- No se tocó la condición de cuándo se muestra el botón "Editar trabajo" en
  `detalle_trabajo_screen.dart` (seguía bien, según la tarea).
- No se reestructuró el campo de pago (ya lo hizo la 039).
- No se agregó edición de ubicación (departamento/ciudad/zona) al
  formulario, aunque el backend ya la acepte — se preserva el valor original
  de `widget.publicacion` sin exponer campos nuevos, tal como pedía la tarea.

## Pendiente / follow-ups sugeridos

- Ninguno abierto por esta tarea. El hueco de edición que quedaba anotado en
  el reporte de la 026 ya se cerró (backend + Flutter).
