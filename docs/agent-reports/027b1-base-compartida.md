---
tarea: 027
titulo: "Reestructurar lib/ por funcionalidad — PARTE B-1: la base compartida"
agente: "flutter-agent"
fecha: 2026-09-08
rama: "refactor/base-compartida"
estado_tarea: "en-progreso (A y B-1 hechas, B-2 pendiente)"
---

# Tarea 027 — Parte B-1: la base compartida

Solo la **parte B-1**. La B-2 (mover `trabajos`, `postulaciones` y `perfil`)
**no se ha tocado**, por instrucción explícita.

## Resumen en una línea

`lib/services/api/` es ahora `lib/nucleo/api/` con `api_client.dart` partido en
cuatro, y `lib/widgets/` es `lib/compartido/widgets/` con `custom_textfield.dart`
partido en siete. **Ni una regla de negocio ha cambiado**, y esta vez sí está
comprobado en el emulador.

---

## 1. Evidencia de los criterios de aceptación

Todo lo de abajo es salida real de comandos en esta rama.

### `flutter test` — los 194 siguen pasando

Punto de partida (commit `492b1f3`, `develop` con la parte A dentro):

```
$ flutter test
00:05 +194: All tests passed!
```

Después de los cuatro commits de B-1:

```
$ flutter test
00:06 +194: C:/.../test/screens/perfil_tab_test.dart: (tearDownAll)
00:06 +194: All tests passed!
```

**Ningún test se ha borrado, desactivado ni modificado.** Lo único que cambió
en `test/` son líneas `import`:

```
$ git diff develop...HEAD -- test/ | grep -cE "^[+-]" ; \
  git diff develop...HEAD -- test/ | grep -E "^[+-]" | grep -vE "^(\+\+\+|---)" | grep -vc "^[+-]import "
60
0
```

Es decir: 60 líneas tocadas en `test/`, **cero de ellas fuera de un `import`**.

### `flutter analyze` — 0 errores, 37 issues (ni una más)

```
$ flutter analyze
37 issues found. (ran in 4.8s)

$ flutter analyze 2>&1 | grep -cE "error - "     # 0
$ flutter analyze 2>&1 | grep -cE "warning - "   # 2
$ flutter analyze 2>&1 | grep -cE "info - "      # 35
```

Y no son "37 cualesquiera": son **exactamente las mismas 37**, comprobado
ignorando la ruta y la línea (que sí cambian, porque los archivos se movieron):

```
$ diff <(sed 's| - [^ ]*\.dart:[0-9]*:[0-9]* - | - |' base_analyze.txt | sort) \
       <(sed 's| - [^ ]*\.dart:[0-9]*:[0-9]* - | - |' tras_B1.txt      | sort)
   (sin diferencias)
```

Se corrió `flutter analyze` **después de cada uno de los cuatro pasos**, no al
final: los cuatro dieron 37/0.

### Tamaño de los archivos nuevos o movidos

Todos por debajo de 300 **salvo uno**, que justifico en el §3.

```
lib/nucleo/api/                       lib/compartido/widgets/
  314  gestor_sesion.dart  ← excepción     81  custom_textfield.dart
  295  api_excepciones.dart  (movido)      79  botones_si_no.dart
  260  api_client.dart                     79  indicador_fuerza_contrasena.dart
  199  configuracion_api.dart (movido)     53  indicador_pasos.dart
  172  transporte_http.dart                52  ejecutar_con_carga.dart
  153  sesion_api.dart       (movido)      46  custom_dropdown.dart
  124  pagina_api.dart       (movido)      28  mostrar_snackbar.dart
  109  almacen_sesion.dart   (movido)     161  resenas.dart          (movido)
   95  guardia_escrituras.dart           161  entrada_etiquetas.dart (movido)
                                         110  logo_trabajito.dart    (movido)
lib/nucleo/tema/                          51  estrellas.dart         (movido)
   23  colores_por_tema.dart
```

Los monstruos conocidos (`detalle_trabajo_screen` 1 145, los dos registros,
`usuario.dart` 560) **no se han tocado**: no son de esta parte.

### La app arranca de verdad en el `Pixel_6`

Esto es lo que la parte A no pudo dar por cumplido, y era justo el aviso: *un
refactor de imports puede compilar y no arrancar*.

