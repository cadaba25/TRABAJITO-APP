---
id: 020
tarea: docs/agent-tasks/020-fase2a-auth-contra-el-backend.md
agente: "flutter-agent"
fecha: 2026-08-27
---

## Objetivo (copiado de la tarea)

Primer servicio real que se migra (ADR-0009, épica 014). **Todo lo demás
depende de esto**: sin token del backend, ningún otro servicio puede migrar.

Cuando termines, un usuario debe poder **registrarse, iniciar sesión, ver su
perfil, editarlo y cerrar sesión** hablando con el backend propio, sin pasar
por Firebase Authentication.

## Cambios realizados

### 1. `lib/services/auth_service.dart` — reescrito entero

De `firebase_auth` + escrituras directas a Firestore, a `ApiClient` sobre
`/api/auth/**` y `/api/usuarios/**`. La forma pública (`Future<String?>`:
`null` = bien, texto = mensaje ya en español) **se conservó a propósito**: es
lo que esperan las once pantallas que llaman aquí, y cambiarla a excepciones
habría convertido esta tarea en una reescritura de la UI entera.

| Antes (Firebase) | Ahora (backend) |
|---|---|
| `crearCuentaAuth()` + `guardarPerfil()` (dos pasos) | `registrar()` → un `POST /api/auth/registro` |
| `iniciarSesion()` | `POST /api/auth/login` + `GET /api/auth/yo` |
| `cerrarSesion()` (solo local) | `POST /api/auth/logout`, **revoca en el servidor** |
| `actualizarCampos()` (write directo a Firestore) | `PUT /api/usuarios/me` |
| `obtenerUsuarioPorUid()` | `GET /api/usuarios/{id}` (vista pública) |
| `streamUsuarioActual()` | `recargarPerfil()` + `sesionActual` |
| `streamTrabajadores()` | `listarTrabajadores()` → `GET /api/usuarios/ranking` |
| `eliminarCuenta()` (borraba documentos) | `darDeBajaCuenta()` → `DELETE /api/usuarios/me` (baja **lógica**) |
| — | `reemplazarHabilidades()`, `agregarExperiencia()`, `agregarEstudio()` |
| — | `restaurarSesion()`, `escucharFinDeSesion()` |

El registro dejó de tener la ventana desagradable que tenía con Firebase: la
cuenta en Auth podía crearse y el documento de Firestore fallar, dejando una
cuenta sin perfil. El backend lo hace en una transacción.

### 2. `lib/services/sesion_usuario.dart` (nuevo) — lo que sustituye a `authStateChanges()`

`ValueNotifier<EstadoSesion>` con **tres fases explícitas**:
`comprobando` / `sinSesion` / `conSesion`. El `Stream<User?>` de Firebase
tenía esos mismos tres estados, pero implícitos (no ha emitido / emitió
`null` / emitió un usuario). Hacerlos explícitos importa: si "aún no sé" y "no
hay sesión" se confundieran, el login parpadearía en cada arranque de alguien
que sí tiene sesión guardada.

Es un `ValueNotifier` porque es lo que este proyecto ya usa para el tema
(`notificadorTema`): las pantallas lo consumen con `ValueListenableBuilder` sin
traer ninguna librería de estado.

### 3. `lib/main.dart`

`PantallaInicial` pasa de `StreamBuilder<User?>` a `ValueListenableBuilder`.
`main()` ya no llama a `FirebaseAuth`; llama a `restaurarSesion()` (sin
esperarla: `PantallaInicial` ya enseña la pantalla de carga, así que el primer
frame no espera a la red) y a `escucharFinDeSesion()`.

`Firebase.initializeApp()` **se queda**: cinco de los seis servicios siguen en
Firestore.

### 4. Pantallas adaptadas

- **`login_screen`**: no navega tras el login (`PantallaInicial` lo hace sola).
  Ya no valida "mínimo 6 caracteres" al entrar —quien se registró antes del
  cambio de política tiene una contraseña más corta y debe poder entrar—.
  "¿Olvidaste tu contraseña?" pasa de formulario a aviso honesto.
