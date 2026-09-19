---
id: 039
titulo: "Hotfixes de QA del dueño sobre trabajos/inicio (letra del logo, degradados, scroll, tarifa)"
estado: hecho
agente: "flutter-agent"
creada: 2026-09-12
rama: "feature/hotfixes-qa-039"   # sobre feature/rediseno-postulaciones (036)
---

## Objetivo

Cinco arreglos puntuales que el dueño pidió al revisar 034-036 en el
emulador, sin relación entre sí más que "encontrados en la misma pasada de
QA". Ninguno cambia contrato de API ni modelo de datos — todos son
Flutter-only. Se agrupan en una tarea para no abrir cinco ramas de una línea.

**Depende de 036 (rama base). No depende de 037**, pero **037 va a reabrir
`cabecera_perfil.dart` e `inicio_screen.dart`** para tokens — mergea esta
primero para que 037 parta de la versión ya arreglada, no al revés.

## Contexto relevante

- ADR-0016 (tokens ya aplicados en los archivos de `trabajos/`, `postulaciones/`
  — no los toques salvo que la corrección lo exija).
- **Adenda del 2026-09-12 en ADR-0015** (`docs/decisions.md`, al final de la
  sección de alternativas descartadas de ADR-0015): autoriza explícitamente
  el punto 2 de abajo como excepción a la lista cerrada de movimiento.
- `lib/compartido/widgets/logo_trabajito.dart` — el logo de marca.
- `lib/funcionalidades/trabajos/pantallas/trabajos_tab.dart` y sus widgets
  `barra_busqueda_trabajos.dart` / `toggle_feed_trabajos.dart`.
- `lib/funcionalidades/trabajos/pantallas/widgets/encabezado_feed.dart` y
  `lib/funcionalidades/perfil/pantallas/widgets/cabecera_perfil.dart` — ambos
  usan el mismo `LinearGradient(colors: [AppColores.principal,
  AppColores.azulProfesional])`.
- `lib/funcionalidades/trabajos/pantallas/publicar_trabajo_screen.dart` —
  `presupuesto` es un `String` de texto libre tanto en el modelo
  (`lib/compartido/modelos/publicacion.dart:17`, comentario "texto libre") como
  en lo que se manda a la API — **confirmado antes de crear esta tarea**, así
  que el punto 5 no requiere tocar `backend/` ni cambiar el contrato.

## Qué hacer

1. **Letra dorada del logo, en la "i" no en la "t".**
   `LogoTextoSolo` y `LogoTrabajito` en `logo_trabajito.dart` pintan hoy la
   segunda "t" de "Trabajito" en `AppColores.dorado` (línea ~65 y ~101). El
   dueño pidió que sea la **"i"** la que va en dorado (que es, confirmado en
   `app_colores.dart:10`, el "Amarillo Dorado" `#FFC107` de la paleta de
   marca — no hay ningún otro tono de amarillo declarado). Cambia el split de
   `TextSpan` de `'Trabaji' + 't'(dorado) + 'o'` a `'Trabaj' + 'i'(dorado) +
   'to'` en ambos widgets. Verifica si algún test de golden/widget asume el
   split actual.

2. **Ocultar la barra de búsqueda/filtros y el toggle al hacer scroll**
   (`trabajos_tab.dart`). Hoy `BarraBusquedaTrabajos` (búsqueda + chips
   Todos/Corto/Medio/Largo plazo) y, para empleadores, `ToggleFeedTrabajos`
   ("Trabajos"/"Mis publicaciones") son hijos fijos de la `Column` por encima
   del `Expanded(child: _feed(...))` — no reaccionan a `_scrollCtrl` en
   absoluto, lo que el dueño describe como "un corte agresivo" cuando el
   contenido de la lista pasa por debajo del borde inferior de esas barras.
   Corrige envolviendo ambas barras en algo que colapse su altura al hacer
   scroll hacia abajo y la restaure al subir (p. ej. `AnimatedSize` +
   `SizeTransition`/`ClipRect` atado a la dirección de
   `_scrollCtrl.position.userScrollDirection`, o un `SliverAppBar` `floating`/
   `snap` si migras `ListView.builder` a `CustomScrollView` — tu criterio, la
   `CabeceraPostulantes` de la 036 y la `EntradaEscalonada` de ADR-0015 son
   los precedentes de patrón en esta misma carpeta). Aplica
   `MovimientoAccesible`/`reduced-motion` igual que el resto de
   `AppMovimiento` — es requisito de "hecho" según ADR-0015 punto 5, no un
   extra. Esto está **autorizado explícitamente** como excepción puntual a la
   lista cerrada de ADR-0015 (ver adenda 2026-09-12) — no lo repliques en
   otra pantalla sin pasar otra vez por ese ADR.

