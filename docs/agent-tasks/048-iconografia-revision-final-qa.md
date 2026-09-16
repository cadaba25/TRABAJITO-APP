---
id: 048
titulo: "Iconografía — revisión final de consistencia y regresión (ADR-0017)"
estado: bloqueada
agente: "qa-agent"
creada: 2026-09-12
rama: ""   # se define al empezar; revisa sobre las ramas de 043-047 ya mergeadas entre sí
---

## Objetivo

Cierre de la migración de iconografía (ADR-0017): revisión de consistencia
visual cruzada entre las 5 tareas anteriores (043-047), confirmación de que
no queda ningún `Icons.*` fuera del alcance excluido, y regresión funcional
completa, antes de pedir el PR final contra `develop`.

**Depende de que 043-047 estén todas en `en-revision` o `hecho`.** En
particular, 046 y 047 no pueden empezar hasta que 041 y 037 (de otra
iniciativa) estén cerradas — ver sus propios archivos de tarea — así que
esta revisión final llega necesariamente después de esas dos también.

## Contexto relevante

- ADR-0017 completo, y los 5 reportes de las tareas 043-047.
- `docs/development.md` → checklist de "tarea terminada".
- El mismo patrón que usó `038-rediseno-revision-final-qa.md` para ADR-0016 —
  no es necesario reinventar el criterio, solo aplicarlo a iconos en vez de
  tipografía/espaciado.

## Qué hacer

1. **Barrido completo de `Icons.*` restantes**:
   `grep -rn "Icons\." lib` debe devolver **solo** los 4 archivos de
   `lib/screens/` (excluidos a propósito por ADR-0017) más, si existiera,
   algún uso justificado y documentado en el reporte de la tarea que lo dejó.
   Cualquier otro resultado es una tarea que quedó incompleta — repórtalo al
   `tech-lead` en vez de arreglarlo tú mismo.
2. **Consistencia cruzada**: recorre las 5 pestañas del `BottomNav` más los
   flujos de publicar/postularse/aceptar/detalle/registro (en el emulador o
   con capturas si no hay emulador disponible) y verifica que el mismo
   concepto (por ejemplo "trabajo"/maletín, "chat"/mensaje, "perfil"/persona)
   use el mismo glifo de Lucide en todas las funcionalidades donde aparece —
   es el punto entero de tener un mapa único fijado en la tarea 043.
3. **Pares activo/inactivo**: confirma en `inicio_screen.dart` que las 5
   pestañas siguen distinguiendo visualmente su estado seleccionado/no
   seleccionado (ver el criterio que dejó la 047 documentado en su reporte).
4. **Ninguna familia mixta**: confirma que ninguna pantalla en alcance
   mezcla `Icons.*` y `LucideIcons.*` a la vez (sería precisamente lo que la
   skill de diseño prohíbe en su §7) — una búsqueda por archivo, no solo un
   conteo global.
5. **Regresión**: `flutter analyze` (compara contra el conteo base) y
   `flutter test` completo. Si algún test de widget quedó desactualizado por
   un `find.byIcon` que cambió a propósito, verifica que el agente que lo
   tocó lo haya actualizado y anotado.
6. Si encuentras una inconsistencia entre tareas (p. ej. dos glifos distintos
   para el mismo concepto en dos pantallas), repórtalo al `tech-lead` en vez
   de arreglarlo tú mismo — puede implicar reabrir una tarea ya cerrada.

## Criterios de aceptación

- [ ] Resultado del barrido de `Icons.*` documentado (qué queda y por qué es
      correcto que quede, o qué hay que reabrir).
- [ ] Tabla de glifos verificados por concepto transversal (concepto,
      glifo de Lucide usado, pantallas donde aparece, consistente sí/no) en
      el reporte.
- [ ] `flutter analyze` y `flutter test` documentados con sus cifras finales.
- [ ] Lista de inconsistencias encontradas (si las hay) entregada al
      `tech-lead`, no resuelta unilateralmente.
- [ ] Reporte en `docs/agent-reports/048-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