- **`registro_trabajador_screen`** (5 pasos) y **`registro_empleador_screen`**
  (3 pasos): paso 1 = `POST /api/auth/registro`; el resto, `PUT /api/usuarios/me`
  y los sub-recursos del CV. **Ahora se comprueba el resultado de cada paso**:
  antes se ignoraba el error de `actualizarCampos()`, lo que con un backend que
  valida de verdad (edad mínima) habría hecho avanzar el formulario tras un
  fallo. La contraseña pide 10–72 caracteres.
- **`editar_perfil_screen`**: las habilidades van por su ruta, y **solo si
  `cvCargado`**. "Cambiar contraseña" pasa a aviso.
- **`configuracion_screen`**: `darDeBajaCuenta()` y el texto corregido.
- **`inicio_screen`**: el perfil viene de `sesionActual`.
- **`trabajadores_tab`** y **`ranking_tab`**: de `StreamBuilder` de Firestore a
  `FutureBuilder` + `RefreshIndicator`, **con estado de error visible**. Con
  Firestore un fallo se quedaba en un stream vacío y el usuario leía "no hay
  trabajadores"; ahora se ve el mensaje del backend y se puede reintentar
  deslizando.

### 5. Modelos

- `Usuario.cvCargado` (ver "Decisiones").
- `Usuario.fechaNacimientoLegible` y `fechaNacimientoVisible()` en
  `json_utiles.dart`: el backend devuelve la fecha en ISO.
- `Experiencia.id` y `Estudio.id`: son sub-recursos con UUID propio.
  `aJson()` no manda el `id` (lo decide el servidor y viaja en la URL).

### 6. `RutasApi` y `ReglasCuenta`

Nueve rutas nuevas de perfil en `configuracion_api.dart`. `ReglasCuenta` en
`constantes.dart` fija en un solo sitio lo que **el servidor impone**: 10–72
caracteres de contraseña y 18 años.

## Archivos modificados

Nuevos:
- `lib/services/sesion_usuario.dart`
- `test/services/auth_service_test.dart`
- `test/models/perfil_completo_json_test.dart`

Reescritos:
- `lib/services/auth_service.dart`
- `test/pantalla_inicial_test.dart`

Modificados:
- `lib/main.dart`
- `lib/models/usuario.dart`, `lib/models/json_utiles.dart`
- `lib/services/api/configuracion_api.dart`
- `lib/utils/constantes.dart`
- `lib/screens/login_screen.dart`, `inicio_screen.dart`,
  `editar_perfil_screen.dart`, `configuracion_screen.dart`,
  `postulantes_screen.dart` (solo quitar un import muerto)
- `lib/screens/registro/registro_trabajador_screen.dart`,
  `registro_empleador_screen.dart`
- `lib/screens/tabs/trabajadores_tab.dart`, `ranking_tab.dart`
- `docs/agent-tasks/020-...md`, `docs/agent-context/repo-snapshot.md`,
  `docs/architecture.md`

**No se tocó** `backend/**`, `firestore.rules`, `pubspec.yaml` ni los otros
cinco servicios. `firebase_auth` sigue en `pubspec.yaml` (fase 3), aunque ya
**ningún archivo de `lib/` lo importa**.

## Decisiones tomadas

### `Usuario.cvCargado`: la que evita borrar currículums

El aviso de la tarea era serio y la solución no podía ser "acordarse". El
backend manda `habilidades`, `experiencia` y `estudios`:

| Respuesta | Las tres listas |
|---|---|
| `POST /api/auth/login` | `null` |
| `POST /api/auth/registro` | `null` |
| `GET /api/usuarios/ranking` | `null` |
| `GET /api/auth/yo` | lista (vacía si no tiene) |
| `GET /api/usuarios/{id}` | lista |
| respuesta de `PUT /api/usuarios/me` | lista |

Verificado contra el servidor: un usuario recién registrado responde
`"habilidades":[]` en `/api/auth/yo`, **no `null`**. Así que `null` es un
discriminador fiable: significa "no viene", nunca "no tiene".

