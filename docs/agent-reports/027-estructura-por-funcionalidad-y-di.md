---
tarea: 027
titulo: "Reestructurar lib/ por funcionalidad, DI y techo de tamaño — PARTE A"
agente: "flutter-agent"
fecha: 2026-09-08
rama: "refactor/estructura-por-funcionalidad"
estado_tarea: "en-progreso (parte A hecha, parte B pendiente)"
---

# Tarea 027 — Parte A

Solo la **parte A**. La parte B (mover `trabajos`, `postulaciones` y `perfil`)
**no se ha tocado**, por instrucción explícita.

## Resumen en una línea

`lib/utils/constantes.dart` ya no existe, `autenticacion` vive en
`lib/funcionalidades/`, la app tiene inyección de dependencias con `provider`,
y una pantalla que no tenía test ya tiene cuatro. **Ni una regla de negocio ha
cambiado.**

## Evidencia de los criterios de aceptación

Todo lo de abajo es salida real de comandos en esta rama, no afirmaciones.

### `flutter test` — 194 pasan (los 190 de antes + 4 nuevos)

```
$ flutter test
...
00:05 +194: All tests passed!
```

Antes de empezar, en el mismo entorno:

```
$ flutter test          # commit 492b1f3, punto de partida
00:04 +190: All tests passed!
```

**Ningún test se ha borrado ni desactivado.** 194 − 4 = 190. Los que cambiaron
de sitio (`auth_service_test.dart`, `login_screen_test.dart`) cambiaron de
ruta y de `import`, no de contenido — salvo `login_screen_test.dart`, que
además monta la pantalla bajo `MultiProvider` porque ahora recibe el servicio
inyectado; sus afirmaciones son las mismas.

### `flutter analyze` — 0 errores, 37 issues (ni una más que antes)

```
$ flutter analyze
37 issues found. (ran in 4.7s)

$ flutter analyze 2>&1 | grep -oE "(error|warning|info) - " | sort | uniq -c
     35 info -
      2 warning -
```

Idéntico al punto de partida (37 = 35 info + 2 warning, 0 errores). **Nada de
lo escrito en esta tarea añade una sola issue**, y las 37 preexistentes siguen
siendo las mismas (`withOpacity` deprecados, `curly_braces_in_flow_control`,
etc.).

Sí hubo un error transitorio, resuelto: `SingleChildWidget` **no está
exportado** por `package:provider/provider.dart` en la v6, hay que importar
`package:provider/single_child_widget.dart`. Importar `package:nested` directo
—que es de donde viene— habría disparado `depend_on_referenced_packages`.

### Ningún archivo nuevo pasa de 300 líneas

Archivos **creados** en esta tarea, de mayor a menor:

```
246 test/funcionalidades/autenticacion/registro_empleador_screen_test.dart
149 lib/nucleo/tema/app_tema.dart
 80 lib/nucleo/dominio/estados.dart
 70 lib/compartido/datos/datos_honduras.dart
 61 lib/nucleo/textos/mensajes_error.dart
 50 lib/nucleo/inyeccion/proveedores.dart
 46 lib/nucleo/textos/app_textos.dart
 42 lib/compartido/datos/datos_empleador.dart
 35 lib/nucleo/tema/app_colores.dart
 35 lib/nucleo/dominio/roles.dart
 26 lib/nucleo/dominio/campos_usuario.dart
 23 lib/nucleo/dominio/mapeo_enum_api.dart
 21 lib/nucleo/dominio/reglas_cuenta.dart
 17 lib/services/firestore_colecciones.dart
 14 lib/nucleo/tema/notificador_tema.dart
```

`login_screen.dart` pasó de 265 a **276** (el comentario que explica la
inyección). Sigue por debajo del techo.

**Cuatro archivos MOVIDOS sí lo pasan.** El techo es "un disparador de
revisión" (ADR-0014), así que aquí está la revisión:

