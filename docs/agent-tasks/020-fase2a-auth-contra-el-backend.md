---
id: 020
titulo: "Migración fase 2a: la app se autentica contra el backend, no contra Firebase"
estado: hecho
agente: "flutter-agent"
creada: 2026-08-27
rama: "feature/fase2-auth-contra-backend"
---

## Objetivo

Primer servicio real que se migra (ADR-0009, épica 014). **Todo lo demás
depende de esto**: sin token del backend, ningún otro servicio puede migrar.

Cuando termines, un usuario debe poder **registrarse, iniciar sesión, ver su
perfil, editarlo y cerrar sesión** hablando con el backend propio, sin pasar
por Firebase Authentication.

## Lo que ya está listo y NO hay que rehacer

- **`lib/services/api/`** (fase 1, tarea 018): `ApiClient` con cabecera
  `Authorization` automática, renovación de token con doble candado,
  traducción de errores de ADR-0008, almacén seguro, timeouts. **Úsalo, no
  escribas otro.** Lee su reporte antes de tocarlo.
- Los 7 modelos ya tienen `desdeJson()`/`aJson()`.
- **El backend ya guarda el perfil completo** (tarea 019): habilidades,
  experiencia, estudios, teléfono de emergencia, fecha de nacimiento, etc.
  Ya no se pierde nada al migrar.

## Avisos de contrato (los dejó la tarea 019 en `docs/api.md` — respétalos)

1. **`fechaNacimiento` llega en ISO** (`"1995-03-15"`), no como `dd/MM/yyyy`.
   Hay que formatearla al mostrar. Al enviar se aceptan ambas.
2. **Las tres listas del CV (`habilidades`, `experiencia`, `estudios`)
   llegan `null` en login y registro** — `null` significa "no viene en esta
   respuesta", NO "el usuario no tiene". Para el perfil completo hay que
   pedir `GET /api/auth/yo`. Si tratas `null` como lista vacía, borrarás el
   CV del usuario al guardar.
3. **El perfil ajeno ya no trae correo, DNI, teléfonos, fecha de nacimiento
   ni saldo** (vienen `null` por privacidad, verificado). Las pantallas que
   muestren el perfil de otro no deben esperar esos campos.
4. El login puede responder **429** con `Retry-After` — muéstralo como un
   mensaje entendible ("demasiados intentos, espera X minutos"), no como
   error genérico.
5. **El servidor exige 18 años** en `fechaNacimiento` (antes solo lo
   comprobaba la pantalla) y contraseñas de **10 a 72 caracteres** (antes
   Firebase pedía 6). El formulario de registro debe pedir lo mismo, o el
   usuario rellenará todo para que el servidor lo rechace al final.

## Alcance

1. Reescribir `lib/services/auth_service.dart` para usar `ApiClient`:
   registro, login, `GET /api/auth/yo`, editar perfil (`PUT /api/usuarios/me`),
   cerrar sesión (`POST /api/auth/logout`), ver perfil ajeno.
2. Adaptar las pantallas que dependen de la sesión: `main.dart`
   (`PantallaInicial` decide con `authStateChanges()` de Firebase — eso
   desaparece), `login_screen.dart`, los dos registros,
   `editar_perfil_screen.dart`, `configuracion_screen.dart`.
3. **Los `Stream` que desaparecen.** `streamUsuarioActual` y
   `streamTrabajadores` hoy son streams de Firestore. Según la decisión del
   `tech-lead` (ver tarea 018): **carga puntual + "deslizar para
   actualizar"**, salvo el chat. Para el usuario actual, lo natural es un
   objeto de sesión en memoria que se refresca al iniciar y tras editar.
4. **No migres todavía** los otros 5 servicios: siguen con Firestore y deben
   seguir funcionando. La app quedará mixta durante esta fase, y eso está
   bien: los datos de Firebase son de prueba (ADR-0009).

## Criterios de aceptación

- [x] Registro, login, ver perfil, editar perfil y cerrar sesión funcionan
      **contra el backend real**, no contra Firebase.
- [x] El registro de trabajador guarda el perfil completo (los 5 pasos:
      habilidades, experiencia, estudios) y al volver a entrar se ve todo.
- [x] Cerrar sesión invalida la sesión de verdad en el servidor.
- [x] Los errores del backend se muestran en español y de forma entendible
      (el `message` ya viene listo; los `fields` sirven para marcar el campo
      que falló en el formulario).
- [x] `flutter analyze` sin errores nuevos; `flutter test` pasa (hoy 86).
- [x] Tests de lo migrado.

## Fuera de alcance

- Los otros 5 servicios (fase 2b y siguientes).
- Quitar `firebase_auth` de `pubspec.yaml`: **todavía no**, porque los otros
  servicios siguen usando Firestore. Eso es la fase 3.
- El doble rol (tarea 012).

## Notas del agente que la ejecuta

**Hecho el 2026-08-27.** Registro, login, ver perfil, editarlo y cerrar
sesión ya hablan con el backend propio. Firebase Auth desaparece de la
autenticación; `firebase_core` y `cloud_firestore` siguen porque los otros
cinco servicios no se han migrado (era el alcance pedido).

Lo que conviene saber si retomas esto:

1. **El estado de sesión que daba `authStateChanges()`** vive ahora en
   `lib/services/sesion_usuario.dart`: un `ValueNotifier<EstadoSesion>` con
   tres fases explícitas (`comprobando` / `sinSesion` / `conSesion`). Las
   tres hacían falta: si "aún no sé" y "no hay sesión" fueran lo mismo, el
   login parpadearía en cada arranque de alguien que sí tiene sesión.
2. **Tras el login y el registro se pide `GET /api/auth/yo`.** Cuesta una
   petición más y es a propósito: es la única lectura que trae el CV. Sin
   ella, el perfil en memoria tendría las tres listas vacías y la pantalla
   de edición borraría el currículum del usuario al guardar.
3. **`Usuario.cvCargado`** distingue "no tiene CV" de "esta respuesta no lo
   traía". `Usuario.aJson()` no manda nunca las listas del CV, aunque el
   backend las acepte: se escriben por sus sub-recursos, con una lista que
   alguien haya compuesto a conciencia.
4. **Lo que el backend todavía no sabe hacer** (tarea 017) ya no se finge:
   restablecer contraseña, cambiarla y verificar el correo avisan con un
   mensaje honesto en vez de decir que enviaron un correo que nadie manda.
5. **La baja de cuenta es lógica, no un borrado.** El texto de la pantalla
   se corrigió; antes prometía un borrado permanente que ya no ocurre.
6. **La app queda mixta y hay una consecuencia que no se puede tapar:** el
   `uid` ahora es el UUID del backend, y en Firestore no existe. Las
   pantallas que siguen leyendo Firestore no encontrarán datos de una
   cuenta creada contra el backend. Está explicado en el reporte; es
   inherente a migrar la autenticación primero, no un descuido.

Detalle completo, incluidas las cinco cosas que quedan pendientes para la
fase 2b, en `docs/agent-reports/020-fase2a-auth-contra-el-backend.md`.
