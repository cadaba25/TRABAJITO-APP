---
id: 023
titulo: "La app no avisa de que el perfil que enseña es de hace un rato (sesión restaurada sin conexión)"
estado: hecho
agente: "flutter-agent"
creada: 2026-08-29
rama: "fix/aviso-sin-conexion-perfil"
---

## Por qué existe

Hallazgo de la revisión de QA de la tarea 022, **reproducido en el emulador
Pixel_6 contra el backend real**. No es una hipótesis.

Cuando la app arranca sin conexión y hay sesión guardada,
`AuthService.restaurarSesion()` entra igual con el perfil que se guardó junto
a la sesión (el que devolvió el login). Esa decisión es correcta y está
razonada: *"echar al usuario porque le falló el wifi sería peor"*. El problema
es lo que pasa después:

1. **Ese perfil no trae el CV** (`habilidades`, `experiencia` y `estudios`
   llegan `null` en el login) y puede estar viejo en todo lo demás.
2. La pestaña "Perfil" lo pinta tal cual: `Experiencias 0`, `Estudios 0`,
   **"Sin habilidades registradas"**. Para el usuario eso se lee como *"la app
   me borró el CV"*, aunque en el servidor esté intacto.
3. **`EstadoSesion.avisoSinConexion` existe justo para esto y no lo consume
   nadie.** `grep avisoSinConexion lib/` solo encuentra la declaración y el
   sitio donde se pone a `true`. Ninguna pantalla lo lee.
4. **No hay forma de refrescar el perfil desde la interfaz.** `PerfilTab` no
   tiene "deslizar para actualizar" (sí lo tienen `TrabajadoresTab` y
   `RankingTab`). Cuando vuelve la conexión, el perfil sigue viejo hasta que
   el usuario cierre y abra la app, o edite el perfil.

La consecuencia **destructiva** de esto (guardar el perfil desde ese estado
borraba la presentación y descartaba en silencio las habilidades escritas)
**ya se arregló en la tarea 022**: `EditarPerfilScreen` ahora pide el perfil
completo antes de dejar editar, y si no puede, lo dice y no enseña el
formulario. Lo que queda aquí es lo **informativo**: que el usuario sepa que
está viendo datos viejos y pueda pedir los de verdad.

## Cómo reproducirlo

Con una cuenta que tenga CV (por ejemplo `qa022a@trabajito.test`, creada en la
022, con 2 habilidades, 1 experiencia y 1 estudio):

```bash
adb shell svc wifi disable && adb shell svc data disable
adb shell am force-stop com.trabajito.trabajito
adb shell monkey -p com.trabajito.trabajito -c android.intent.category.LAUNCHER 1
# entrar en la pestaña Perfil
```

Se ve `Experiencias 0`, `Estudios 0`, "Sin habilidades registradas" y **ningún
aviso** de que no hay conexión. Al volver la red, sigue igual hasta reiniciar.

## Qué habría que hacer (a decidir por producto)

- Enseñar un aviso cuando `sesionActual.value.avisoSinConexion` sea `true`
  ("Sin conexión: estos datos son de tu última visita"), o
- no pintar las secciones del CV cuando `!usuario.cvCargado` en vez de
  pintarlas a cero (que es lo que se lee como "borrado"), y
- añadir "deslizar para actualizar" en `PerfilTab` que llame a
  `AuthService.recargarPerfil()`, para que al volver la conexión el usuario
  pueda arreglarlo sin reiniciar la app.

Son tres decisiones de interfaz, por eso no se hicieron dentro de la 022:
tocan qué se le promete al usuario, no un fallo mecánico.

## Fuera de alcance

- Cachear el CV completo en el dispositivo. Es otra discusión (qué datos
  personales se guardan en local y con qué caducidad) y merece su propia
  tarea, no colarse aquí.

## Notas del agente que la ejecuta

Hecho el 2026-08-30. Se hicieron las **tres** cosas que proponía la sección de
arriba, porque separadas no resuelven el caso: el aviso sin gesto de recarga
deja al usuario mirando datos viejos, y el gesto sin aviso no le dice por qué
tendría que usarlo.

1. **Aviso** arriba de la pestaña Perfil cuando `avisoSinConexion` es `true`
   ("Sin conexión: estos son los datos de tu última visita"), en amarillo de
   advertencia y no en rojo de error: no hay nada roto, solo datos de antes.
   Es el primer sitio de la app que lee esa bandera.
2. **El CV que no se ha cargado ya no se pinta a cero**: se ocultan las filas
   `Experiencias`/`Estudios` y, en lugar de "Sin habilidades registradas", va
   una tarjeta que dice "No pudimos cargar tu currículum" y —lo importante—
   que **no se ha borrado nada**.
3. **"Deslizar para actualizar"** con `RefreshIndicator` sobre
   `recargarPerfil()`, más **un único intento automático** al abrir la pestaña
   si ya se sabe que los datos están sin confirmar o incompletos. No es sondeo
   y hay un test que se pone rojo si alguien lo convierte en eso.

Verificado en el emulador Pixel_6 contra el backend real con la cuenta
`qa022a@trabajito.test` (tiene CV): modo avión → arranque → Perfil enseña el
aviso y la tarjeta honesta; "Reintentar" sin red da "Error de conexión";
devolver la red y deslizar trae el CV entero (Experiencias 1, Estudios 1, 3
habilidades) y quita el aviso; y volver a la pestaña con la red ya de vuelta lo
arregla solo. +4 tests (144 → 148), `flutter analyze` de 62 a 60 issues.

Reporte: `docs/agent-reports/023-perfil-viejo-sin-conexion-no-se-avisa.md`.