```
$ flutter emulators --launch Pixel_6
$ flutter run -d emulator-5554 --dart-define=TRABAJITO_API_URL=http://10.0.2.2:8080
Syncing files to device sdk gphone64 x86 64...   166ms
Flutter run key commands.
```

Backend **apagado** a propósito. Capturas en
`docs/agent-reports/capturas/`:

| Captura | Qué demuestra |
|---|---|
| `027b1-01-arranque.png` | La pantalla de carga (`EstadoSesion.comprobando`). La app arranca; `Firebase.initializeApp()` y el orden de `main()` siguen bien |
| `027b1-02-tras-restaurar-sesion.png` | **La sesión se restauró**: "Hola, Juan Alvarado" leído del almacén seguro por `GestorDeSesion.cargar()`. El feed dice *"El servidor tardó demasiado en responder… Desliza hacia abajo para reintentar"* — el mensaje exacto que produce `TransporteHttp` al agotar el tiempo límite. Es lo esperado con el backend apagado |
| `027b1-03-perfil.png` | `PerfilTab` con el aviso honesto de la tarea 023 (*"Sin conexión: estos son los datos de tu última visita"*) y los datos del perfil |
| `027b1-04-tema-oscuro.png` | **Tema oscuro.** Es la prueba directa de que las cuatro ayudas de color movidas a `nucleo/tema/colores_por_tema.dart` siguen funcionando: si estuvieran mal, aquí se vería |
| `027b1-05-publicar-formulario.png` | El formulario de publicar: `CustomTextField` ×4 y `CustomDropdown` ×3, cada uno ya en su archivo, pintando en oscuro |
| `027b1-06-adr0013-no-se-ha-enviado-nada.png` | **ADR-0013 de punta a punta en el dispositivo**: al pulsar "Publicar" sin backend sale *"Sin conexión no podemos publicar ni guardar cambios. No se ha enviado nada: vuelve a intentarlo cuando tengas internet."* Eso ejercita `guardia_escrituras.dart` **y** `mostrar_snackbar.dart`, los dos archivos nuevos, a la vez |
| `027b1-07-ranking.png` | La pestaña de ranking con su estado de error honesto |

También se visitaron **Trabajadores** y **Chats** (esta última sigue en
Firestore y pintó su conversación de siempre). Las cinco pestañas van.

**El log de `flutter run` no tiene ni una excepción**:

```
$ grep -inE "EXCEPTION|Unhandled|Failed assertion|RenderFlex overflow" flutter_run.log
   (nada)
```

**Lo que NO probé en el emulador, y por qué:** el **login**. La sesión guardada
se restauró sola, y para llegar al login habría que cerrar sesión — con el
backend apagado no se podría volver a entrar, así que habría destruido el resto
de la prueba. El camino de login está cubierto por
`test/funcionalidades/autenticacion/login_screen_test.dart` y los 30 de
`auth_service_test.dart`.

---

## 2. Qué partí y **cómo decidí los cortes**

### 2.1 `api_client.dart` (649 líneas) → cuatro archivos

Antes de cortar nada leí el archivo entero y anoté, método a método, **qué
estado toca cada uno**. Ese fue el criterio, no el tamaño:

| Bloque | Toca `_sesion` / `_refrescoEnVuelo` | Toca `_confirmador` | Toca `_http` |
|---|---|---|---|
| `_enviar`, `_interpretar`, `_cabecera`, `construirUri` | **no** | **no** | sí |
| `exigirSesionConfirmada`, `_exigirSesionConfirmada` | **no** | sí | **no** |
| `_renovar`, `_ejecutarRenovacion`, `_esLaSesionActual`, `_peticionConReintento`, `cerrarSesion` | sí | (una línea) | vía `_enviar` |

Las dos primeras filas **no comparten un solo campo** con la renovación. Eso
las convierte en cortes sin riesgo, y son los dos que hice primero:

- **`transporte_http.dart` (172)** — `TransporteHttp`: una ida y vuelta.
  Construye la URI, pone cabeceras, aplica el tiempo límite, traduce el error
  de ADR-0008. No sabe qué es una sesión.