Tres barreras, no una:

1. `Usuario.cvCargado` guarda si la respuesta traía las listas.
2. `Usuario.aJson()` **nunca** manda el CV, aunque `PUT /api/usuarios/me`
   acepte `habilidades` en el mismo cuerpo. El CV se escribe por sus
   sub-recursos, con una lista que alguien haya compuesto a conciencia.
   `AuthService.actualizarCampos()` filtra `habilidades` incluso si se la
   pasan, y hay un test que lo fija.
3. Tras el login y el registro se pide `GET /api/auth/yo`, así que el perfil
   en memoria está siempre completo. Cuesta una petición más; es barato
   comparado con el fallo que evita.

### Los `Stream` que desaparecen

La tarea remitía a la decisión del `tech-lead` (carga puntual + deslizar para
actualizar, salvo el chat). Aplicado así:

- **Usuario actual**: objeto en memoria (`sesionActual`), que se rellena al
  arrancar y se refresca tras cada edición. No hay sondeo.
- **Lista de trabajadores / ranking**: `FutureBuilder` + `RefreshIndicator`.

El `RefreshIndicator` necesita un hijo desplazable: los carteles de "no hay
nada" y de error van dentro de un `ListView`, o el usuario se quedaría sin
forma de reintentar.

### `GET /api/usuarios/ranking` alimenta las dos pestañas de personas

Es la única lista de personas que expone el backend. Para "Ranking" es
exactamente lo que hace falta. Para "Trabajadores" es un **recorte**: top 50
por trabajos completados, y sin CV (vista pública), así que la tarjeta ya no
puede enseñar la especialidad sin abrir el perfil. Está anotado en Pendientes;
no se inventó un endpoint.

### Lo que el backend no sabe hacer se dice, no se finge

`enviarResetPassword`, `cambiarContrasena` y `enviarVerificacionCorreo`
devuelven un aviso y **no hacen ninguna petición** (hay tests que lo
comprueban). Firebase daba las tres de serie; el backend no tiene endpoint
(tarea 017 abierta). Enseñar un formulario que no guarda nada, o decir "te
enviamos un correo" cuando nadie lo manda, sería peor que el aviso.

### La baja de cuenta no borra

`DELETE /api/usuarios/me` desactiva (`activo = false`); después no se puede
iniciar sesión (verificado: 401). El diálogo prometía un borrado permanente,
así que se reescribió el texto. **No es un cambio cosmético**: prometer un
borrado que no ocurre es exactamente el tipo de cosa por la que una app se
mete en problemas legales.

### `AuthService` sigue devolviendo `String?`

Ver arriba. Se añadió `ultimoErrorPorCampo` para que un formulario pueda
marcar el campo concreto que falló, usando el `fields` de ADR-0008.

### Un fallo de red al arrancar no expulsa al usuario

Si hay sesión guardada pero no hay conexión, se entra con el perfil guardado y
`avisoSinConexion = true`. Ese perfil viene del login, así que llega con
`cvCargado = false` y no puede usarse para reescribir el CV. Coherente con la
decisión de la tarea 018 (un fallo de red no mata la sesión): el caso de uso
de esta app es gente trabajando en la calle con cobertura intermitente.

### Se reconectó `eventosSesion` (pendiente nº 8 de la tarea 018)

`main()` llama a `escucharFinDeSesion()`. Sin eso, un refresh token revocado
dejaba al usuario dentro de una pantalla donde ya no cargaba nada: el cliente
HTTP se enteraba, la interfaz no.

## Problemas encontrados

### 1. El `uid` cambia de significado — la consecuencia grande de migrar auth primero

Antes era el `uid` de Firebase; ahora es el UUID del backend. Los otros cinco
servicios reciben ese identificador y consultan **Firestore**, donde no
existe. Consecuencias reales de una cuenta creada contra el backend:

- Sus publicaciones, postulaciones, chats y tarjetas salen vacíos.
- Peor: `firestore.rules` empieza con `request.auth != null` en todas las
  colecciones. Al no haber sesión de Firebase Auth, **Firestore rechaza
  también las lecturas**, no solo las escrituras.

Esto **no se puede evitar** migrando la autenticación primero, que es el orden
que fijó el `tech-lead` en la épica 014 y que es correcto (sin token no se
puede migrar nada más). Lo que sí se hizo es que **se vea**: las dos pestañas
migradas enseñan el error y ofrecen reintentar, en vez de fingir una lista
vacía. Las que siguen en Firestore no se tocaron.

Se descartó a propósito un `signInAnonymously()` de Firebase como puente: crea
cuentas anónimas basura, depende de que ese proveedor esté habilitado en la
consola (no verificable desde aquí), y de todas formas `request.auth.uid` no
coincidiría con el UUID del backend, así que las reglas de dueño seguirían
fallando. Sería complejidad a cambio de una ilusión.

**Impacto real hoy: ninguno para usuarios reales.** No hay usuarios reales, y
ADR-0009 dice que los datos de Firebase son de prueba y se descartan. Pero
quien pruebe la app entre esta fase y la 2b debe saberlo.

### 2. `RegistroRequest` no acepta la fecha de nacimiento

Se le mandó `fechaNacimiento` al registro y el servidor la ignoró en silencio
(el DTO solo admite correo, contraseña, nombres, apellidos, DNI, teléfono,
rol, departamento y ciudad). No es un fallo —el formulario la pide en el paso
2, no en el 1—, pero conviene saberlo: **el registro no valida la edad**; la
valida el `PUT` posterior. Un cliente que solo llamara al registro crearía una
cuenta sin fecha de nacimiento y sin comprobación de los 18 años.

### 3. Los `_` repetidos en patrones, y por qué acabaron ahí

Primer intento con `__`/`___` como huecos: 50 avisos de
`constant_identifier_names`. Segundo intento con un registro de campos con
nombre y desestructuración parcial (`final (:auth, :espia) = ...`): **no
compila**, los patrones de registro exigen que el tipo coincida entero. La
forma que funciona es `final (auth, _, _, _) = ...`: en Dart 3 el guion bajo
es un comodín de patrón y se puede repetir.

### 4. El servidor de pruebas se cayó a mitad de la verificación

Ver "Tests ejecutados": el contrato se verificó punto por punto **antes** de
escribir el parseo, pero el guion de flujo completo de punta a punta no se
llegó a ejecutar de una pieza. Está dicho ahí con detalle.

### 5. Sin emulador, otra vez

Sigue sin haber emulador ni dispositivo físico en este entorno, así que
`flutter_secure_storage` **nunca se ha ejecutado de verdad**: los tests usan
el doble en memoria. Es el pendiente nº 6 de la tarea 018 y sigue abierto,
ahora con más urgencia: antes la capa HTTP no la usaba nadie; ahora es el
camino del login.

## Tests ejecutados

```
$ flutter analyze
62 issues found. (ran in 4.2s)      # 0 errores
```

**Baja de 65 a 62** (el baseline del snapshot). Los 62 son preexistentes
(`withOpacity` deprecado, `use_build_context_synchronously`, un campo sin
usar). Bajan tres porque se limpió un import muerto en `postulantes_screen`
y se corrigió el nombre del parámetro de un `operator ==`. **Cero issues en
todo lo nuevo:**

```
$ flutter analyze test/services/auth_service_test.dart
No issues found!
```

```
$ flutter test
00:03 +135: All tests passed!
```

**De 86 a 135 (+49):**

| Archivo | Tests | Qué cubre |
|---|---|---|
| `test/services/auth_service_test.dart` | 30 | login (429 con `Retry-After`, 400 con `fields`, 401 como credenciales y no como sesión caducada), registro, `restaurarSesion` en sus cuatro desenlaces, logout que revoca de verdad, `PUT /me` (filtrado de campos, `fotoPerfil`→`fotoUrl`, `null` que no viaja), los tres sub-recursos del CV, ranking, perfil ajeno, baja de cuenta, la sesión que muere sola |
| `test/models/perfil_completo_json_test.dart` | 17 | `cvCargado` en sus cuatro casos, ids de `Experiencia`/`Estudio`, fecha ISO → dd/MM/aaaa, campos que oculta el perfil ajeno |
| `test/pantalla_inicial_test.dart` | 5 (antes 3) | las tres fases de sesión y las dos transiciones |
| preexistentes | 83 | sin cambios |

