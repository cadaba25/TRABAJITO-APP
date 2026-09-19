---
id: 023
tarea: docs/agent-tasks/023-perfil-viejo-sin-conexion-no-se-avisa.md
agente: "flutter-agent"
fecha: 2026-08-30
---

## Objetivo (copiado de la tarea)

Cuando la app arranca sin conexión y hay sesión guardada,
`AuthService.restaurarSesion()` entra con el perfil que se guardó junto a la
sesión (el que devolvió el login). Esa decisión es correcta. El problema es lo
que pasa después:

1. Ese perfil **no trae el CV** (`habilidades`, `experiencia` y `estudios`
   llegan `null`) y puede estar viejo en todo lo demás.
2. La pestaña "Perfil" lo pintaba tal cual: `Experiencias 0`, `Estudios 0`,
   **"Sin habilidades registradas"**. Para el usuario eso se lee como *"la app
   me borró el CV"*, aunque en el servidor esté intacto.
3. **`EstadoSesion.avisoSinConexion` existe justo para esto y no lo consumía
   nadie.**
4. **No había forma de refrescar el perfil desde la interfaz**: al volver la
   conexión seguía viejo hasta reiniciar la app o editar el perfil.

La parte destructiva (guardar desde ese estado borraba datos) ya se cerró en la
tarea 022. Lo que quedaba aquí es lo **informativo**.

## Cambios realizados

Tres decisiones de interfaz, todas la misma idea: **no prometerle al usuario
datos que no se tienen, y no enseñar como vacío algo que solo está sin cargar.**

1. **Se avisa de que el perfil es de la última visita.** Cuando
   `EstadoSesion.avisoSinConexion` es `true`, la pestaña Perfil enseña arriba
   del todo un aviso en amarillo de advertencia (no en rojo de error: la sesión
   funciona, lo único que pasa es que estos datos no se han podido confirmar):

   > **Sin conexión: estos son los datos de tu última visita.**
   > Desliza hacia abajo para actualizarlos cuando vuelvas a tener internet.

   Con un botón de recargar al lado, que mientras trabaja se convierte en una
   rueda en el mismo sitio. Es el primer sitio de la app que lee
   `avisoSinConexion`; hasta ahora la bandera existía y no la miraba nadie.

2. **El CV que no se ha cargado ya no se pinta a cero.** Si
   `Usuario.cvCargado == false`:
   - **desaparecen** las filas `Experiencias` y `Estudios` (un `0` ahí se lee
     como "no tengo ninguno", y es mentira), y
   - en lugar de `ChipsHabilidades` —que decía "Sin habilidades registradas"—
     va una tarjeta que dice lo que de verdad pasa:

     > **No pudimos cargar tu currículum.**
     > Tus habilidades, tu experiencia y tus estudios siguen guardados en tu
     > cuenta: aquí no se ha borrado nada. Vuelve a intentarlo cuando tengas
     > conexión.  · [Reintentar]

     La segunda frase es el punto entero de la tarea: lo que asusta al usuario
     no es que falte el CV, es creer que se lo han borrado.

