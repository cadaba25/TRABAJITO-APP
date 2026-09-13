---
id: 043
titulo: "Iconografía — fase 0: paquete Lucide, mapa completo Icons.*→LucideIcons.* y compartido/widgets (ADR-0017)"
estado: hecho
agente: "flutter-agent"
creada: 2026-09-12
completada: 2026-09-12
rama: "feature/hotfixes-qa-039"   # NO se creó feature/iconografia-fundamentos: se ejecutó directo sobre la rama vigente por instrucción explícita de coordinación (dos flutter-agent más trabajando en background sobre el mismo working tree en 041/037); cambios sin commit, ver reporte
---

## Objetivo

Sentar la base de la migración de iconografía (ADR-0017): añadir la
dependencia `lucide_icons_flutter`, fijar por escrito el mapa completo de los
100 glifos de `Icons.*` en uso hoy a su equivalente `LucideIcons.*` (con los
casos semánticos ya decididos en el ADR), y aplicar esa migración a los 8
archivos de `lib/compartido/widgets/` — son transversales a todos los módulos,
así que migrarlos aquí evita que dos tareas de funcionalidad distintas toquen
el mismo archivo compartido.

Sin esto, ninguna tarea posterior (044-047) tiene una dependencia declarada
ni un criterio único para los glifos ambiguos.

## Contexto relevante

- `docs/decisions.md` → **ADR-0017** completo: la comparación de paquetes
  (por qué `lucide_icons_flutter` y no `lucide_icons`), la auditoría de los
  100 glifos/203 usos/52 archivos, y la tabla de equivalencias semánticas
  para los 7 casos sin nombre literal.
- `docs/decisions.md` → ADR-0016 (tokens de tipografía/espaciado/paleta — no
  se tocan aquí) y ADR-0014 (estructura por funcionalidad, techo de 300
  líneas — sigue vigente).
- `pubspec.yaml` — patrón de comentario que justifica cada dependencia
  (ver el bloque de `http`/`flutter_secure_storage`/`provider`); sigue el
  mismo estilo al añadir `lucide_icons_flutter`.

## Lo que NO es esta tarea

- No toca ninguna pantalla de `lib/funcionalidades/**` todavía — eso son las
  tareas 044-047.
- No toca `lib/screens/` (los 4 archivos que siguen en Firestore) — fuera de
  alcance de ADR-0017.
- No toca tokens de tipografía/espaciado/paleta (ADR-0016) ni el vocabulario
  de movimiento (ADR-0015).
- No introduce una capa de abstracción propia sobre los iconos
  (`AppIconos.*` o similar) — ADR-0017 decisión 5 la descarta por ahora; si
  al hacer el mapa completo encuentras evidencia real y concreta de que hace
  falta, anótalo en el reporte para que el `tech-lead` lo decida, no la
  crees sobre la marcha.

## Qué construir

1. **Añade `lucide_icons_flutter` a `pubspec.yaml`** (última versión estable
   al momento de ejecutar la tarea — verifica en pub.dev que sigue siendo el
   paquete más mantenido antes de fijar la versión, no asumas que la cifra de
   este ADR sigue vigente si ya pasó tiempo). Comenta la elección en
   `pubspec.yaml` con el mismo estilo que las dependencias anteriores
   (una o dos líneas, referencia a ADR-0017).
2. **Construye el mapa completo de los 100 glifos.** Parte de
   `grep -rn "Icons\." lib | grep -oE "Icons\.[A-Za-z0-9_]+" | sort -u` para
   confirmar que sigue siendo 100 (si cambió porque algo se tocó entre el
   ADR y esta tarea, documenta la diferencia) y arma una tabla
   `Icons.*` → `LucideIcons.*` para los 100, con una columna de
   literal/semántico. Dónde vive esa tabla es tu decisión de implementación
   (el reporte de la tarea, un comentario largo en un archivo, o ambos) —
   pero **tiene que ser un artefacto único y citable por número de tarea**,
   igual que el reporte de la 031 fijó los nombres de tokens para que
   032-037 los citaran sin reinventarlos.
3. **Resuelve los 7 casos semánticos de la tabla de ADR-0017** (trabajo,
   foro/chat, filtros, documento genérico, categoría, doble check, género) —
   son una decisión ya tomada en el ADR, tu trabajo es aplicarla, no
   revisarla. Si al auditar encuentras un octavo caso sin nombre literal que
   el ADR no previó, resuélvelo con el mismo criterio (semántica del
   concepto, no visual del glifo) y anótalo en el reporte.