Los cuatro que más valen son los del `null` del CV, porque cubren un fallo que
**no da ningún error**: guardar tratando ese `null` como lista vacía funciona
perfectamente y deja al usuario sin currículum.

`test/pantalla_inicial_test.dart` quedó bastante más corto: ya no hace falta
suplantar `FirebaseAuthPlatform` con tres clases falsas (~60 líneas) para
probar tres ramas de un `if`; basta con poner el estado en `sesionActual`.
Sigue haciendo falta `setupFirebaseCoreMocks()` porque `InicioScreen` abre el
stream de chats de Firestore (fase 2b).

### Verificado contra el servidor real (VM Ubuntu, 2026-08-27)

**Antes de escribir el parseo**, no deducido de `docs/api.md`:

- `POST /api/auth/registro` → 200 con `{token, refreshToken, tokenType,
  expiraEnSegundos:900, usuario:{...}}`, y `habilidades`/`experiencia`/
  `estudios` a **`null`**.
- `GET /api/auth/yo` → perfil completo. En un usuario **sin** CV devuelve
  `[]`, **no `null`**: es lo que hace fiable el discriminador de `cvCargado`.
- `PUT /api/usuarios/me` con `"fechaNacimiento":"15/03/1995"` → responde
  `"1995-03-15"` (entra en las dos formas, **sale siempre en ISO**).
- `PUT /api/usuarios/me` **sin** `habilidades`, sobre un usuario que sí tenía
  CV → la respuesta trajo `habilidades`, `experiencia` y `estudios`
  **intactos**. Es la prueba directa de que editar el perfil como lo hace la
  app no borra el CV.
- `PUT /api/usuarios/me/habilidades` → devuelve la lista ya guardada.
- `POST /api/usuarios/me/experiencia` y `/estudios` → 201 con un `id` UUID.
- `PUT /api/usuarios/me` con `"01/01/2015"` → **400**, "Debes tener al menos
  18 años para usar Trabajito".
- Registro con contraseña de 6 caracteres → **400** con
  `fields.password: "La contraseña debe tener al menos 10 caracteres"`.
- `GET /api/usuarios/{id}` (vista pública) → `correo`, `dni`, `telefono`,
  `telefonoEmergencia`, `fechaNacimiento`, `genero`, `codigoPostal`, `rtn` y
  `saldo` a `null`; el CV **sí** viene.
- `GET /api/usuarios/ranking` → **array pelado**, no página de Spring, con el
  CV a `null`.
- `DELETE /api/usuarios/me` → 200; el login posterior → **401**.

### Lo que NO se pudo verificar — dicho explícitamente

1. **El guion de flujo completo de punta a punta no llegó a correr.** Se
   preparó (`/tmp/f020_flujo.sh`, 30 comprobaciones: registro → los 5 pasos →
   logout → volver a entrar → el CV sigue ahí → editar sin habilidades → el CV
   no se borró → privacidad del perfil ajeno → ranking → política de
   contraseña) y el túnel SSH a la VM dejó de responder
   (`kex_exchange_identification` y luego tiempo agotado en el saludo) antes
   de poder ejecutarlo. Se reintentó nueve veces. **Todas sus afirmaciones
   individuales sí están verificadas** por las llamadas de la lista de arriba,
   hechas antes de la caída; lo que falta es haberlas encadenado en una sola
   pasada. La única de esas 30 que no tiene equivalente ya comprobado es
   "cerrar sesión, volver a entrar y ver el CV intacto": el logout revocando
   el refresh token sí se comprobó (la 018 lo dejó verificado y aquí se
   repitió el 204), y el CV persistido también, pero **no encadenados**.
   Quien retome esto: el guion quedó guardado en
   `docs/agent-reports/scripts/020-verificar-auth-contra-el-backend.sh`, con las
   instrucciones para lanzarlo en su cabecera.