- **`guardia_escrituras.dart` (95)** — `GuardiaEscrituras`: ADR-0013. Máquina
  de estados propia (un confirmador + una comprobación en vuelo). Se lleva
  también el `typedef ConfirmadorDeSesion`.

Y la tercera fila, la delicada:

- **`gestor_sesion.dart` (314)** — `GestorDeSesion`: la sesión viva, su
  almacén, sus eventos, **los tres candados con su docstring de 55 líneas** y
  `peticionConReintento`.

- **`api_client.dart` (260)** — la fachada: los cinco verbos, las ayudas
  tipadas, el ciclo de vida (`iniciar`, `guardarSesion`, `cerrarSesion`,
  `cambiarUrlBase`, `cerrar`) y la instancia compartida.

### 2.2 El corte que **no** hice, y por qué

**No separé `peticionConReintento` de `_renovar`.** Era el corte obvio por
tamaño (63 líneas que habrían dejado `gestor_sesion.dart` en 251, bajo el
techo), y es exactamente el que no se debe hacer:

```dart
// gestor_sesion.dart, dentro de peticionConReintento
final refreshVisto = actual.refreshToken;          // ← aquí se captura
...
final renovada = await _renovar(refreshVisto);     // ← y aquí se compara
```

```dart
// _renovar, veinte líneas más abajo, en el mismo archivo
// Candado 2: alguien renovó mientras esperábamos...
if (actual.refreshToken != refreshVisto) return Future.value(actual);
```

Esas dos mitades **son el candado 2**. Ponerlas en archivos distintos deja a
quien lo lea con media pista en cada sitio, y el candado 2 es precisamente el
que evita que dos refrescos presenten el mismo token y el backend revoque la
familia entera. **Prefiero 314 líneas legibles a 251 que escondan eso.**

**Tampoco toqué la API de `fijarInstancia`.** `ApiClient.instancia` y
`ApiClient.fijarInstancia()` están copiados tal cual, misma firma, mismo campo
estático. Lo único que cambió del constructor es que ahora es `factory` — con
**los mismos parámetros nombrados y opcionales**, así que ninguna llamada
existente cambia. Comprobé antes que nadie hereda de `ApiClient`:

```
$ grep -rn "extends ApiClient\|implements ApiClient\|with ApiClient" lib test
ninguno
```

También sobreviven `ApiClient.comoObjeto` y `ApiClient.construirUri` como
reenvíos de una línea (los cuerpos viven en `transporte_http.dart`): los usan
`auth_service`, `publicacion_service` y tres tests. Y `api_client.dart`
**reexporta** `ConfirmadorDeSesion`, para que quien importe el cliente lo siga
viendo igual que antes.

### 2.3 Cómo comprobé que no se perdió lógica

No a ojo. Los cuerpos se copiaron **por rango de líneas** con un script
(`dart`), no a mano, y luego comparé el original con los cuatro archivos
nuevos línea a línea, solo código, deshaciendo los renombrados deliberados:

```
lineas de codigo: viejo=370  nuevo=459

--- 11 lineas del ORIGINAL que ya no estan ---
  - ApiClient({
  - })  : _http = clienteHttp ?? http.Client(),
  - _almacen = almacen ?? AlmacenSesionSeguro(),
  - _urlBase = urlBase == null ? null : ConfiguracionApi.normalizar(urlBase),
  - final String? _urlBase;
  - String get urlBase => _urlBase ?? ConfiguracionApi.urlBase;
  - if (_urlBase == null) {
  - await _terminarSesion();
  - _http.close();
  - _eventos.close();
  - void exigirSesionConfirmada(ConfirmadorDeSesion? confirmador) {
```

Las **once** son constructor, el campo `_urlBase` (ahora `_urlBaseFija` dentro
del transporte) y los cuatro métodos que pasaron a delegar. **Ninguna línea de
lógica de negocio desapareció.** Las 100 nuevas son imports, constructores y
delegación.

### 2.4 Y la prueba que de verdad importa: mutación de los tres candados

Comparar líneas demuestra que el código está; no demuestra que siga
*enganchado*. Así que rompí cada candado a propósito, **después** del corte, y
miré si los tests se ponían rojos:

```
=== MUTANTE 1 — sin candado 1 (una sola renovacion en vuelo) ===
  4 tests en rojo (api_client_test.dart):
    · 5 peticiones que caducan a la vez producen UN solo refresh
    · la sesión se guarda una sola vez aunque cinco peticiones esperen
    · diez peticiones simultáneas caducadas no expulsan al usuario
    · varias rondas seguidas siguen sin reutilizar ningún token

=== MUTANTE 2 — sin candado 2 (comparar el refresh visto) ===
  2 tests en rojo (api_client_test.dart):
    · una petición que despierta tarde NO refresca con el token viejo
    · una petición lenta que despierta tras la renovación tampoco

=== MUTANTE 3 — sin candado 3 (la sesion sigue siendo la misma) ===
  2 tests en rojo (renovacion_y_sesion_test.dart):
    · cerrar sesión mientras se renueva deja el dispositivo SIN sesión
    · un refresco viejo que llega tarde no pisa la sesión nueva

=== MUTANTE 4 — sin el guardia de ADR-0013 ===
  7 tests en rojo (bloqueo_sin_conexion_test.dart)
```

El archivo se restauró tras cada mutación (`diff` contra la copia buena:
idéntico) y la suite volvió a 194.

### 2.5 `custom_textfield.dart` (407 líneas) → ocho archivos

El archivo tenía **siete cosas** y su nombre describía una. Criterio de corte:
uno por declaración pública, con el nombre del archivo igual al del símbolo.

| Nuevo archivo | Líneas | Qué |
|---|---|---|
| `nucleo/tema/colores_por_tema.dart` | 23 | `colorTextoFuerte`, `colorTextoSuave`, `colorSuperficie`, `colorBorde` |
| `compartido/widgets/custom_textfield.dart` | 81 | `CustomTextField` |
| `compartido/widgets/indicador_pasos.dart` | 53 | `IndicadorPasos` |
| `compartido/widgets/botones_si_no.dart` | 79 | `BotonesSiNo` |
| `compartido/widgets/custom_dropdown.dart` | 46 | `CustomDropdown` |
| `compartido/widgets/indicador_fuerza_contrasena.dart` | 79 | `IndicadorFuerzaContrasena` |
| `compartido/widgets/mostrar_snackbar.dart` | 28 | `mostrarSnackBar` |
| `compartido/widgets/ejecutar_con_carga.dart` | 52 | `ejecutarConCarga` + su candado global |

Dos decisiones que me aparté de lo obvio:

1. **Las cuatro ayudas de color no son widgets: son tema.** ADR-0014 pone el
   tema en `nucleo/tema/`, así que ahí van, junto a `app_colores.dart`. Las
   usan **15 pantallas** y estaban en las líneas 6-18 de un archivo llamado
   "custom_textfield": nadie las iba a encontrar.

2. **`mostrarSnackBar` y `ejecutarConCarga` van separados aunque el segundo
   llame al primero.** Porque `ejecutarConCarga` esconde esto:

   ```dart
   bool _ejecutando = false;   // ← global, NO por pantalla
   ```

   Mientras una acción corre, **ninguna otra pantalla puede lanzar la suya**.
   Es a propósito (anti doble-toque) pero es estado compartido, y estaba en la
   línea 376 de 407. Ahora está declarado el primero, con su documentación, en
   un archivo cuyo nombre lo delata. Es el mismo criterio que la parte A aplicó
   a `notificadorTema`.

Comprobación de equivalencia, igual que antes:

```
lineas de codigo: viejo=350  nuevo=350
IDENTICO: las 350 lineas de codigo son las mismas, ni una mas ni una menos
```

Los **22 importadores** pasan a importar solo lo que usan (mapeado símbolo a
símbolo con un script; el analizador lo confirma: un import de más habría
salido como `unused_import`, uno de menos como error).

---

## 3. El archivo que pasa de 300 líneas, y por qué se queda

**`lib/nucleo/api/gestor_sesion.dart` — 314 líneas.** Única excepción de B-1.

La revisión que el techo de ADR-0014 pide es esta:

- **55 de esas líneas son el docstring de los tres candados**, tal cual estaba
  en `api_client.dart`. Documenta un fallo real reproducido en la tarea 022
  (una renovación en vuelo revivía una sesión cerrada) y explica por qué hacen
  falta los tres. Borrarlo o resumirlo para bajar el contador sería el peor
  intercambio posible.