3. **"Deslizar para actualizar" en `PerfilTab`**, con `RefreshIndicator` sobre
   `AuthService.recargarPerfil()`, igual que `TrabajadoresTab` y `RankingTab`.
   Como la lista puede caber entera en pantalla, lleva
   `AlwaysScrollableScrollPhysics` para que el gesto exista siempre. Un fallo
   al refrescar a mano enseña el mensaje del cliente HTTP tal cual ("Error de
   conexión. Verifica tu internet.") y deja los avisos donde estaban.

   Además, **un único intento automático al abrir la pestaña** y solo si ya se
   sabe que los datos están sin confirmar o incompletos
   (`avisoSinConexion || !cvCargado`). No es sondeo: no se repite, no hay
   temporizador, y con conexión normal no llega a ocurrir nunca (login y
   registro ya piden el perfil entero). Sirve para el caso más común de todos:
   arrancaste en el bus sin cobertura, te llega la red, vuelves a Perfil y se
   arregla solo. Ese intento es **silencioso** —no saca `SnackBar` de error—
   porque el usuario no ha pedido nada y el aviso que ya está en pantalla lo
   explica mejor.

Para que la pestaña sepa lo de la conexión, `InicioScreen` le pasa
`datosSinConfirmar: estado.avisoSinConexion`. De paso se corrigió ahí un detalle
del `ValueListenableBuilder`: antes hacía `_usuario = estado.usuario ?? _usuario`
y ahora solo copia usuario y bandera **juntos**, para que no puedan quedar
descompasados (usuario viejo con bandera nueva).

`PerfilTab` pasó de `StatelessWidget` a `StatefulWidget`, que es lo que pedía
tener una recarga en marcha.

## Archivos modificados

- `lib/screens/tabs/perfil_tab.dart` — los tres cambios de arriba.
- `lib/screens/inicio_screen.dart` — pasa `avisoSinConexion` a la pestaña.
- `lib/utils/constantes.dart` — 4 textos nuevos en `AppTextos`
  (`datosDeTuUltimaVisita`, `datosSinConfirmarDetalle`, `cvSinCargar`,
  `cvSinCargarDetalle`). Van ahí y no sueltos en la pantalla porque los
  comparten la pestaña y sus tests.
- `test/screens/perfil_tab_test.dart` — **nuevo**, 4 tests.
- `docs/agent-tasks/023-...md`, `docs/agent-context/repo-snapshot.md`, este
  reporte.

## Decisiones tomadas

- **Aviso de advertencia, no de error.** No hay nada roto: hay sesión y hay
  datos, solo que son de antes. Se usa `AppColores.advertencia` (el dorado de
  marca) y un texto que dice *qué* son los datos, no *qué falló*.
- **El aviso va en la pestaña Perfil, no en la barra de la app.** Es donde
  duele el problema (es el perfil lo que se ve viejo) y donde está el gesto que
  lo arregla. Ponerlo global habría obligado a decidir qué hacen las otras
  cuatro pestañas, que hoy siguen leyendo de Firestore y tienen su propio
  concepto de "sin datos" — eso es fase 2b.
- **Ocultar `Experiencias`/`Estudios` en vez de enseñar un guion.** Un `—` en
  esas filas obliga al usuario a interpretar; quitarlas y explicarlo una sola
  vez, en la tarjeta del CV, dice más con menos ruido.
- **El intento automático al abrir la pestaña.** Es lo único que no pedía la
  tarea literalmente. Se añadió porque sin él la promesa del aviso ("desliza
  para actualizar") solo se cumple si el usuario lee el aviso y hace el gesto,
  y porque el coste está acotado a un caso que ya se sabe malo. Está detrás de
  una condición explícita y hay un test que falla si alguien lo convierte en
  una petición incondicional.
- **No se tocó nada de la renovación de token** ni de los cinco servicios que
  siguen en Firestore.
- De paso se limpiaron los dos `withOpacity` deprecados que ya tenía
  `perfil_tab.dart` (`flutter analyze` baja de 62 a 60).

## Problemas encontrados

- **El emulador y los `RefreshIndicator` en test.** El indicador no dispara
  hasta un 25% de la altura del viewport, y los tests montan la pestaña en una
  ventana de 3000 px de alto (necesaria: un `ListView` solo construye lo que se
  ve, y sin eso "no aparece el CV a cero" sería cierto por estar fuera de
  pantalla, o sea un test que no prueba nada). El gesto de los tests arrastra
  1400 px a propósito.
- **`pumpAndSettle` no sirve en esta pantalla**: `SeccionResenas` sigue
  leyendo de Firestore (fase 2b) y en test puede quedarse girando. Los tests
  bombean a mano y descartan los errores de Firestore, igual que
  `test/pantalla_inicial_test.dart`.
- **Cambiar `ApiClient.fijarInstancia()` a mitad de un test no afecta a una
  pantalla ya montada**: `AuthService` captura la instancia al construirse. Se
  resolvió con un `bool hayRed` dentro del propio `MockClient`, que además
  imita mejor lo que pasa de verdad (el mismo cliente, la red que va y viene).

## Tests ejecutados

- `flutter analyze` → **60 issues, 0 errores** (antes de esta tarea: 62; todas
  son warnings/info preexistentes del resto del proyecto).
- `flutter test` → **148/148 pasan** (antes: 144). Los 4 nuevos están en
  `test/screens/perfil_tab_test.dart`:
  1. sin conexión, el perfil restaurado se enseña con su aviso y **sin pintar
     el CV a cero** (comprueba que NO aparecen "Sin habilidades registradas",
     "Experiencias" ni "Estudios", que SÍ aparece la tarjeta honesta, y que se
     intentó **una** lectura);
  2. deslizar para actualizar trae el perfil y retira los avisos (la red vuelve
     a mitad del test: llega el CV, aparecen las habilidades y el contador de
     experiencias, y el aviso desaparece);
  3. con el perfil completo y confirmado, abrir la pestaña **no pide nada** al
     servidor (este es el que se pondrá rojo si alguien convierte esto en
     sondeo);
  4. deslizar sobre un perfil bueno lo vuelve a pedir **una sola vez**.

**En el emulador de verdad** (Pixel_6, Android 13, APK de debug con
`--dart-define=TRABAJITO_API_URL=http://10.0.2.2:8080`, contra el backend real
de la VM, cuenta `qa022a@trabajito.test` que tiene CV: 3 habilidades, 1
experiencia, 1 estudio). Esto se **ejecutó**, no se razonó:

1. `svc wifi disable` + `svc data disable` → `am force-stop` → relanzar → pestaña
   Perfil: sale el aviso **"Sin conexión: estos son los datos de tu última
   visita"** y, más abajo, "No pudimos cargar tu currículum" con su
   "Reintentar". **Ya no salen `Experiencias 0`, `Estudios 0` ni "Sin
   habilidades registradas"** (que es exactamente lo que se veía antes).
2. Pulsar "Reintentar" sin conexión → `SnackBar` "Error de conexión. Verifica
   tu internet.", los avisos se quedan, no se enseña un CV vacío.
3. `svc wifi enable` + deslizar hacia abajo → el aviso desaparece y el perfil
   completo aparece: **Experiencias 1, Estudios 1, Electricidad / Pintura /
   Plomería**. Antes de esta tarea esto solo se arreglaba reiniciando la app.
4. Arrancar otra vez sin conexión (aviso presente), devolver la red, cambiar a
   la pestaña Trabajos y volver a Perfil → el aviso **ya no está**, sin ningún
   gesto: el intento automático al abrir la pestaña hizo su trabajo.

Capturas tomadas con `adb exec-out screencap -p` en cada uno de esos pasos.

**No se ejecutó** (y no se afirma que funcione): nada del backend —esta tarea
no toca `backend/`—, ni el resto de pestañas, ni iOS.

## Pendientes

- **Cachear el CV en el dispositivo.** Fuera de alcance por decisión de la
  propia tarea: guardar habilidades/experiencia/estudios en local es una
  decisión sobre datos personales y caducidad, y merece su tarea.
- **El resto de la app no dice nada cuando no hay conexión.** Trabajos,
  Trabajadores, Chats y Ranking siguen contra Firestore y cada una tiene su
  propio "no hay nada". Cuando la fase 2b los migre habrá que decidir si el
  aviso sube a un sitio único (barra de la app) en vez de repetirse pestaña a
  pestaña. Hoy sería prematuro.
- **Decisión de producto para el dueño**, no del agente: si al arrancar sin
  conexión la app debe seguir **entrando** con el perfil guardado (hoy sí, y
  parece lo correcto) o si algún día debería limitar qué se puede hacer desde
  ese estado —hoy solo se bloquea editar el perfil (tarea 022)—. Publicar un
  trabajo o postularse desde una sesión sin confirmar no está probado.