| Archivo | Líneas | Por qué se queda así |
|---|---|---|
| `funcionalidades/autenticacion/pantallas/registro_trabajador_screen.dart` | 1 030 | Monstruo conocido. ADR-0014 lo parte **con la tarea 012**, que lo reescribe entero (doble rol). Partirlo hoy es un diff enorme que la tarea 012 tiraría a la basura |
| `funcionalidades/autenticacion/pantallas/registro_empleador_screen.dart` | 909 | Igual que el anterior |
| `funcionalidades/autenticacion/datos/auth_service.dart` | 487 | **Excepción nueva, la explico abajo** |
| `test/funcionalidades/autenticacion/auth_service_test.dart` | 689 | Solo cambió de carpeta. Son 30 casos independientes de un servicio; partirlo por tamaño no mejora nada y ADR-0014 habla de archivos de producción |

Sobre `auth_service.dart` (487):

```
$ wc -l ...auth_service.dart          487
   comentarios y líneas en blanco:    244
   código real:                       243
```

**La mitad del archivo es documentación** —de la buena: explica qué cambió al
salir de Firebase y por qué—. El código son 243 líneas, por debajo del techo.
Aun así **hay un corte natural pendiente**: `AuthService` mezcla
*autenticación* (sesión, login, registro, logout, guardián de ADR-0013) con
*perfil* (`PUT /me`, los tres sub-recursos del CV, ranking, perfil ajeno, baja
de cuenta). **No lo he partido aquí a propósito**: los dos registros
—pantallas de `autenticacion`— usan las dos mitades, y las pantallas de perfil
que consumirían un `PerfilService` son justo las de la parte B. Partirlo ahora
obligaría a tocar 7 pantallas que esta tarea no debía tocar. **Va con la parte
B, cuando se mueva `perfil`.**

### El test nuevo con servicio falso inyectado — el criterio que importa

`test/funcionalidades/autenticacion/registro_empleador_screen_test.dart`, 4
casos sobre `RegistroEmpleadorScreen`, que **no tenía ningún test**. Es la
pantalla con más lógica de guardado del proyecto y hasta hoy solo se había
probado a mano.

```
$ flutter test test/funcionalidades/autenticacion/registro_empleador_screen_test.dart
00:00 +0: el paso 1 registra con el servicio inyectado y luego guarda el tipo de empleador, en ese orden
00:01 +1: si el registro falla no se manda el perfil y el usuario se queda en el paso 1 con el mensaje del servidor
00:01 +2: sin aceptar los términos no se llama al servidor
00:02 +3: elegir "Empresa" manda el nombre, el RTN y el cargo de contacto
00:02 +4: All tests passed!
```

**Y comprobé que se pone rojo si se rompe lo que vigila**, que es la parte que
la gente se salta. Quitando el `return` de la rama de error del paso 1
(`registro_empleador_screen.dart:125`):

```
Expected: ['registrar']
  Actual: ['registrar', 'actualizarCampos']
00:02 +1 -1: si el registro falla no se manda el perfil ... [E]
```

El archivo se restauró inmediatamente (`git diff` limpio).

El doble es `class AuthServiceFalso extends AuthService`, registrado con
`proveedoresDeLaApp(auth: falso)`. Recibe un `ApiClient` con `MockClient` y
almacén en memoria **por seguridad, no por uso**: si mañana la pantalla llama
a un método sin doblar, no se abre un socket ni se toca el almacén seguro real
(donde vive el refresh token).

**Esto es la prueba de que la DI sirve para algo.** Antes, para afirmar "si el
registro falla no se manda el `PUT` de perfil" había que levantar la capa HTTP
entera y deducirlo de las peticiones. Ahora es una línea.

### Lo que NO tengo evidencia de haber probado

**No he abierto el emulador.** El criterio "la app arranca y se recorre en el
`Pixel_6`: login → feed → detalle → perfil, con capturas" **no está cumplido**
y no lo doy por bueno. Es un refactor sin cambios de comportamiento y los 194
tests pasan, pero eso no sustituye a arrancarla: lo que un test de widget no
ve es, por ejemplo, que `Firebase.initializeApp()` y el orden de arranque de
`main()` sigan bien en un dispositivo real, o que el `MultiProvider` nuevo no
rompa algún `Navigator.push` concreto. Recomiendo que sea lo primero que se
haga antes de fusionar, con el túnel SSH al 8080 de la VM que describe el
snapshot.