4. **Migra los 8 archivos de `lib/compartido/widgets/`**:
   `botones_si_no.dart`, `custom_dropdown.dart`, `custom_textfield.dart`,
   `entrada_etiquetas.dart`, `estado_exito.dart`, `estrellas.dart`,
   `mostrar_snackbar.dart`, `resenas.dart`. Sustituye cada `Icons.*` por su
   `LucideIcons.*` según el mapa del punto 2. Presta atención a
   `estrellas.dart` (rating con estrellas — usado en `resenas.dart` y en el
   flujo de calificar): verifica que `LucideIcons.star`/`starHalf` rindan
   visualmente igual de reconocibles a la escala en la que se usan hoy.
5. **No migres ninguna pantalla de `funcionalidades/**` en esta tarea** — el
   objetivo es que el paquete y el mapa existan, y que los 8 widgets
   compartidos ya usen Lucide, no adelantar trabajo de 044-047.

## Criterios de aceptación

- [x] `pubspec.yaml` declara `lucide_icons_flutter` con su comentario de
      justificación (regla 5 de `CLAUDE.md`).
- [x] El mapa completo de los 100 glifos existe como artefacto citable
      (ver punto 2), con los 7+ casos semánticos resueltos.
- [x] Los 8 archivos de `lib/compartido/widgets/` migrados a `LucideIcons.*`,
      cero `Icons.*` restantes en esos archivos
      (`grep -n "Icons\." lib/compartido/widgets/*.dart` vacío tras el
      cambio, salvo que quede un uso justificado y documentado — verifica
      qué es antes de asumir que hace falta).
- [x] Ningún archivo tocado pasa de 300 líneas como consecuencia de este
      cambio.
- [x] `flutter analyze` sin errores nuevos (compara contra el conteo base
      documentado en `docs/agent-context/repo-snapshot.md` al momento de
      empezar).
- [x] `flutter test` pasa completo; si algún test de widget buscaba un
      `Icons.*` concreto (`find.byIcon(Icons.algo)`), actualízalo al
      `LucideIcons.*` correspondiente y anótalo — no lo dejes en rojo ni lo
      borres sin más.
- [x] Verificación visual (emulador si está disponible, o capturas
      reales montando los widgets con datos falsos si no lo está — mismo
      criterio que usó ADR-0016) de al menos `estrellas.dart`/`resenas.dart`
      y `mostrar_snackbar.dart` antes/después.
- [x] Reporte en `docs/agent-reports/043-*.md` con el mapa completo de los
      100 glifos (para que 044-047 lo citen por nombre, no lo reinventen) y
      la justificación de la dependencia.

## Notas del agente que la ejecuta

Ejecutada 2026-09-12. Ver `docs/agent-reports/043-iconografia-fundamentos-lucide.md`
para el detalle completo (mapa de 100 glifos, hallazgo del octavo caso
semántico —Lucide no tiene "estrella rellena" separada de la vacía— y
resultado de analyze/test). Resumen:

- No se creó la rama `feature/iconografia-fundamentos`: por instrucción de
  coordinación explícita (dos `flutter-agent` más trabajando en background
  sobre 041/037 en el mismo working tree de `feature/hotfixes-qa-039`), se
  trabajó directo sobre esa rama y los cambios se dejaron SIN commit.
- `pubspec.yaml` + `pubspec.lock`: `lucide_icons_flutter: ^3.1.19` (versión
  vigente confirmada contra pub.dev el mismo día, coincide con ADR-0017).
  `flutter pub get` solo trajo esa dependencia nueva.
- Los 8 archivos de `lib/compartido/widgets/` migrados. Se encontró y
  corrigió un octavo caso semántico no previsto por el ADR: Lucide no tiene
  glifo de "estrella rellena" (es un set de solo trazo), así que
  `Estrellas`/`ResumenCalificacion` ahora distinguen llena/vacía por COLOR
  (`AppColores.dorado` vs `AppColores.grisMedio`), no solo por glifo. Se
  verificó visualmente (capturas antes/después) y se agregó
  `test/compartido/widgets/estrellas_test.dart` para fijarlo.
- `test/compartido/widgets/estado_exito_test.dart` actualizado
  (`Icons.check_circle_rounded` → `LucideIcons.circleCheck`).
- `flutter analyze`: 12-14 issues preexistentes, 0 nuevos. `flutter test`:
  270/270 (268 previos + 2 nuevos de `estrellas_test.dart`).
