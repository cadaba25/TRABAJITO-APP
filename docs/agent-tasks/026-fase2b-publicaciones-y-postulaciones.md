---
id: 026
titulo: "Migración fase 2b-1: trabajos y postulaciones contra el backend"
estado: hecho
agente: "flutter-agent"
creada: 2026-08-30
rama: "feature/fase2b-servicios-restantes"
---

## Objetivo

Migrar los **dos servicios que forman el corazón de la demo**:
`publicacion_service.dart` (450 líneas, el más grande) y
`postulacion_service.dart`. Con esto, el flujo que se le enseña a un
inversionista —publicar un trabajo, verlo en el feed, postularse, elegir
postulante— pasa a funcionar contra PostgreSQL.

Los otros tres (cartera, calificaciones, chat) van después, en su propia
tarea. **No los toques aquí.**

## Regla nueva y vinculante: ADR-0013

Decisión del dueño del 2026-08-30, textual: *"si no hay conexion no puede
hacer ninguna funcion nueva"*.

**Sin sesión confirmada** (`EstadoSesion.avisoSinConexion == true`), la app
**no ejecuta ninguna acción que cree o modifique datos**. Leer sí; escribir
no. Y hay que **decírselo al usuario** con un mensaje claro, no dejar el
botón girando ni fingir que funcionó.

Esto importa especialmente ahora: **Firestore encola las escrituras sin
conexión y las sincroniza después**. Cuando migres a REST ese encolado
desaparece y la petición simplemente falla. Si no lo tratas, la migración
empeora el comportamiento actual sin que se note.

**La comprobación va en UN solo sitio** (por ejemplo en el `ApiClient` o en
una capa común), no repetida pantalla por pantalla: si cada una la
implementa por su cuenta, alguna se olvidará. Lee ADR-0013 entero.

## Lo que ya está resuelto y debes reutilizar

- **`lib/services/api/`** — `ApiClient` con los **tres candados** de
  renovación de token, traducción de errores de ADR-0008, almacén seguro.
  **No toques esa lógica**: cada candado cubre un caso distinto y hay tests
  que fallan si se quita alguno. Lee el reporte de la tarea 024 antes.
- Los 7 modelos ya tienen `desdeJson()`/`aJson()`.
- El patrón de la fase 2a (tarea 020) para pantallas: cómo se sustituyeron
  los `StreamBuilder` por carga puntual. Síguelo.
- El aviso de sin conexión de la tarea 023 (`perfil_tab.dart`): mismo
  criterio visual y de tono.

## Decisión ya tomada sobre los streams

`Stream` de Firestore → **carga puntual + "deslizar para actualizar"**
(`RefreshIndicator`). Nada de sondeo. El tiempo real se reserva para el chat,
que va en otra tarea.

`publicacion_service.dart` tiene 6 métodos `Stream` y `postulacion_service`
tiene 3. Todos se convierten.

## Avisos de contrato (verificados, no los adivines)

- El backend exige `{"reabrir": true|false}` en `POST /api/trabajos/{id}/cancelar`
  — sin valor por defecto: falta → 400.
- **Entregar un trabajo exige al menos una evidencia** (ADR-0007). Si la
  pantalla no la pide, el usuario no podrá entregar.
- Tras pedir correcciones hace falta una evidencia **nueva**, posterior.
- **Postularse al propio trabajo → 409** (decisión del dueño, tarea 019).
- Estados del trabajo: hay **10**, incluido `EN_DISPUTA` (ADR-0007). Mira
  `EstadoTrabajo` en el backend, no asumas los de Firestore.
- El feed viene **paginado** (envoltorio de Spring Data). Ya existe
  `pagina_api.dart` de la tarea 018.

Comprueba las respuestas reales contra el servidor antes de escribir el
parseo. `docs/api.md` puede ir por detrás del código.

## Alcance

