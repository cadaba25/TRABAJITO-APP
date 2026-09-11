---
id: 028
titulo: "Vocabulario de movimiento único + feedback al tacto + reduced-motion (ADR-0015)"
estado: todo   # todo | en-progreso | en-revision | hecho | bloqueada
agente: "flutter-agent"
creada: 2026-09-10
rama: "feature/movimiento-y-feedback"   # creada sobre refactor/funcionalidades-b2b (PR #7, aún sin fusionar a develop); rebasar a develop cuando el #7 entre
---

## Objetivo

Aplicar al front las reglas de las skills de diseño del repo
(`emil-design-eng`, `apple-design`, `find-animation-opportunities`). Hoy la
app no tiene sistema de movimiento, las tarjetas no dan feedback al tacto, y
ninguna animación respeta `MediaQuery.disableAnimations`. **El diseño y la
lista cerrada de qué se anima y qué no están en ADR-0015 — léelo entero
antes de tocar nada.**

## Lo que NO es esta tarea

- **No es un rediseño visual.** No se toca la paleta (`AppColores`), la
  tipografía (`Sora`), ni el espaciado. Solo movimiento y feedback.
- **No se añade ningún paquete.** `AnimatedScale`, `AnimatedSwitcher`,
  `AnimatedContainer`, `TweenAnimationBuilder` del framework cubren todo.
- **No se cambia ninguna regla de negocio ni contrato de API.**
- **No se anima nada fuera de la lista cerrada de ADR-0015.** Si crees que
  otro sitio lo pide, anótalo en el reporte y NO lo implementes: lo decide
  el tech-lead.

## Contexto relevante

- `docs/decisions.md` → **ADR-0015** (la decisión completa, con la tabla de
  traducción web→Flutter y las dos listas cerradas).
- `docs/decisions.md` → ADR-0014 (estructura por funcionalidad; esta tarea
  respeta el techo de 300 líneas y el patrón `nucleo/`).
- Skills: `.claude/skills/emil-design-eng/`, `.claude/skills/apple-design/`,
  `.claude/skills/find-animation-opportunities/`.

## Alcance, por fases (cada fase = un commit, `analyze`+`test` verde antes de seguir)

### Fase 1 — `lib/nucleo/movimiento/` (los cimientos)

- `app_movimiento.dart` → `AppMovimiento`:
  - `Duration`: `microFeedback` (120 ms), `chico` (180 ms), `medio` (240 ms),
    `panel` (320 ms).
  - `Curve`: `entrada` (`Curves.easeOutCubic`), `panel`
    (`Cubic(0.32, 0.72, 0.0, 1.0)`), `estandar` (`Curves.easeInOut`).
  - Nada más. Ningún otro archivo declara un `Duration`/`Curve` de animación
    a mano después de esta tarea.
- `movimiento_accesible.dart` → helpers que leen
  `MediaQuery.maybeOf(context)?.disableAnimations ?? false`:
  - `duracionMov(context, base)` → `Duration.zero` si el sistema pide
    reducir.
  - `curvaMov(context, base)` → curva de fundido simple si reduce.
  - Un `extension` sobre `BuildContext` está bien si queda legible.
- Test: `test/nucleo/movimiento/movimiento_accesible_test.dart` — con
  `disableAnimations: true` en el `MediaQuery` de prueba, `duracionMov`
  devuelve cero; con `false`, devuelve la base. **Rompe el helper a
  propósito y comprueba que el test se pone rojo.**

### Fase 2 — `PulsaConEscala` (feedback al tacto)

- `lib/compartido/widgets/pulsa_con_escala.dart` → widget que envuelve un
  hijo pulsable: `AnimatedScale` a `0.97` en press-down, vuelta a `1.0` en
  release/cancel, `AppMovimiento.microFeedback`, `Curves.easeOut`, pasando
  por `movimiento_accesible` (si reduce: sin escala, el `onTap` sigue
  funcionando). Recibe `onTap` y opcional `onLongPress`. Usa
  `GestureDetector` con `onTapDown`/`onTapUp`/`onTapCancel`.
- **Sustituye** el `GestureDetector` desnudo en:
  `tarjeta_trabajo.dart`, `tarjeta_mi_publicacion.dart`,
  `tarjeta_postulante.dart` (postulaciones), los accesos rápidos de
  `accesos_rapidos_perfil.dart` si no son ya `ElevatedButton`, y la tarjeta
  de `mis_postulaciones_screen.dart`.
- **NO** toques `ElevatedButton`/`OutlinedButton` (Material ya da feedback).
- Test de widget: al mantener pulsada la tarjeta, su `scale` baja; con
  `disableAnimations` no cambia; el `onTap` se dispara igual en ambos casos.

### Fase 3 — Fundido entre estados de lista