## Qué se movió

### 1. `constantes.dart` partido (commit `d94da67`)

605 líneas, 15 clases sin relación, importado por 45 archivos. Reparto:

| Destino | Contiene |
|---|---|
| `lib/nucleo/tema/app_colores.dart` | `AppColores` |
| `lib/nucleo/tema/app_tema.dart` | `AppTema` (claro y oscuro) |
| `lib/nucleo/tema/notificador_tema.dart` | `notificadorTema` |
| `lib/nucleo/textos/app_textos.dart` | `AppTextos` |
| `lib/nucleo/textos/mensajes_error.dart` | `MensajesError` |
| `lib/nucleo/dominio/estados.dart` | `EstadosTrabajo`, `EstadosPostulacion`, `TiposMensaje` |
| `lib/nucleo/dominio/mapeo_enum_api.dart` | `MapeoEnumApi` |
| `lib/nucleo/dominio/roles.dart` | `RolesApi`, `ValoresDefecto` |
| `lib/nucleo/dominio/campos_usuario.dart` | `CamposUsuario` |
| `lib/nucleo/dominio/reglas_cuenta.dart` | `ReglasCuenta` |
| `lib/compartido/datos/datos_honduras.dart` | `DatosHonduras` |
| `lib/compartido/datos/datos_empleador.dart` | `DatosEmpleador` |
| `lib/services/firestore_colecciones.dart` | `FirestoreColecciones` |

Cada importador pasó a importar **solo lo que usa** (mapeado símbolo a símbolo
con un script; el analizador confirma que no sobra ni falta ninguno: un import
de más habría salido como `unused_import`, uno de menos como error).

**Cero líneas de código cambiadas.** Comprobado, no supuesto:

```
$ # el archivo viejo vs. la concatenación de los nuevos, sin imports ni comentarios
$ diff /tmp/v.txt /tmp/n.txt && echo IDENTICO
IDENTICO: cero lineas de codigo cambiadas (437 lineas)
```

Tres decisiones dentro del reparto que me aparté del plan o que conviene saber:

- **`ValoresDefecto` está con `RolesApi`**, no en `campos_usuario.dart`, porque
  `RolesApi.todos` referencia `ValoresDefecto.rolTrabajador`. Separarlos creaba
  una dependencia entre dos archivos del mismo paquete sin ganar nada.
- **`notificadorTema` tiene archivo propio.** El plan lo metía en
  `nucleo/tema/` junto a los colores; le di archivo aparte precisamente porque
  **no es una constante, es estado compartido**, y esconderlo entre colores es
  lo que hizo que nadie se diera cuenta durante 605 líneas. El archivo lo dice
  y lista a los cuatro que lo escuchan.
- **`FirestoreColecciones` NO está en `nucleo/`.** El plan decía "déjalo donde
  menos estorbe". Lo puse en `lib/services/`, al lado de sus tres únicos
  consumidores (`chat`, `calificacion` y `cartera`), con un comentario que dice
  que muere con ellos en la fase 3 y que nada de `nucleo/` ni de
  `funcionalidades/` debe importarlo. Si estuviera en `nucleo/`, cuando llegue
  la fase 3 alguien tendría que ir a buscarlo.

Sobre `notificadorTema` y el aviso del encargo: hice el `grep` antes de
moverlo. Lo escuchan/escriben cuatro sitios — `main.dart`,
`configuracion_screen.dart`, `inicio_screen.dart` y `login_screen.dart` — más
dos menciones en comentarios que actualicé. Al moverse **la instancia sigue
siendo única** (un solo `final` global en un solo archivo), así que el
comportamiento es idéntico. Lo dejé **fuera de `provider`** a propósito y
escrito en el propio archivo: es un `ValueNotifier` sin dependencias que ningún
test necesita sustituir. Meterlo en el contenedor solo por simetría habría sido
ruido.

### 2. `autenticacion` movida (commit `c4eb28c`)