3. **Degradado con banding/pixelado en `encabezado_feed.dart` y
   `cabecera_perfil.dart`.** Ambos widgets pintan el mismo
   `LinearGradient(colors: [AppColores.principal, AppColores.azulProfesional])`
   de esquina a esquina sobre un área relativamente grande, y el dueño lo ve
   "de baja resolución" en el emulador (banding/escalones de color, no un
   asset de imagen). Antes de tocar nada, **confirma en el emulador real qué
   es**: banding de gradiente (arréglalo con más paradas de color intermedias
   entre `principal` y `azulProfesional`, o verificando si el `Paint` interno
   necesita dithering) vs. algo distinto (p. ej. un `BorderRadius` con
   antialiasing pobre, o composición con `CircleAvatar` semitransparente
   encima). Documenta qué era realmente y por qué la corrección elegida lo
   resuelve — no asumas la causa sin mirarlo.

4. **Reestructurar el campo de pago en `publicar_trabajo_screen.dart`**
   (y de paso `editar_trabajo_screen.dart`, que tiene el mismo campo aunque
   esté deshabilitado — mantenlo consistente aunque no se pueda guardar).
   Hoy es un solo campo "Pago por hora en Lempiras (opcional)" que compone
   `'L. $monto/hora'` a mano (línea ~92 de `publicar_trabajo_screen.dart`).
   Cámbialo a: un campo "Tarifa en Lempiras" (mismo tipo numérico) **más**,
   al lado, un selector (chip/dropdown — tu criterio, sigue el patrón de
   `ChoiceChip` que ya usa el "Plazo de contratación" en la misma pantalla)
   para elegir la unidad: **día / hora / semana / contratación completa**.
   Sigue componiendo el mismo `presupuesto: String` de siempre (p. ej.
   `'L. 150/día'`, `'L. 5000/semana'`, `'L. 20000 (contratación)'` — el
   formato exacto de "contratación" queda a tu criterio, documenta cuál
   elegiste). **No toques `PublicacionService` ni ningún endpoint**: sigue
   siendo texto libre en el mismo campo del payload.

5. **NO hagas el punto de "descargar íconos de las skills"** — quedó
   pendiente de que el dueño aclare a qué se refería exactamente
   (conversación en curso); no es parte de esta tarea.

## Qué NO es esta tarea

- No toca `backend/` — ningún punto de arriba lo requiere (verificado en
  "Contexto relevante").
- No habilita la edición de una publicación ya guardada (`PUT
  /api/trabajos/{id}`) — eso es una tarea aparte, cross-módulo, que el
  `tech-lead` está planificando por separado.
- No aplica tokens de ADR-0016 a `cabecera_perfil.dart` ni a
  `inicio_screen.dart` más allá de lo estrictamente necesario para el punto 3
  (esa tokenización completa es la tarea 037, que va después).

## Criterios de aceptación

- [x] Los 5 puntos (1-4, el 5 es "no hacer nada") implementados y
      verificados en el emulador con captura antes/después.
- [x] `flutter analyze` sin errores nuevos; `flutter test` verde (o los
      tests afectados actualizados y anotados, si el split de `TextSpan` del
      logo rompe algún golden/widget test).
- [x] Reporte en `docs/agent-reports/039-*.md`, con la causa real del
      banding del punto 3 documentada explícitamente (no una suposición).

## Notas del agente que la ejecuta

- Punto 1: split de `TextSpan` cambiado en `LogoTextoSolo`/`LogoTrabajito`.
  Ningún test existente asumía el split anterior; se añadió
  `test/compartido/widgets/logo_trabajito_test.dart` (no había cobertura de
  este widget).
- Punto 2: mecanismo elegido `SizeTransition` + `AnimationController`
  (envolviendo, no desmontando, los widgets reales — el buscador no tiene
  `TextEditingController` propio) atado a `ScrollPosition.userScrollDirection`,
  extraído a `widgets/colapso_barras_scroll.dart` para no pasar de 300 líneas
  en `trabajos_tab.dart`. Verificado con gestos reales (`adb shell input
  swipe`) en el emulador: las barras colapsan al bajar y reaparecen al subir.
- Punto 3: causa real confirmada — degradado diagonal de 2 paradas, Impeller
  (backend OpenGLES en este emulador, confirmado por el log de `flutter
  run`) lo renderiza sin dithering (`RenderUniform`/`FastLinearGradient`, a
  diferencia de `RenderSSBO` que sí llama `IPOrderedDither8x8`). Arreglado
  con una tercera parada (`AppColores.azulClaro`) fuera de la recta original.
  Verificado con `adb exec-out screencap` + muestreo de píxeles antes/después
  (ver reporte).
- Punto 4: campo + selector extraídos a `widgets/selector_tarifa.dart`,
  reusado en editar (deshabilitada) y publicar. Verificado en vivo en ambas
  pantallas (incluida la detección best-effort de la unidad ya guardada al
  editar).
- Tuve que reconstruir la app con `flutter run` completo (no solo `flutter
  attach` + hot reload/restart) para que el emulador reflejara de verdad
  todos los cambios — `flutter attach` en este entorno dejó al menos una
  pantalla (`PublicarTrabajoScreen`) con código compilado viejo pese a
  reportar "Restarted application" sin error. El proceso de `flutter run`
  que dejo corriendo al terminar es nuevo (pid de la app 19964, reemplaza al
  18625 que ya existía); sigue siendo la app real, con sesión iniciada.