1. `publicacion_service.dart` y `postulacion_service.dart` contra `ApiClient`.
2. Las pantallas que los usan: `trabajos_tab`, `detalle_trabajo_screen`
   (905 líneas, la más grande), `publicar_trabajo_screen`,
   `editar_trabajo_screen`, `mis_publicaciones_screen`, `postularse_sheet`,
   `postulantes_screen`, `mis_postulaciones_screen`.
3. El bloqueo de escritura sin conexión (ADR-0013), en un solo sitio.
4. Tests.

## Fuera de alcance

- `cartera_service`, `calificacion_service`, `chat_service`: otra tarea.
- Quitar Firebase de `pubspec.yaml`: fase 3.
- Pantallas nuevas que el backend soporta y la app no tiene (reclamar a
  soporte, elegir cerrar/reabrir al cancelar): anótalas, no las hagas aquí
  salvo que sean imprescindibles para que el flujo no se rompa.

## Criterios de aceptación

- [x] Publicar → ver en el feed → postularse → ver postulantes → aceptar,
      todo contra el backend, **probado en el emulador `Pixel_6`**.
- [x] Sin conexión, ninguna acción de escritura se ejecuta, y el usuario
      recibe un mensaje claro (ADR-0013).
- [x] `flutter analyze` sin errores nuevos; `flutter test` pasa (hoy **148**).
- [x] Lo que quede sin migrar o sin probar, dicho explícitamente.

## Notas del agente que la ejecuta

**Hecha el 2026-09-04.** Reporte completo en
`docs/agent-reports/026-fase2b-publicaciones-y-postulaciones.md`. Lo que hay
que saber sin leerlo entero:

- Los dos servicios y las 8 pantallas hablan con `/api/**`. Los **9 `Stream`**
  (6 + 3) son ahora carga puntual + "deslizar para actualizar". Nada de sondeo.
- **ADR-0013 vive en un solo sitio**: `ApiClient.exigirSesionConfirmada`, que
  bloquea toda petición autenticada que no sea `GET`. Lo instala
  `AuthService.vigilarEscriturasSinConexion()` desde `main.dart`, y aprovecha
  para reconfirmar la sesión, así que si la conexión volvió la acción sigue
  sola. **La renovación de token no se tocó**: es un mecanismo aparte.
- **Tres cosas del contrato que no se pueden adivinar** y ahora tienen test:
  el feed pagina con `pagina`/`tamano` —mandar `page`/`size` no falla, se
  ignora y devuelve siempre la página 0—; `cancelar` exige `reabrir` (400 si
  falta); y la postulación del backend **no trae** `tituloTrabajo` ni
  `empleadorId`.
- **La app perdió capacidades porque el backend no las tiene**: no se puede
  editar un trabajo (`PUT`/`PATCH` no existen), no se puede borrar (`DELETE`
  tampoco; se cierra) y un trabajo cerrado no se reabre. Las pantallas lo
  dicen en vez de fingirlo.
- El botón "Reportar problema" —que solo enseñaba un "próximamente"— **ahora
  manda `POST /{id}/reclamar` de verdad**. Hizo falta: al migrar, cancelar
  dejó de estar permitido desde `en_progreso`, así que sin esto las dos partes
  se quedaban sin salida.
- `flutter analyze`: 60 → **37 issues**, 0 errores. `flutter test`: 148 →
  **190**.
- **Probado en el emulador Pixel_6 contra el backend real**: publicar → feed →
  postularse → ver postulantes → aceptar, con el `ASIGNADO` y el chat
  comprobados por API en el servidor. Y ADR-0013 con la red cortada de verdad,
  incluida la recuperación al volver la red.
- **NO probado en el emulador** (dicho a propósito): todo el tramo económico
  —reservar pago, iniciar, entregar, aceptar y pagar—, porque necesita saldo y
  un acuerdo en el chat, **y el chat y la cartera siguen en Firestore**. Eso
  se cierra en la fase 2b-2. Ahí queda además la única costura entre las dos
  mitades: `DetalleTrabajoScreen._reservarPago` lee el acuerdo del chat de
  Firestore.