Todo con `git mv`. Git las detecta como renombrados al **94-99%**:

```
rename lib/{services => funcionalidades/autenticacion/datos}/auth_service.dart (98%)
rename lib/{screens => funcionalidades/autenticacion/pantallas}/bienvenida_registro_screen.dart (97%)
rename lib/{screens => funcionalidades/autenticacion/pantallas}/login_screen.dart (96%)
rename lib/{screens/registro => funcionalidades/autenticacion/pantallas}/registro_empleador_screen.dart (98%)
rename lib/{screens/registro => funcionalidades/autenticacion/pantallas}/registro_trabajador_screen.dart (98%)
rename lib/{services => nucleo/sesion}/sesion_usuario.dart (99%)
rename test/{services => funcionalidades/autenticacion}/auth_service_test.dart (99%)
rename test/{screens => funcionalidades/autenticacion}/login_screen_test.dart (94%)
```

`sesion_usuario.dart` fue a `nucleo/sesion/` y no dentro de la funcionalidad
porque `InicioScreen` y tres tests de otras pantallas también lo leen: es
estado transversal, y ADR-0014 pone la sesión en `nucleo/`.

Moví también los dos tests de la funcionalidad a
`test/funcionalidades/autenticacion/` para que el árbol de tests refleje el de
`lib/`; si no, el test nuevo no habría tenido un sitio coherente donde vivir.

### 3. `provider` y la raíz de composición (commit `3cc09b4`)

- `provider: ^6.1.5` en `pubspec.yaml` (resuelto a 6.1.5+1). **Única
  dependencia nueva**, justificada en ADR-0014.
- `lib/nucleo/inyeccion/proveedores.dart`: `proveedoresDeLaApp()`, el único
  sitio donde se construyen servicios. Registra `AuthService`,
  `PublicacionService` y `PostulacionService`, todos perezosos.
- `TrabajitApp` monta el `MultiProvider` **por encima** de `MaterialApp` — tiene
  que estar arriba para que las pantallas abiertas con `Navigator.push`, que se
  construyen dentro del `Navigator`, sigan viendo los servicios.
- `main()` le pasa el **mismo** `AuthService` con el que ya restauró la sesión.
- Las tres pantallas de `autenticacion` cambiaron
  `final _authService = AuthService();` por
  `late final AuthService _authService = context.read<AuthService>();`.
  **Sin valor por defecto a propósito**: si falta el proveedor revienta fuerte,
  en vez de fabricarse un servicio de verdad dentro de un test.

`ApiClient` **no** se registra: ya tiene `ApiClient.fijarInstancia()`, que usan
unos 60 tests. El encargo pedía respetar ese mecanismo y no duplicarlo; tener
dos formas de sustituir lo mismo es peor que tener una. Está escrito en el
propio `proveedores.dart` y corregí los dos comentarios del código que decían
"la app no usa un contenedor de inyección de dependencias", que acababan de
volverse falsos (`api_client.dart` y `sesion_usuario.dart`).

## Qué NO se movió, y por qué

- **`lib/services/api/**`** → su sitio de ADR-0014 es `nucleo/api/`. No lo moví
  porque `api_client.dart` son **646 líneas**: moverlo lo convierte en un
  "archivo movido" que incumple el techo, y partirlo es una tarea en sí misma
  (renovación de token con tres candados + guardián de ADR-0013; tocar eso de
  refilón en un refactor de carpetas es como se rompen las sesiones). **Parte B.**
- **`lib/widgets/**`** → su sitio es `compartido/widgets/`. Igual:
  `custom_textfield.dart` son **406 líneas** y además mezcla tres widgets con
  cuatro ayudas de tema (`colorTextoFuerte`, `colorTextoSuave`,
  `colorSuperficie`, `colorBorde`) y `mostrarSnackBar`. Esas ayudas son de
  `nucleo/tema/` y el resto de `compartido/widgets/`: al moverlo hay que
  partirlo, y eso toca los ~20 archivos que hoy lo importan entero. **Parte B.**
- **`lib/models/usuario.dart`** (560 líneas) → lo usan las seis
  funcionalidades. **Parte B**, probablemente a `compartido/` y no a una
  funcionalidad concreta.