- Otras ~40 son comentarios en línea del mismo estilo (por qué no hay `await`
  entre la comprobación y la asignación, por qué un fallo de red no mata la
  sesión, los dos casos reales del candado 3). **Código real: ~200 líneas.**
- El único corte que baja de 300 separa el candado 2 en dos archivos (§2.2).

Si en el futuro alguien quiere bajarlo sin romper nada, el candidato es
`cerrarSesion()` (el `POST /logout` + borrado local, 22 líneas), que podría
volver a la fachada. Lo dejé aquí porque es ciclo de vida de la sesión y el
gestor ya tiene el transporte.

`api_excepciones.dart` (295) y `configuracion_api.dart` (199) se movieron sin
tocarlos y ya estaban por debajo.

---

## 4. Qué NO se movió, y por qué

- **`lib/models/`** (incluido `usuario.dart`, 560 líneas) → sigue por tipo. Lo
  usan las seis funcionalidades; decidir si va a `compartido/` o se reparte es
  una decisión de la B-2, no de "la base compartida".
- **`lib/screens/` y `lib/screens/tabs/`** → B-2.
- **`publicacion_service` y `postulacion_service`** → van con sus
  funcionalidades en la B-2. Aquí solo se les cambió el `import`.
- **`cartera_service`, `calificacion_service`, `chat_service`** → intactos, por
  instrucción. Nacen en la estructura nueva en la fase 2b-2.
- **`firestore_colecciones.dart`** → sigue en `lib/services/`, junto a sus tres
  únicos consumidores, como decidió la parte A.
- **Los tres monstruos** (`detalle_trabajo_screen`, los dos registros) → no se
  parten aquí; ADR-0014 los deja para las tareas que ya tienen que abrirlos.
- **`backend/**`** → ni un archivo. **`firestore.rules`** → sin tocar.
- **Las dos instancias vivas de `AuthService`** (7 pantallas construyen la
  suya) → sigue abierto, es trabajo de la B-2.

---

## 5. Dónde el plan me pareció mejorable

El plan de B-1 es bueno y su corrección de orden era la correcta: haber movido
la base antes que otra funcionalidad ahorra imports feos. Tres matices:

1. **"Partir `api_client.dart` al moverlo, no después" es buena idea, pero se
   hace en dos commits, no en uno.** Un commit que mueve *y* parte 649 líneas
   es ilegible. Lo hice como `git mv` puro (imports y nada más) + corte. El
   resultado es el pedido; la unidad de revisión, no.

2. **El plan sugería "el almacén de sesión" como candidato de corte.** Lo
   probé y lo descarté: `AlmacenSesion` **ya es un archivo aparte**
   (`almacen_sesion.dart`, con su interfaz y dos implementaciones). Lo que hay
   en `api_client.dart` no es el almacén, es la *sesión viva* que lo usa, y esa
   no se puede separar de la renovación (§2.2).

3. **"`custom_textfield.dart` casi seguro contiene varios widgets"** — contenía
   cinco widgets, dos funciones y cuatro ayudas de tema que **no son widgets**.
   La instrucción "uno por archivo" se cumple, pero uno de los ocho archivos
   acabó en `nucleo/tema/`, no en `compartido/widgets/`.

---

## 6. Cosas que encontré y **no** arreglé (anotadas, como pide el encargo)

Ningún bug de comportamiento. Cuatro observaciones:

1. **`ApiClient.obtenerPagina` manda `page`/`size`, no `pagina`/`tamano`.**
   ```dart
   // nucleo/api/api_client.dart
   if (pagina case final int p) 'page': p,
   if (tamano case final int t) 'size': t,
   ```
   El snapshot avisa de que **el feed pagina con `pagina`/`tamano`** y que
   mandar los de Spring "no da error, se ignoran y devuelven siempre la página
   0". `publicacion_service.listarFeed` lo esquiva pasando los suyos por
   `consulta`, así que hoy funciona; pero el helper genérico sigue apuntando al
   contrato equivocado y el siguiente que lo use de buena fe se comerá la
   página 0 en silencio. **No lo he tocado** (cambiarlo es comportamiento).
   Ya está anotado en `configuracion_api.dart:153`.