- `AnimatedSwitcher` (`AppMovimiento.chico`, `curvaMov`) envolviendo el
  intercambio `cargando` ↔ `contenido` ↔ `error` ↔ `vacío` en:
  `trabajos_tab.dart` (`_feed`), `mis_publicaciones_screen.dart` (`_cuerpo`),
  `postulantes_screen.dart` (`_cuerpo`), `mis_postulaciones_screen.dart`.
- Solo fundido de opacidad (nada de slide). Cada rama necesita una `Key`
  estable para que el `AnimatedSwitcher` distinga los estados.
- Cuidado: no metas el `ListView` entero dentro del `AnimatedSwitcher` si
  eso rompe el `RefreshIndicator` o el `ScrollController` del feed — envuelve
  solo el contenido condicional, no el scroll.
- Los tests de pantalla existentes (`perfil_tab_test`,
  `trabajos_y_postulaciones_test`, etc.) **no cambian de aserción**. Si un
  `find` empieza a fallar por el `AnimatedSwitcher`, usa
  `tester.pumpAndSettle()` donde haga falta — no relajes el `expect`.

### Fase 4 — Stagger de la primera carga del feed

- Solo en `trabajos_tab.dart`, solo la **primera** vez que llega la lista
  (un `bool _primeraCargaHecha`), tope **6** ítems, `AppMovimiento.medio`,
  fundido + subida de 8 px, stagger de 40 ms por ítem vía
  `TweenAnimationBuilder` con `delay` por índice (o
  `AnimationController` escalonado). Con `disableAnimations`: aparecen sin
  stagger.
- **NO** al paginar (`_cargarMas`) ni al recargar deslizando.
- Test: tras la primera carga los ítems están visibles; el test no depende
  de tiempos frágiles (usa `pumpAndSettle`).

### Fase 5 — Flip de color de los chips de filtro seleccionados

- `barra_busqueda_trabajos.dart` (chips de plazo) y el toggle
  `Trabajos / Mis publicaciones` (`toggle_feed_trabajos.dart`):
  `AnimatedContainer` (`AppMovimiento.chico`, `curvaMov`) para el color de
  fondo y el borde al seleccionar. Nada de tamaño ni posición.

### Fase 6 — Estado de éxito tras publicar / postularse (presupuesto de "delight")

- Tras `POST /api/trabajos` (publicar) y `POST /api/postulaciones`
  (postularse) con éxito: un check que entra con `AnimatedScale` desde 0.6 a
  1.0, `AppMovimiento.medio`, `Curves.easeOutBack` con overshoot suave
  (equivale a `bounce 0.15`), visible ~700 ms y luego se hace el `pop`.
  Con `disableAnimations`: aparece el check sin escala y el `pop` ocurre
  igual.
- **Esta fase es la más discutible.** Si al implementarla ves que cambia el
  flujo de navegación de forma no trivial (p. ej. el `pop` ya devolvía un
  resultado que otra pantalla espera), **para y díselo al tech-lead** antes
  de seguir. Preferible un check sobrio a romper el "volver y recargar".

## Módulos afectados y orden de trabajo

Solo `lib/` (Flutter). Orden = las fases 1→6. Cada fase compila y pasa tests
por sí sola. Un commit por fase, mensaje `feat(mov): ...` o
`refactor(mov): ...`.

Archivos nuevos: `lib/nucleo/movimiento/app_movimiento.dart`,
`lib/nucleo/movimiento/movimiento_accesible.dart`,
`lib/compartido/widgets/pulsa_con_escala.dart`, + sus tests.
Archivos tocados: los 4–6 de tarjetas/listas de arriba,
`barra_busqueda_trabajos.dart`, `toggle_feed_trabajos.dart`, y las 2
pantallas de publicar/postularse.

## Criterios de aceptación

- [ ] `flutter analyze` no sube de la línea base (36 issues, 0 errores).
- [ ] `flutter test` no baja de la línea base (212) — sube con los tests
      nuevos de las fases 1, 2 y 4.
- [ ] **Ningún archivo animado sin su rama de `disableAnimations`.** Es
      requisito de "hecho" (ADR-0015 punto 5).
- [ ] Ningún `Duration`/`Curve` de animación declarado a mano fuera de
      `lib/nucleo/movimiento/`.
- [ ] Ningún archivo nuevo o tocado pasa de 300 líneas (ADR-0014).
- [ ] Se anima **solo** lo de la lista de ADR-0015. Nada más.
- [ ] La app se recorre en el emulador Pixel_6 con capturas/-video: feed
      (con y sin "reducir animaciones" en ajustes de Android), pulsar una
      tarjeta, cambiar de estado de lista, publicar un trabajo.
- [ ] `docs/architecture.md` menciona `lib/nucleo/movimiento/`.
- [ ] Reporte en `docs/agent-reports/028-movimiento-y-feedback.md`: qué se
      animó, con qué valores, qué se rechazó y por qué, y las capturas.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
