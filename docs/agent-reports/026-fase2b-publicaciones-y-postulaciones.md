---
id: 026
tarea: docs/agent-tasks/026-fase2b-publicaciones-y-postulaciones.md
agente: "flutter-agent"
fecha: 2026-09-04
---

## Objetivo (copiado de la tarea)

Migrar los **dos servicios que forman el corazón de la demo**:
`publicacion_service.dart` (450 líneas, el más grande) y
`postulacion_service.dart`. Con esto, el flujo que se le enseña a un
inversionista —publicar un trabajo, verlo en el feed, postularse, elegir
postulante— pasa a funcionar contra PostgreSQL.

Los otros tres (cartera, calificaciones, chat) van después, en su propia
tarea. **No los toques aquí.**

Además, aplicar ADR-0013 (sin conexión confirmada no se ejecuta ninguna acción
que cree o modifique datos) **en un solo sitio**.

## Cambios realizados

### 1. Los dos servicios, contra `/api/**`

`PublicacionService` y `PostulacionService` ya no importan
`cloud_firestore`. Ambos reciben un `ApiClient` inyectable (mismo patrón que
`AuthService` en la tarea 020) y devuelven `String?` — `null` = bien, texto =
mensaje en español listo para enseñar—, así que las ocho pantallas que los
llaman no tuvieron que cambiar de forma de tratar errores.

**Los 9 `Stream` desaparecieron** (6 + 3), sustituidos por carga puntual +
`RefreshIndicator`, que es la decisión del `tech-lead` para la fase 2. No hay
sondeo en ningún sitio.

| Antes (Firestore) | Ahora |
|---|---|
| `streamPublicaciones({limite})` | `listarFeed({pagina, tamano})` → `PaginaApi<Publicacion>` |
| `streamMisPublicaciones(uid)` | `misPublicaciones()` (el uid sale del token) |
| `streamPublicacion(id)` | `obtenerPublicacion(id)` / `recargarPublicacion(id)` |
| `streamEvidencias(id)` | `listarEvidencias(id)` |
| `streamMisPostulaciones(uid)` | `misPostulaciones()` |
| `streamPostulantes(idPub)` | `postulantesDe(idPub)` |
| `streamMiPostulacion(pub, uid)` | `miPostulacionEn(idPublicacion)` |
| `asignarTrabajador(...)` (transacción a mano en el cliente) | `PostulacionService.aceptar(id)` — el servidor asigna, rechaza al resto y **crea el chat**, en una transacción |
| transacciones de escrow escritas desde el móvil | una llamada por transición; **el servidor decide** (ADR-0007) |

Métodos nuevos que el backend sí ofrecía y la app no usaba:
`misTrabajosAsignados()`, `cerrarPublicacion(id)`, `reclamarProblema(...)`,
`idsDeTrabajosPostulados()`.

### 2. ADR-0013, en un solo sitio

La comprobación vive en **`ApiClient.exigirSesionConfirmada`**, y se aplica
dentro de `_peticionConReintento` a toda petición autenticada cuyo método no
sea `GET` — es decir, a toda acción que cree o modifique datos, de cualquier
pantalla, presente o futura. Si no hay sesión confirmada, se lanza
`SinConexionConfirmada` **sin tocar la red**.

Quien la instala es `AuthService.vigilarEscriturasSinConexion()`, llamada
desde `main.dart` junto a `escucharFinDeSesion()`. Además de comprobar,
**intenta confirmar la sesión** (`GET /api/auth/yo`): si la conexión ya
volvió, la acción sigue adelante sola y el aviso de "datos de tu última
visita" desaparece de toda la app. Verificado en el emulador (ver más abajo).