2. **El docstring de `ejecutarConCarga` documentaba la variable equivocada.**
   Estaba pegado a `bool _ejecutando = false;`, no a la función. Al partir el
   archivo lo puse en la función que describe y le di al candado el suyo. Es lo
   único que cambió de sitio *dentro* de un cuerpo, y no es código.

3. **`_ejecutando` es un candado global entre pantallas.** No es un bug —está
   puesto a conciencia— pero es un comportamiento que nadie ha decidido por
   escrito: si dos pantallas están abiertas (una hoja modal sobre otra), la
   segunda acción se descarta devolviendo `false` sin avisar al usuario. Lo
   dejo escrito en el archivo y aquí.

4. **Nada comprueba automáticamente el techo de 300 líneas.** Sigue igual que
   lo dejó la parte A: ADR-0014 pide un check de CI y **no hay CI**. Es trabajo
   de `devops-agent`.

---

## 7. Commits

```
e4743c1 refactor(flutter): partir custom_textfield.dart en un archivo por cosa
34681ed refactor(flutter): mover lib/widgets a lib/compartido/widgets
fc64386 refactor(flutter): partir api_client.dart en cuatro
9f842ef refactor(flutter): mover lib/services/api a lib/nucleo/api
```

**Mover y cambiar código van separados**, como pedía el encargo:

- `9f842ef` y `34681ed` son `git mv` + **solo líneas `import`**. Comprobado:
  `git diff` filtrando los `import` sale vacío en los dos. Git detecta los
  seis + cinco movimientos como renombrados al 100 %.
- `fc64386` y `e4743c1` cambian código y **no mueven ningún archivo**.

Nota honesta sobre el historial: en los dos commits que *parten*, git no marca
nada como renombrado. En los dos casos el heredero mayor **conserva la ruta
original** (`api_client.dart` y `custom_textfield.dart` siguen llamándose
igual), así que git ve una modificación grande más varios `create mode`, y no
hay renombrado que detectar. `git log --follow` sobre los archivos nuevos
empieza en este commit. Es el mismo límite que encontró la parte A con
`constantes.dart`; por eso metí en el mensaje de cada commit la prueba de
equivalencia de líneas, que es lo que le sirve a quien revise:

```
$ git show --summary e4743c1 | grep -c "create mode"
7
$ git show --stat fc64386 | tail -5
 lib/nucleo/api/api_client.dart         | 583 ++++++---------------------------
 lib/nucleo/api/gestor_sesion.dart      | 314 ++++++++++++++++++
 lib/nucleo/api/guardia_escrituras.dart |  95 ++++++
 lib/nucleo/api/transporte_http.dart    | 172 ++++++++++
 4 files changed, 678 insertions(+), 486 deletions(-)
```

---

## 8. Documentación actualizada

- `docs/architecture.md`: la tabla de módulos Flutter con `lib/nucleo/api/` y
  `lib/compartido/widgets/` (y el detalle de en qué archivo está cada cosa),
  el diagrama de la sección 1, y la nota de que partir `ApiClient` no cambió ni
  `fijarInstancia` ni la renovación.
- `docs/agent-context/repo-snapshot.md`: bloque nuevo de la B-1 —dónde está
  ahora la renovación, la excepción de las 314 líneas, el candado global de
  `ejecutarConCarga`—, el estado de la tarea 027, y que la app **sí** está
  revisada en el emulador.
- `docs/development.md`: la ruta del cliente HTTP.
- `docs/agent-tasks/027-...md`: B-1 marcada como hecha y los criterios de
  aceptación revisados uno a uno.

## 9. Qué queda para la parte B-2

1. Mover `trabajos`, `postulaciones` y `perfil` a `lib/funcionalidades/`.
2. **Cerrar las dos instancias vivas de `AuthService`**: que no quede ni un
   `final _x = AlgunService();` dentro de un `State`.
3. Decidir el sitio de `lib/models/` (`usuario.dart` son 560 líneas).
4. **Partir `AuthService` en auth + perfil** (487 líneas, mezcla las dos
   cosas), que es lo natural en cuanto `perfil` sea una funcionalidad.
5. Registrar en `proveedoresDeLaApp()` los servicios que falten.

Y fuera de la tarea: el check de CI del techo de 300 líneas.