- **`cartera_service`, `calificacion_service`, `chat_service`** → intactos, por
  instrucción. Nacen en la estructura nueva en la fase 2b-2.
- **`detalle_trabajo_screen.dart`** (1 143) y los dos registros → **no se
  parten**, por ADR-0014. Los registros sí se movieron de carpeta (son
  `autenticacion`); `detalle_trabajo_screen.dart` ni se tocó (es `trabajos`).
- **`backend/**`** → ni un archivo.
- **`firestore.rules`** → sin tocar.

## Lo que no esperaba

1. **`git mv` no salva el historial de `constantes.dart`, y no hay forma de que
   lo haga.** Cuando un archivo se parte en 13, el heredero mayor
   (`app_tema.dart`, 149 de 605 líneas) conserva el **25%**, por debajo del
   umbral de detección de renombrados de git —ni siquiera con `-M25%` lo
   marca—. Hice el `git mv` igualmente para que la intención quede registrada,
   pero el diff se lee como borrado + creación y no hay truco que lo evite. Por
   eso puse en el mensaje del commit la prueba de que el contenido es idéntico:
   es lo único que le sirve a quien revise. Los 8 movimientos de la
   funcionalidad sí conservan el historial (94-99%).

2. **Dos archivos "importaban" `constantes.dart` solo en un comentario.**
   `sesion_usuario.dart` y `configuracion_api.dart` salían en el `grep` por
   nombre de archivo pero no tenían la línea `import`. Si hubiera hecho la
   sustitución a ciegas por nombre habría metido imports muertos. Se
   actualizaron los comentarios a las rutas nuevas.

3. **La DI se demostró sola rompiendo un test.** Al quitar
   `AuthService()` de dentro de `LoginScreen`, `login_screen_test.dart` se
   puso rojo porque montaba `MaterialApp(home: LoginScreen())` sin proveedor.
   No es un problema, es exactamente la señal de que la costura existe: la
   pantalla ya no puede fabricarse su servicio a escondidas.

4. **`AuthService` mezcla dos cosas y no me lo esperaba tan claro.** Auth y
   perfil. Es el motivo real de sus 487 líneas, más que el tamaño en sí. Lo
   dejo anotado como el primer candidato de la parte B.

## Dónde creo que el plan se equivocaba (o le faltaba un detalle)

El plan es bueno; tres matices honestos:

1. **"Mover una sola funcionalidad completa" no es del todo posible con
   `autenticacion`**, porque sus pantallas dependen de `custom_textfield.dart`
   y `logo_trabajito.dart`, que son de `compartido/`, y su servicio depende de
   `services/api/`, que es de `nucleo/`. El resultado son imports feos del tipo
   `../../../widgets/custom_textfield.dart`. Funciona y no rompe nada, pero
   **la parte B debería empezar por `nucleo/api/` y `compartido/widgets/`**, no
   por otra funcionalidad: son la base sobre la que se apoyan todas. Es un
   cambio de orden respecto al plan.

2. **El criterio "flutter test sigue en 190" choca con el criterio "un test
   nuevo".** Son 194. Interpreté que los 190 tienen que seguir pasando, que es
   lo que importa. Lo dejo dicho para que nadie lea el 194 como un fallo.

3. **El criterio del emulador no lo he cumplido** (ver arriba). No lo he
   maquillado ni marcado como hecho.

## Riesgos que quedan vivos

- **Conviven dos estructuras en `lib/`.** Es lo pactado, pero durante la parte B
  cualquiera que abra el proyecto se encontrará `screens/`, `services/`,
  `models/` y `widgets/` al lado de `funcionalidades/` y `nucleo/`. La tabla de
  `docs/architecture.md` ya lo dice con todas las letras. **Cuanto antes se
  haga la parte B, mejor**: una estructura a medias es peor que cualquiera de
  las dos enteras.
