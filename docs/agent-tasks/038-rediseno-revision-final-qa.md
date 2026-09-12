---
id: 038
titulo: "Rediseño visual — revisión final de consistencia y regresión (ADR-0016)"
estado: todo
agente: "qa-agent"
creada: 2026-09-11
rama: ""   # se define al empezar; revisa sobre las ramas de 031-037 ya mergeadas entre sí
---

## Objetivo

Cierre del rediseño (ADR-0016): revisión de consistencia visual cruzada entre
las 6 tareas anteriores (031–037) y regresión funcional completa, antes de
pedir el PR final contra `develop`. Ninguna de las tareas 032–037 se prueba
sola contra el árbol completo — esta es la que lo hace.

**Depende de que 031–037 estén todas en `en-revision` o `hecho`.**

## Contexto relevante

- ADR-0016 completo, y los 6 reportes de las tareas 031–037.
- `docs/development.md` → checklist de "tarea terminada".

## Qué hacer

1. **Consistencia cruzada**: recorre las 5 pestañas del `BottomNav` más los
   flujos de publicar/postularse/aceptar/detalle en el emulador (o revisando
   capturas si no hay emulador disponible en el entorno) y verifica que el
   mismo tipo de elemento (título de pantalla, chip, botón primario, tarjeta)
   se vea igual en todas las funcionalidades — es el punto entero de tener
   tokens compartidos.
2. **Contraste**: verifica a mano (fórmula WCAG, como hizo la 031) los pares
   texto/fondo que cambiaron, en claro y oscuro, en al menos: botón primario,
   botón secundario, chip de categoría/plazo, aviso de "sin conexión"/"CV sin
   cargar", precio/presupuesto.
3. **Regresión**: `flutter analyze` (compara contra el conteo base) y
   `flutter test` completo. Si algún test de widget quedó desactualizado por
   un valor visual que cambió a propósito, verifica que el agente que lo tocó
   lo haya actualizado y anotado (no lo aceptes sin más si solo se comentó el
   assert).
4. **reduced-motion**: confirma que ninguna de las 7 tareas tocó
   `lib/nucleo/movimiento/` ni el comportamiento de `MediaQuery.disableAnimations`
   — el rediseño visual no debía tocar eso.
5. Si encuentras una inconsistencia entre pantallas de distintas tareas
   (p. ej. dos radios de tarjeta distintos que deberían ser el mismo token),
   repórtalo al `tech-lead` en vez de arreglarlo tú mismo — puede implicar
   reabrir una tarea ya cerrada.

## Criterios de aceptación

- [ ] Tabla de contraste verificado (par, contexto, ratio, pasa/no pasa AA)
      en el reporte.
- [ ] `flutter analyze` y `flutter test` documentados con sus cifras finales.
- [ ] Lista de inconsistencias encontradas (si las hay) entregada al
      `tech-lead`, no resuelta unilateralmente.
- [ ] Reporte en `docs/agent-reports/038-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