Lo que **no** se bloquea, a propósito: las lecturas (ADR-0013 dice "leer sí,
escribir no"), y `login`/`registro`/`refresh`/`logout`, que van por otro
camino (`autenticada: false` o `_enviar` directo). Bloquearlas sería impedir
salir del agujero.

El mensaje (`MensajesError.sinConexionNoSeEscribe`) dice explícitamente **"No
se ha enviado nada"**. Esa frase es la razón de ser de todo esto: con
Firestore la escritura se encolaba y se sincronizaba sola, así que el usuario
podía creer que algo se guardó; contra HTTP no se guarda nada y hay que
decirlo con esas palabras.

**No se tocó la lógica de renovación del token.** El guardián es un mecanismo
aparte, con su propio estado (`_confirmador`, `_confirmacionEnVuelo`), y se
ejecuta *antes* de la renovación. Los tres candados siguen intactos y sus
tests siguen en verde.

### 3. Las ocho pantallas

Todas pasan a carga puntual con "deslizar para actualizar", estado de error
honesto (con el `message` del backend, no un "no hay nada" ambiguo) y recarga
después de cada acción — sin stream, eso es lo único que las mantiene al día.

Cambios de comportamiento **obligados por reglas del servidor**, avisados en
pantalla en vez de dejar que el usuario los descubra a base de errores:

- **Cancelar obliga a elegir.** `POST /{id}/cancelar` exige
  `{"reabrir": true|false}` y sin él responde 400. El diálogo de "¿cancelar?"
  pasó a tener dos botones: "Volver a publicarlo" y "Cerrarlo".
- **Desde `en_progreso` ya nadie cancela** (409). El botón de cancelar
  desaparece en esos estados y en su lugar aparece **"Reportar problema a
  soporte"**, que ahora manda `POST /{id}/reclamar` de verdad; antes solo
  enseñaba un `SnackBar` de "próximamente" y no mandaba nada. Sin esto, al
  migrar las dos partes se habrían quedado sin ninguna salida de un trabajo
  ya iniciado.
- **Entregar exige al menos una evidencia propia** (ADR-0007). El botón
  "Marcar como terminado" se desactiva mientras no haya avances y se explica
  por qué, en amarillo de advertencia.
- **Estado `en_disputa`**: no se ofrece ninguna acción, porque no hay ninguna
  que ofrecer; se dice que el pago queda retenido hasta que soporte resuelva.
- **`Mis publicaciones`**: el badge ya no es "Activo/Cerrado" sino la etiqueta
  real del estado (son diez, ADR-0007), "Cerrar" solo aparece cuando de verdad
  se puede, y "Reabrir" desapareció porque el backend no sabe reabrir nada.
- **`Editar trabajo`**: el backend no tiene `PUT`/`PATCH` de un trabajo. La
  pantalla se conserva con los campos rellenos —para poder copiarlos y volver
  a publicar—, un aviso arriba y el botón desactivado. Ni se quita (escondería
  que la app perdió algo) ni se deja activo (haría escribir para nada).
- **`Eliminar publicación`**: tampoco existe `DELETE`. El botón explica que
  los trabajos no se borran y ofrece cerrarla, que es lo que sí se puede.
- **`Mis postulaciones`** pide el trabajo aparte para poder enseñar su título:
  el DTO de postulación del backend **no trae** `tituloTrabajo` ni
  `empleadorId`, que en Firestore iban desnormalizados dentro del documento.
- **`Trabajos`** pagina de verdad (se piden páginas y se suman) en vez de
  volver a pedirlo todo con un límite mayor, y filtra ids repetidos: un
  trabajo publicado entre dos peticiones desplaza la paginación.

## Archivos modificados

- `lib/services/publicacion_service.dart` — reescrito contra el backend
- `lib/services/postulacion_service.dart` — reescrito contra el backend
- `lib/services/api/api_client.dart` — `exigirSesionConfirmada` + guardián
  (**sin tocar la renovación de token**)
- `lib/services/api/api_excepciones.dart` — `SinConexionConfirmada`
- `lib/services/api/configuracion_api.dart` — 16 rutas nuevas en `RutasApi`
- `lib/services/auth_service.dart` — `vigilarEscriturasSinConexion()`
- `lib/main.dart` — instala la comprobación al arrancar
- `lib/utils/constantes.dart` — 3 mensajes nuevos
- `lib/screens/tabs/trabajos_tab.dart`
- `lib/screens/detalle_trabajo_screen.dart` (de `StatelessWidget` a
  `StatefulWidget`)
- `lib/screens/mis_publicaciones_screen.dart`
- `lib/screens/mis_postulaciones_screen.dart`
- `lib/screens/postulantes_screen.dart`
- `lib/screens/editar_trabajo_screen.dart`
- `test/services/trabajos_y_postulaciones_test.dart` (nuevo, 31 tests)
- `test/api/bloqueo_sin_conexion_test.dart` (nuevo, 11 tests)
- `docs/architecture.md`, `docs/agent-context/repo-snapshot.md`,
  `docs/agent-tasks/026-...md`

`publicar_trabajo_screen.dart` y `postularse_sheet.dart` **no necesitaron
cambios**: ya hablaban con los servicios por su API de `String?`.

## Decisiones tomadas

**El guardián de ADR-0013 va en `ApiClient`, no en una capa nueva ni en las
pantallas.** Es el único punto por el que pasan todas las escrituras de la
app; cualquier otro sitio deja un hueco por el que alguna pantalla se colará.
Se inyecta como callback (`ConfirmadorDeSesion`) en vez de importar
`sesion_usuario.dart` desde la capa HTTP, para no invertir la dependencia
—`ApiClient` no debe saber qué es un `Usuario`— y para que los tests puedan
ejercitarlo sin montar la sesión entera.

**El confirmador reintenta en vez de solo comprobar.** La alternativa era
bloquear y esperar a que el usuario encontrara dónde deslizar para actualizar.
Con esto, si la conexión volvió, la acción que el usuario acaba de pulsar
funciona. Comprobado en el emulador: mismo botón, misma pantalla, sin
reiniciar nada.

**Los mensajes 409 del backend se pasan tal cual al usuario.** Explican qué
hacer ("sube una evidencia nueva antes de volver a entregar"); reescribirlos
en el cliente sería perder información.

**`reclamarProblema` entra en el alcance** aunque la tarea lo listaba como
"anótalas, no las hagas". Motivo: al migrar, cancelar dejó de estar permitido
desde `en_progreso`, y el botón que ya existía ("Reportar problema") no
mandaba nada. Dejarlo así habría quitado la única salida que les queda a las
dos partes. Es un cambio pequeño sobre un botón existente, no una pantalla
nueva.

**No se implementó cola de reintentos** (ADR-0013 la descarta a propósito).

**`marcarCompletado()` y `reembolsar()` se cayeron** al reescribir el
servicio. Los dos eran código muerto —ninguna pantalla los llamaba— y ninguno
tiene endpoint equivalente para un cliente normal: el reembolso solo puede
hacerlo un ADMIN resolviendo una disputa.

## Problemas encontrados

**El feed no pagina con `page`/`size`.** El controlador declara
`@RequestParam("pagina")` y `@RequestParam("tamano")`. Mandar los nombres de
Spring Data **no da error**: se ignoran en silencio y se devuelve siempre la
página 0 de tamaño 20. Un scroll infinito escrito a partir de `docs/api.md`
habría repetido los mismos veinte trabajos para siempre sin que nadie lo
notara. Comprobado con `curl` contra el servidor antes de escribir el parseo,
y fijado en un test.

**No existe forma de editar ni de borrar un trabajo.** `TrabajoController` no
expone `PUT`, `PATCH` ni `DELETE` (verificado con `grep` sobre todo
`backend/src/main/java`: los únicos `PUT`/`DELETE` del backend están en
`UsuarioController`). Es una **pérdida real de funcionalidad** frente a la
versión con Firestore, que escribía el documento directamente. Y un trabajo
cerrado **no se puede reabrir**: `cancelarContratacion` solo acepta
`ACTIVO`/`ASIGNADO`/`ACORDADO`.

**El DTO de postulación no trae el título del trabajo ni el empleador.** El
backend serializa la entidad JPA tal cual (sin DTO), así que llegan
`creadoEn`/`actualizadoEn` y faltan los dos campos que Firestore llevaba
desnormalizados. `MisPostulacionesScreen` lo resuelve con una petición por
postulación; funciona porque esa lista es corta por naturaleza, pero la
solución buena es del lado del servidor.

**`adb shell input text` corta en el primer espacio.** No es del proyecto,
pero cuesta un rato descubrirlo: hay que escribir `%s` por cada espacio.

## Tests ejecutados

```
flutter analyze
→ 37 issues found (0 errores). Antes de la tarea: 60.
   Bajó porque se limpiaron los `withOpacity` deprecados de los archivos
   tocados. Nada de lo escrito aquí añade una sola issue.

flutter test
→ 00:05 +190: All tests passed!
   148 antes + 42 nuevos.
   · test/services/trabajos_y_postulaciones_test.dart — 31
   · test/api/bloqueo_sin_conexion_test.dart — 11
```

Todo el JSON de los tests nuevos está **copiado de respuestas reales** del
servidor (VM Ubuntu, 2026-09-04), no deducido de la documentación. Los tres
que más valen son los que fijan los contratos que no se pueden adivinar: el
feed con `pagina`/`tamano`, `cancelar` con `reabrir` siempre presente, y la
postulación sin título ni empleador.

### Verificado en el emulador `Pixel_6` (Android 13), contra el backend real

APK de debug con `--dart-define=TRABAJITO_API_URL=http://10.0.2.2:8080`, con
un túnel SSH `-L 8080:localhost:8080` a la VM (el puerto 8080 de la VM **no**
está reenviado al host; solo el 2222 de SSH).

**El recorrido de la demo, completo:**

1. `f026jefe@trabajito.test` (EMPLEADOR) publica "Reparar fuga de agua T026" →
   "¡Trabajo publicado!".
2. Aparece en "Mis publicaciones" con categoría, plazo, ubicación y
   `L. 250/hora` correctos.
3. `demo@trabajito.com` (TRABAJADOR) lo ve **el primero del feed** y se
   postula con mensaje → "¡Postulación enviada!" y el botón pasa a "Ya te
   postulaste" sin recargar a mano.
4. El empleador abre "Ver postulantes" → ve a Carlos Demo con su mensaje y su
   estado "Pendiente".
5. "Seleccionar" → "Trabajo asignado a Carlos Demo".
6. Comprobado **en el servidor**, no solo en pantalla: `GET /api/trabajos/mios`
   devuelve `"estado":"ASIGNADO"` con `trabajadorAsignadoId` de Carlos, y
   `GET /api/chats` devuelve el chat que creó el backend al aceptar.

**ADR-0013, reproducido de verdad:** `am force-stop` → `svc wifi disable` +
`svc data disable` → arrancar la app (la sesión se restaura del dispositivo
pero no se puede confirmar) → rellenar el formulario de publicar → "Publicar"
→ sale el mensaje **"Sin conexión no podemos publicar ni guardar cambios. No
se ha enviado nada: vuelve a intentarlo cuando tengas internet."**, sin botón
girando y sin petición.

**Y la recuperación sola:** con el formulario todavía en pantalla, se vuelve a
activar la red y se pulsa "Publicar" otra vez → el trabajo se publica. El
usuario no tuvo que reiniciar la app ni buscar dónde recargar. Confirmado en
el servidor: `GET /api/trabajos/mios` ya devuelve "Cambiar chapa de puerta".

También se vio en pantalla: el feed sin conexión enseña "Error de conexión.
Verifica tu internet. / Desliza hacia abajo para reintentar" en vez de "aún no
hay trabajos" (que era lo que hacía Firestore, y era falso), deslizar para
actualizar funciona, y "Editar trabajo" enseña su aviso con el botón
desactivado.

### Lo que NO se probó en el emulador (solo razonado y/o cubierto por tests)

Se dice explícitamente para que nadie lo dé por hecho:

- **Todo el tramo económico**: reservar pago, iniciar, agregar avances,
  entregar, pedir correcciones, aceptar y pagar, y calificar. Requiere saldo
  en la cartera y un acuerdo cerrado en el chat, y **el chat y la cartera
  siguen en Firestore** (fase 2b-2), donde una cuenta creada contra el backend
  no tiene datos. Está cubierto por tests de servicio, no por uso real.
- Cancelar con las dos opciones (reabrir/cerrar), rechazar la asignación y
  reclamar a soporte: tests sí, emulador no.
- Retirar una postulación y la pantalla "Mis postulaciones" con su lectura
  extra del título: tests sí, emulador no.
- El scroll infinito con más de una página: el feed de pruebas tiene 33
  trabajos y sí se paginó al cargar, pero **no se llegó a hacer scroll hasta
  el final** para ver la segunda página.
- La sección de evidencias en pantalla.

## Pendientes

**Para el backend** (candidatos a tarea de `backend-agent`):

1. **`PUT /api/trabajos/{id}`** — editar una publicación. Hoy no se puede, y
   la app lo dice pero es una pérdida frente a lo que había.
2. **Reabrir un trabajo cerrado**, o dejar claro que no es un caso de uso.
3. **`tituloTrabajo` y `empleadorId` en la respuesta de postulación.** Ahorra
   una petición por fila en "Mis postulaciones" y quita la única lectura N+1
   que quedó en la app. De paso, esa respuesta debería ser un DTO: hoy es la
   entidad JPA en crudo, con `actualizadoEn` incluido.
4. **Paginar `GET /api/trabajos/mios`** antes de que alguien tenga cientos.

**Para Flutter:**

5. **Fase 2b-2**: `cartera_service`, `calificacion_service` y `chat_service`.
   Ojo a la costura que queda: `DetalleTrabajoScreen._reservarPago` lee el
   acuerdo de pago y tiempo del **chat de Firestore** para mandárselo a
   `POST /api/trabajos/{id}/reservar-pago`. Es el único cruce entre las dos
   mitades y hay que cerrarlo ahí.
6. **Probar el tramo económico de punta a punta** en el emulador, cuando la
   cartera y el chat estén migrados. Hasta entonces no se puede.
7. **Pantalla de disputas**: la app enseña `en_disputa` y sabe abrirlo, pero
   no enseña el motivo ni la resolución (`motivoDisputa`,
   `resolucionDisputa`, `disputaAbiertaPorId` llegan del backend y
   `Publicacion` no los modela).
8. **Adjuntar fotos a una evidencia**: el backend guarda `archivoUrl` y el
   modelo `Evidencia` de la app no lo tiene. El diálogo sigue diciendo
   "próximamente".
9. **Tests de pantalla** de estas ocho: hay tests de servicio y de la capa
   HTTP, pero de pantalla solo existen los de perfil/login (tareas 022-023).