2. **La app no se ha ejecutado en un emulador ni en un dispositivo.** No hay
   ninguno en este entorno. Por tanto **no se ha probado**: que
   `flutter_secure_storage` persista la sesión entre arranques reales, que
   `10.0.2.2` resuelva desde el emulador, ni el
   `network_security_config.xml`. Todo lo de la sesión persistida está
   probado contra el doble en memoria, que **no ejercita el canal de
   plataforma**.
3. **No se probó qué se ve exactamente** en las pantallas que siguen en
   Firestore cuando el `uid` es un UUID del backend. Lo razonado está en
   "Problemas encontrados nº 1"; medirlo requiere el emulador.

### Efecto sobre el servidor de pruebas

Cuentas nuevas: `f020a`, `f020b`, `f020d` (dada de baja a propósito para
comprobar el `DELETE`) y `f020c`/`f020f` que **no** llegaron a crearse (400 por
contraseña corta). `f020b` tiene CV completo. Se gastaron 2 intentos fallidos
del cupo por IP. No se borró nada existente.

## Pendientes

En orden de urgencia para la fase 2b:

1. **[`flutter-agent`] Probar en un emulador de verdad, antes de seguir
   migrando.** Es lo más urgente. Ahora mismo el login entero depende de una
   capa que nunca se ha ejecutado fuera de `flutter test`. Confirmar
   `flutter_secure_storage` entre arranques, `10.0.2.2` y el
   `network_security_config`.
2. **[`backend-agent`] Un endpoint de trabajadores que no sea el ranking.**
   `GET /api/usuarios/ranking` está topado en 50 y ordenado por trabajos
   completados: sirve de ranking, no de directorio. Hace falta listado con
   paginación, búsqueda y filtro por departamento/habilidad, y decidir si la
   tarjeta debe traer la especialidad (hoy la vista pública del listado no
   trae CV, así que la tarjeta dice "Profesional" para todo el mundo).
3. **[`tech-lead`] Decidir qué se hace con las pantallas que siguen en
   Firestore durante la fase 2b.** Ver "Problemas nº 1": con auth migrada, no
   pueden funcionar. Las opciones son migrarlas seguidas (2b corta y densa) o
   marcarlas como no disponibles mientras tanto.
4. **[`backend-agent` + `security-agent`] Cambiar y recuperar contraseña**
   (tarea 017). Ahora mismo un usuario que olvide su contraseña **no tiene
   ninguna vía de recuperarla dentro de la app**. Con Firebase la tenía. Es
   una pérdida de funcionalidad real y visible, y la app ya solo puede
   ofrecer un correo de soporte.
5. **[`backend-agent`] `fechaNacimiento` en `RegistroRequest`**, o dejar
   escrito que la edad mínima solo se valida al editar el perfil. Ver
   "Problemas nº 2".
6. **[`flutter-agent`] Editar y borrar experiencia y estudios.** El backend ya
   tiene `PUT`/`DELETE` por id y el modelo ya guarda el `id`; la pantalla de
   edición todavía no los expone (con Firestore tampoco lo hacía: decía "La
   actualización de CV estará disponible pronto"). No es una regresión, pero
   ahora es barato.
7. **[`flutter-agent`] Enseñar `avisoSinConexion`.** El estado existe y nadie
   lo pinta: el usuario que entra sin conexión no ve que su perfil puede estar
   viejo.
8. **[`security-agent`] Revisar esta tarea.** Toca el ciclo de sesión, el
   almacenamiento del token y qué se manda en `PUT /api/usuarios/me`. La 018
   también sigue pendiente de su revisión.
9. **[`docs-agent`] `docs/api.md`**: dejar anotado que `RegistroRequest` no
   admite `fechaNacimiento` y que el ranking es la única lista de personas.
