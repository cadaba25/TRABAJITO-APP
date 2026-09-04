---
id: 026
titulo: "Migración fase 2b-1: trabajos y postulaciones contra el backend"
estado: en-progreso
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

- [ ] Publicar → ver en el feed → postularse → ver postulantes → aceptar,
      todo contra el backend, **probado en el emulador `Pixel_6`**.
- [ ] Sin conexión, ninguna acción de escritura se ejecuta, y el usuario
      recibe un mensaje claro (ADR-0013).
- [ ] `flutter analyze` sin errores nuevos; `flutter test` pasa (hoy **148**).
- [ ] Lo que quede sin migrar o sin probar, dicho explícitamente.

## Notas del agente que la ejecuta

(vacío — en progreso)
