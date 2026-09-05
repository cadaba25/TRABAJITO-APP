---
id: 022
titulo: "Revisión de QA de todo lo migrado, antes de seguir con la fase 2b"
estado: hecho
agente: "qa-agent"
creada: 2026-08-29
rama: "qa/revision-migracion"
---

## Por qué existe

Encargo del dueño del proyecto: *"no quiero ir dejando bugs atrás sin
resolver y que después se nos olviden"*. Antes de migrar los 5 servicios que
faltan (fase 2b), hay que revisar lo que ya se construyó.

Se ha hecho mucho en pocos días y **nada de la parte Flutter ha pasado por
una revisión independiente**. Concretamente:

- **Tarea 018** (capa HTTP, `ApiClient`) y **tarea 020** (auth contra el
  backend): el propio `flutter-agent` las dejó marcadas como **pendientes de
  revisión de `security-agent`**. Nadie las ha mirado con ojos ajenos.
- **Tarea 019** (perfil completo): tocó la privacidad de los datos —
  `UsuarioResponse` pasó a tener vista de dueño y vista pública. El
  `backend-agent` pidió explícitamente que lo revisara `security-agent`.
- El `tech-lead` arregló a mano dos fallos del build (fuente Sora empaquetada
  y `compileSdk`) sin que nadie los revisara.

## Ámbito de la revisión

Lo migrado, no todo el proyecto. En orden de importancia:

1. **`lib/services/api/`** — el `ApiClient`, la renovación de token con sus
   dos candados, el manejo de errores, el almacén seguro. Es el cimiento de
   todo lo que venga después: un fallo aquí se multiplica por 6 servicios.
2. **`lib/services/auth_service.dart` y `lib/services/sesion_usuario.dart`** —
   el estado de sesión que sustituyó a `authStateChanges()` de Firebase.
3. **Las pantallas adaptadas** en la tarea 020 (login, los dos registros,
   editar perfil, configuración, inicio, las dos pestañas de personas).
4. **La privacidad del perfil** (backend, tarea 019): que un tercero no vea
   saldo, DNI, teléfonos ni fecha de nacimiento. Ya lo verificó el
   `tech-lead` por API, pero conviene mirar el código.

## Puntos calientes concretos (no empieces a ciegas)

Estos son los sitios donde ya se sabe que hay riesgo:

- **El CV se puede borrar sin querer.** `habilidades`, `experiencia` y
  `estudios` llegan `null` en login y registro (`null` = "no viene", no "no
  tiene"). El `flutter-agent` puso tres barreras. **Compruébalas de verdad**:
  es el fallo más caro que podría quedar vivo, porque destruye datos del
  usuario en silencio.
- **La renovación de token.** Dos refrescos a la vez con el mismo token hacen
  que el backend revoque **toda la familia** y el usuario quede fuera. Hay
  dos candados y tests con un backend falso. Intenta romperlo.
- **Pantallas que ya no pueden dar por hecho lo de antes**: el perfil ajeno
  ahora trae `null` en varios campos. ¿Alguna pantalla revienta con eso?
- **429 del login** (freno de fuerza bruta): ¿se muestra un mensaje
  entendible o un error genérico?
- **La app está mixta**: auth contra el backend, los otros 5 servicios contra
  Firestore. Documentado y esperado — **no lo reportes como bug**, pero mira
  si produce estados raros en pantalla (por ejemplo, una pantalla que se
  queda cargando para siempre en vez de decir que no hay datos).

## Puedes probar en un dispositivo de verdad

**Usa el emulador `Pixel_6` (Android 13), NO el `Pixel_9`** (Android 17
preview: va lentísimo y provoca bloqueos que no son de la app).

```bash
flutter emulators --launch Pixel_6
flutter run -d emulator-5554 --dart-define=TRABAJITO_API_URL=http://10.0.2.2:8080
```

El backend corre en la VM (ver `docs/development.md`). Cuenta ya creada:
`demo@trabajito.com` / `DemoTrabajito2026`.

**El caso que más falta por probar**, y que el dueño querría ver cubierto:
registrarse desde la app rellenando los 5 pasos (habilidades, experiencia,
estudios), cerrar sesión, volver a entrar y comprobar que **el CV sigue
completo**. Y después editar el perfil y comprobar que **tampoco lo borra**.

## Qué hacer con lo que encuentres

El dueño pidió que se arregle, no solo que se diagnostique:

- **Arregla** lo que sea claro y esté dentro del ámbito de arriba.
- Si algo es grande o cambia una decisión de producto, **no lo arregles**:
  créale tarea y dilo en el reporte.
- Cada arreglo con su test, para que no vuelva.

## Criterios de aceptación

- [x] Revisados los cuatro puntos del ámbito.
- [x] Los puntos calientes probados de verdad, no leídos por encima.
- [x] Cada fallo encontrado: qué es, cómo reproducirlo, y arreglado o con
      tarea abierta.
- [x] `flutter analyze` sin errores nuevos; `flutter test` pasa (hoy **135**).
      → **144 tests**, **62 issues** (las mismas de la línea base).
- [x] Backend intacto: `mvn test` sigue en **103** y el script de regresión en
      **207 OK / 0 inesperados**, si tocas algo de ahí.
      → **No se tocó `backend/`**. `mvn test` corrido igual como control:
      **103/103, 0 saltados, BUILD SUCCESS**. El script de regresión **no** se
      ejecutó, y el porqué está escrito en el reporte (no aplica la condición
      + el cupo de fuerza bruta por IP quedó parcialmente gastado al provocar
      el 429 a propósito, así que ahora daría fallos que no serían del
      backend).
- [x] Si NO encuentras nada, dilo claramente: "revisado X, sin hallazgos" es
      un resultado válido y útil. No inventes hallazgos para justificar la
      tarea.

## Fuera de alcance

- La fase 2b (migrar los otros 5 servicios): va después de esto.
- Los 5 servicios que siguen en Firestore: no los revises, se van a reescribir.
- Rediseñar la interfaz.

## Notas del agente que la ejecuta

Cerrada el 2026-08-29. Reporte completo, con comandos y salidas reales, en
`docs/agent-reports/022-revision-qa-de-la-migracion.md`.

**Tres fallos encontrados y arreglados**, cada uno con su test de regresión:

1. **Una renovación de token en vuelo resucitaba una sesión cerrada** (el más
   grave, es de seguridad). Si el usuario pulsaba "cerrar sesión" mientras
   `ApiClient` estaba renovando, el refresco terminaba después y guardaba el
   par recién emitido. Como `POST /api/auth/logout` del backend revoca **solo
   el token que se le presenta** y no la familia, en el dispositivo quedaba una
   sesión que el servidor seguía aceptando: al siguiente arranque la app
   entraba sola. Reproducido con una sonda antes de arreglarlo (`haySesion:
   true`, `refresh-1` en el almacén). Arreglado con un tercer candado.
   Variantes también cerradas: un refresco viejo pisaba la sesión de otra
   cuenta, y su 401 tumbaba la sesión nueva.
2. **Editar el perfil con la sesión restaurada sin conexión borraba la
   presentación del servidor** y **descartaba en silencio** la habilidad
   escrita, diciendo "Perfil actualizado". Reproducido en el emulador contra el
   backend real y verificado en PostgreSQL: `presentacion` pasó de
   `PruebaQA022` a vacío. La barrera de `cvCargado` protegía el CV —bien— pero
   solo el CV. Ahora el formulario no se abre sin el perfil completo.
3. **`LoginScreen` no se protegía del doble envío por la tecla "listo"** del
   teclado (`alTerminar` no pasa por el botón, que sí se desactiva). A nivel de
   widget salían 2 `POST /api/auth/login`; **en el emulador no se reprodujo**
   con tres pulsaciones de ENTER, así que es una carrera latente, no un fallo
   que se haya visto sufrir. Se dice así en el reporte a propósito.

**Lo que se revisó y está bien** (resultado igual de útil):

- **Las tres barreras del CV funcionan.** Caso del dueño hecho entero en el
  emulador: registro de 5 pasos → cerrar sesión → entrar → editar. El CV se
  mantuvo en 2 habilidades / 1 experiencia / 1 estudio en los tres momentos,
  comprobado en la BD. Hay además una cuarta barrera no anotada: el backend
  solo toca las habilidades si llegan distintas de `null`.
- **Los candados 1 y 2 de la renovación no se pudieron romper**, ni con el
  backend falso que castiga la reutilización.
- **Doble/triple toque en el registro**: 1 cuenta, 1 experiencia, 1 estudio.
  El guardado aguanta porque `_cargando` se pone antes del primer `await`.
- **Privacidad del perfil ajeno**: correo, DNI, teléfonos, fecha de
  nacimiento, género, código postal, RTN y **saldo** llegan `null`. Ninguna
  pantalla revienta con eso.
- **El 429 del login se entiende** y dice cuánto falta (fotografiado en el
  emulador). Y la contraseña correcta sigue entrando con la cuenta "con
  fricción", como manda ADR-0010.
- **No apareció ninguna pantalla que se quede cargando para siempre** por la
  app mixta.

**Tarea nueva abierta:** `023-perfil-viejo-sin-conexion-no-se-avisa` — la app
enseña el perfil viejo sin decirlo (`EstadoSesion.avisoSinConexion` no lo lee
nadie) y `PerfilTab` no tiene "deslizar para actualizar". La parte destructiva
ya se arregló aquí; lo que queda es decisión de interfaz.

**Ojo para quien venga después:** esta revisión es de QA. **No sustituye** la
revisión de `security-agent` que las tareas 018, 019 y 020 siguen teniendo
pendiente sobre el almacenamiento del token y la cadena de filtros.