- **Hay dos instancias de `AuthService` en ejecución**: la del proveedor (la que
  usan las pantallas de auth) y las que siguen construyendo las 7 pantallas de
  la parte B. **No cambia el comportamiento** —`AuthService` no tiene estado
  propio: delega en `ApiClient.instancia` y `sesionActual`, que son únicos, y
  comprobé que nadie fuera de sus tests lee `ultimoErrorPorCampo`, su único
  campo mutable—. Pero es una anomalía temporal que la parte B debe cerrar.
- **Nada comprueba automáticamente el techo de 300 líneas.** ADR-0014 pide un
  check en CI que falle el PR. **No hay CI** (`.github/workflows/claude.yml` no
  lo es). Hasta que exista, la regla depende de que alguien la mire — que es
  justo como se rompen las reglas. Es trabajo de `devops-agent`, no mío.

## Bug encontrado de paso y NO arreglado (por instrucción)

Ninguno de comportamiento. Lo único que encontré son **inconsistencias de
documentación**, que sí corregí porque el encargo pide dejar los docs al día:

- `docs/database.md` apuntaba a `lib/utils/constantes.dart` para los nombres de
  colección. Corregido.
- `api_client.dart` y `sesion_usuario.dart` afirmaban en comentarios que la app
  no tiene contenedor de DI. Corregido.
- **`.claude/agents/flutter-agent.md` (línea 22) sigue diciendo que colores,
  textos, colecciones y tema están "todo centralizado en
  `lib/utils/constantes.dart`", que ya no existe.** **No lo he tocado**: es
  configuración de agente, no código del proyecto. Que lo actualice quien
  corresponda; si un agente futuro lee esa línea, irá a buscar un archivo
  borrado.

## Qué queda para la parte B

En el orden que recomiendo, que **no** es el del plan:

1. `lib/services/api/**` → `lib/nucleo/api/**`, **partiendo `api_client.dart`**
   (646 líneas). Con cuidado: ahí viven los tres candados de la renovación de
   token y el guardián de ADR-0013.
2. `lib/widgets/**` → `lib/compartido/widgets/**`, **partiendo
   `custom_textfield.dart`** (406): las cuatro ayudas de color a `nucleo/tema/`,
   `mostrarSnackBar` a `compartido/widgets/`, los widgets a los suyos.
3. `lib/models/usuario.dart` (560) y el resto de modelos.
4. Mover `trabajos`, `postulaciones` y `perfil`, y **cablearles la DI**
   (quitarles el `AuthService()` de dentro a las 7 pantallas que aún lo tienen).
5. **Partir `AuthService` en auth + perfil**, que es lo natural en cuanto
   `perfil` sea una funcionalidad de verdad.
6. Registrar en `proveedoresDeLaApp()` los servicios que falten según se
   muevan.

Y fuera de esta tarea: el check de CI del techo de 300 líneas (`devops-agent`)
y el recorrido en el emulador con capturas.

## Commits

```
ee7c6d6 test(flutter): primer test de RegistroEmpleadorScreen con AuthService falso inyectado
3cc09b4 feat(flutter): inyectar los servicios con provider
c4eb28c refactor(flutter): mover la funcionalidad autenticacion a lib/funcionalidades
d94da67 refactor(flutter): partir constantes.dart en nucleo/ y compartido/
```

Los que mueven archivos (`d94da67`, `c4eb28c`) **no cambian ni una línea de
lógica**; los que cambian código (`3cc09b4`, `ee7c6d6`) **no mueven nada**.
Están separados para que se puedan revisar.

## Documentación actualizada

- `docs/architecture.md`: sección "Módulos Flutter" reescrita con la estructura
  nueva, diciendo explícitamente qué está movido y qué no, más las dos reglas
  (techo de 300 y pantallas que no construyen servicios) y por qué `ApiClient`
  es la excepción.
- `docs/agent-context/repo-snapshot.md`: bloque nuevo de la 027, contadores de
  tests (190 → 194), rutas de los tests movidos, y la nota de cobertura de
  pantallas actualizada (ya no es cierto que ninguna pantalla de registro tenga
  test).
- `docs/database.md`: ruta de `FirestoreColecciones`.
- `docs/agent-tasks/027-...md`: `estado: en-progreso`.
