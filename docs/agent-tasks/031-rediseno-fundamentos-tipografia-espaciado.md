---
id: 031
titulo: "Rediseño visual — fase 0: tokens de tipografía/espaciado + arreglo de contraste (ADR-0016)"
estado: todo
agente: "flutter-agent"
creada: 2026-09-11
rama: "feature/rediseno-fundamentos"   # crear sobre feature/movimiento-y-feedback (PR #9, aún sin fusionar); rebasar cuando #9 y #7 entren a develop
---

## Objetivo

Sentar la base del rediseño visual (ADR-0016): un type scale con nombre y una
escala de espaciado con nombre, más el arreglo de un defecto de contraste
verificado en el tema oscuro. Sin esto, ninguna tarea posterior (032–037)
tiene a qué tokens migrar.

**NO DELEGAR TODAVÍA.** ADR-0016 está en estado "Propuesto": el dueño tiene
que confirmar el alcance (en particular, si la paleta se corrige o se
reemplaza) antes de que esta tarea pase de `todo` a `en-progreso`.

## Contexto relevante

- `docs/decisions.md` → **ADR-0016** completo (léelo entero: trae la
  auditoría de valores sueltos, el defecto de contraste, y las dos listas
  cerradas de qué cambia y qué no).
- `docs/decisions.md` → ADR-0015 (vocabulario de movimiento — no se toca) y
  ADR-0014 (estructura por funcionalidad, techo de 300 líneas — sigue
  vigente).
- `lib/nucleo/tema/app_colores.dart`, `app_tema.dart`, `colores_por_tema.dart`
  — lo que ya existe; se extiende, no se reemplaza.
- Skills: `.claude/skills/apple-design/SKILL.md` §15 (tipografía) y §16
  (principios), `.claude/skills/emil-design-eng/SKILL.md` (aplica sobre todo
  a movimiento, ya cubierto — no dupliques trabajo de ADR-0015 aquí).

## Lo que NO es esta tarea

- No toca ninguna pantalla de `lib/funcionalidades/**/pantallas/` todavía —
  eso son las tareas 032–037.
- No cambia los tres colores de marca (marino/dorado/verde) — solo corrige
  el contraste verificado y completa roles semánticos que falten.
- No toca `lib/nucleo/movimiento/` ni el comportamiento de `PulsaConEscala`,
  `AnimatedSwitcher`, etc. (ADR-0015 intacto).
- No toca `lib/screens/` (los cuatro archivos que siguen en Firestore) —
  fuera de alcance de ADR-0016.
- No añade ninguna dependencia nueva.

## Qué construir

1. **`lib/nucleo/tipografia/app_tipografia.dart`**: type scale con nombre
   sobre `Sora` (roles sugeridos: `titulo`, `subtitulo`, `cuerpo`,
   `cuerpoChico`, `etiqueta`, `numero` para montos/precios — ajusta los
   nombres si al auditar las pantallas encuentras un rol que falta o uno que
   sobra, y anótalo en el reporte). Cada rol fija tamaño + peso +
   interlineado una sola vez. Debe quedar accesible desde
   `Theme.of(context).textTheme.<rol>` (extendiendo el `TextTheme` que ya
   arma `AppTema`) o, si eso no es viable con Material 3 sin perder los
   roles nativos que Flutter/Material ya usa internamente, un helper
   equivalente en el mismo archivo — documenta la decisión.
2. **`lib/nucleo/espaciado/app_espaciado.dart`**: constantes con nombre
   (`xs`=4, `sm`=8, `md`=12, `lg`=16, `xl`=24, `xxl`=32 — ajusta si la
   auditoría real de valores lo justifica, documenta por qué). Añade también
   los 2–3 roles de radio de borde (`chip`/`pastilla`, `tarjeta`, `campo`)
   aquí o en `AppTema`, consolidando los 10 valores de `BorderRadius.circular`
   detectados en la auditoría de ADR-0016.
3. **Arreglo de contraste en `AppTema.temaOscuro()`**: el `elevatedButtonTheme`
   y el `ColorScheme.dark(primary: acento, onPrimary: blanco)` dejan de poner
   texto blanco sobre fondo dorado (contraste verificado ~1.7:1, falla WCAG
   AA). Cambia el texto/`onPrimary` a un color que sí cumpla AA sobre
   `AppColores.acento` (candidato: `AppColores.principal`/`texto` — verifícalo
   con la fórmula de contraste, no lo des por bueno a ojo). Revisa si el mismo
   par se usa en otro sitio de `AppTema` (p. ej. `checkboxTheme`,
   cualquier chip que use `secondary`/`onSecondary`) y corrígelo también si
   aplica.
4. **Completa los roles semánticos que falten en `colores_por_tema.dart`** si
   al construir 1–3 identificas un hueco real (p. ej. "superficie alterna",
   "deshabilitado") — no inventes roles que ninguna pantalla vaya a usar
   todavía; dócumentalos para que 032–037 los consuman.
5. **No migres ninguna pantalla a los tokens nuevos en esta tarea** — el
   objetivo es que existan y que `AppTema` los use donde corresponde
   (colores globales de botones/inputs/appbar), no reescribir
   `tarjeta_trabajo.dart` ni ningún otro widget de pantalla.

## Criterios de aceptación

- [ ] `lib/nucleo/tipografia/app_tipografia.dart` y
      `lib/nucleo/espaciado/app_espaciado.dart` existen, cada uno ≤300 líneas.
- [ ] El defecto de contraste del modo oscuro está corregido y verificado
      con la fórmula de contraste (documenta el cálculo en el reporte, no
      solo "se ve mejor").
- [ ] `flutter analyze` sin errores nuevos (compara contra el conteo base
      documentado en `docs/agent-context/repo-snapshot.md`).
- [ ] `flutter test` pasa completo (los 212+ existentes) — este cambio toca
      `AppTema`, que varios tests de pantalla montan; si algún test dependía
      del color viejo del botón, corrígelo y anótalo.
- [ ] Captura antes/después del botón primario en modo oscuro, adjunta al
      reporte.
- [ ] Reporte en `docs/agent-reports/031-*.md` con la lista final de roles
      de tipografía/espaciado/radio definidos (para que 032–037 los citen
      por nombre, no los reinventen).

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
