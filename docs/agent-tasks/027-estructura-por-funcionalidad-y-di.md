---
id: 027
titulo: "Reestructurar lib/ por funcionalidad, inyección de dependencias y techo de tamaño por archivo"
estado: en-progreso   # parte A hecha (2026-09-08); falta la parte B
agente: "flutter-agent"
creada: 2026-09-08
rama: "refactor/estructura-por-funcionalidad"
---

## Origen

Encargo directo del dueño del proyecto (2026-09-08):

> *"no quiero que el proyecto este trabajado en un solo archivo ej.
> «app.dart» con 20mil lineas de codigo, quiero que programes de una manera
> donde se le pueda dar mantenimiento y sea super escalable"*

El diseño y las alternativas descartadas están en **ADR-0014**, escrito antes
de esta tarea. **Léelo entero antes de tocar nada.** Aquí solo está el
trabajo concreto.

## Lo que NO es esta tarea

- **No se toca el backend.** Está medido y sano (65 líneas/archivo de media).
- **No se implementa Clean Architecture** de cuatro capas. Está descartada en
  el ADR con su porqué; si crees que te hace falta, para y dilo, no la metas.
- **No se migra ningún servicio de Firestore aquí.** Eso es la fase 2b-2 y va
  después, ya sobre la estructura nueva.
- **No se cambia el comportamiento de la app.** Al terminar, un usuario no
  debe notar absolutamente nada. Es un refactor puro.

## Alcance, en dos partes

### Parte A — Cimientos (hazla primero y entera)

1. **Añadir `provider`** a `pubspec.yaml`. Es la única dependencia nueva
   autorizada; está justificada en el ADR.
2. **Partir `lib/utils/constantes.dart`** (605 líneas, 15 clases sin
   relación). Reparto propuesto — ajústalo si al abrirlo ves algo mejor, y
   explica por qué en el reporte:
   - `nucleo/tema/` → `AppColores`, `AppTema`, `notificadorTema`
   - `nucleo/textos/` → `AppTextos`, `MensajesError`
   - `compartido/datos/` → `DatosHonduras`, `DatosEmpleador`
   - `nucleo/dominio/` → `EstadosTrabajo`, `EstadosPostulacion`,
     `TiposMensaje`, `MapeoEnumApi`, `RolesApi`, `CamposUsuario`,
     `ValoresDefecto`, `ReglasCuenta`
   - `FirestoreColecciones` → déjalo donde menos estorbe y **marca con un
     comentario que muere en la fase 3**.
3. **Crear el esqueleto de carpetas** de ADR-0014 y **mover una sola
   funcionalidad completa** como piloto: **`autenticacion`**. Es la que ya
   está migrada al backend y la que más test tiene, así que si algo se
   rompe, se nota.
4. **Registrar los servicios con `provider`** en el arranque, y hacer que las
   pantallas de `autenticacion` los reciban por inyección en vez de
   construirlos. `ApiClient.instancia` ya tiene `fijarInstancia()` para los
   tests — respeta ese mecanismo, no lo dupliques.

### Parte B — La base compartida primero, luego el resto

> **Orden corregido el 2026-09-08.** El plan original decía "mueve otra
> funcionalidad". Está **mal**, y lo demostró el agente que hizo la parte A:
> las pantallas de `autenticacion` dependen de `lib/widgets/` y su servicio de
> `lib/services/api/`, así que mover funcionalidades antes que la base deja
> imports como `../../../widgets/custom_textfield.dart`. **La base va
> primero.** El error era del plan, no de quien lo ejecutó.

**B-1 — La base compartida (haz esto antes que nada):**

1. `lib/services/api/` → `lib/nucleo/api/`. `api_client.dart` son **649
   líneas** y hay que partirlo al moverlo, no después. Candidatos de corte
   evidentes: la lógica de renovación con sus tres candados, el almacén de
   sesión, y el envío HTTP. **Cuidado**: los tres candados están documentados
   en el docstring de la clase y hay ~60 tests que dependen de
   `ApiClient.fijarInstancia`. Si el corte obliga a tocar esa API, **para y
   dilo** en vez de cambiarla.
2. `lib/widgets/` → `lib/compartido/widgets/`. `custom_textfield.dart` son
   **407 líneas** y casi seguro contiene varios widgets en un archivo:
   sepáralos, uno por archivo.

**B-2 — Las funcionalidades ya migradas al backend:**

Mueve `trabajos`, `postulaciones` y `perfil` a la estructura nueva, y **cierra
la anomalía que dejó la parte A**: hay dos instancias de `AuthService` vivas
porque 7 pantallas siguen construyendo la suya. Al terminar B-2 no debe quedar
ni un `final _x = AlgunService();` dentro de un `State`. (Verificado en la
parte A que no rompe nada hoy: el estado de sesión vive en el singleton global
`sesionActual`, no en la instancia; lo único por instancia es
`ultimoErrorPorCampo`, que son mensajes de validación de formulario.)

**`cartera`, `calificacion` y `chat` NO se mueven en esta tarea**: nacen
directamente en la estructura nueva cuando se migren (fase 2b-2). Crear sus
carpetas vacías ahora solo genera ruido.

**`detalle_trabajo_screen.dart` (1 143 líneas) y los registros (1 914) NO se
parten aquí.** El ADR lo dice: se parten cuando haya que abrirlos por otra
razón (el chat y la tarea 012 respectivamente). Partirlos ahora es un diff
enorme sin nada que lo verifique.

## Criterios de aceptación

- [ ] `flutter analyze` **no introduce errores nuevos**. Los 37 avisos
      actuales pueden bajar, no subir.
- [ ] `flutter test` sigue en **190 pasando**. Si un test cambia de ruta,
      cambia el import, no el test.
- [ ] **Ningún archivo Dart nuevo o movido pasa de 300 líneas.** Los tres
      monstruos conocidos quedan como están, con excepción anotada.
- [ ] Al menos **una pantalla que hoy no tiene test** gana uno que use un
      servicio falso inyectado. Es la prueba de que la DI sirve de algo: si
      no puedes escribirlo, la parte A no está terminada.
- [ ] La app **arranca y se recorre en el emulador** (`Pixel_6`, no
      `Pixel_9`): login → feed → detalle → perfil. Con capturas.
- [ ] `docs/architecture.md` refleja la estructura nueva.
- [ ] El reporte dice **qué se movió, qué no, y por qué**.

## Trampas conocidas

- **Mover archivos en Dart rompe imports en silencio hasta que compilas.**
  Corre `flutter analyze` después de cada funcionalidad movida, no al final.
- Usa **`git mv`**, no borrar y crear: si no, el historial se pierde y el
  diff se vuelve ilegible para revisar.
- `notificadorTema` es un `ValueNotifier` **global**. Al moverlo, comprueba
  quién lo escucha (`grep`) — es estado compartido disfrazado de constante.
- El commit de mover archivos y el de cambiar código **van separados**. Un
  commit que mueve y edita a la vez no se puede revisar.
