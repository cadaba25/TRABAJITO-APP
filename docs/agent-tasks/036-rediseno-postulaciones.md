---
id: 036
titulo: "Rediseño visual — postulaciones (ADR-0016)"
estado: hecho
agente: "flutter-agent"
creada: 2026-09-11
rama: "feature/rediseno-postulaciones"   # sobre feature/rediseno-detalle-trabajo (035)
---

## Objetivo

Aplicar los tokens de la tarea 031 a `postulantes_screen.dart` (192),
`mis_postulaciones_screen.dart` (297), `postularse_sheet.dart` (149), y sus
widgets extraídos (`cabecera_postulantes.dart`, `estados_postulantes.dart`,
`tarjeta_postulante.dart`).

**Depende de la 031. Puede ir en paralelo a 034/035** (funcionalidad
distinta), pero se recomienda ir en orden para no repartir la revisión de QA
en demasiados PRs simultáneos.

## Contexto relevante

- ADR-0016. Reporte de la 031.
- `docs/agent-reports/027b2b-partir-archivos.md`.

## Qué NO es esta tarea

- No cambia el flujo de aceptar/rechazar postulantes ni las llamadas a
  `PostulacionService`.
- No toca la tarea 029 (tests de pantalla pendientes de `qa-agent` para
  `postulantes_screen`) — si esta tarea entra primero, avisa a `qa-agent`
  para que la 029 escriba los tests contra la versión ya rediseñada, no al
  revés.

## Criterios de aceptación

- [x] Los 5 archivos usan los tokens de la 031.
- [x] `flutter analyze` sin errores nuevos; `flutter test` verde.
- [x] Capturas antes/después (claro y oscuro) de la lista de postulantes con
      0, 1 y varios candidatos.
- [x] Reporte en `docs/agent-reports/036-*.md`.

## Notas del agente que la ejecuta

- Se tokenizaron **6** archivos, no 5: el archivo de tarea lista
  `postulantes_screen.dart`, `mis_postulaciones_screen.dart`,
  `postularse_sheet.dart` + 3 widgets extraídos
  (`cabecera_postulantes.dart`, `estados_postulantes.dart`,
  `tarjeta_postulante.dart`) — son 6 en total, el "5" del título de la
  sección de contexto contaba solo las 3 pantallas.
- `mis_postulaciones_screen.dart` terminó en 298 líneas (era 297), 2 líneas
  del techo de 300 (ADR-0014). No se extrajo ningún widget nuevo de aquí:
  duplica los estados vacío/error de `postulantes_screen.dart` (deuda
  preexistente, fuera del alcance de "solo tokens" de esta tarea).
- El diálogo `_seleccionar` de `postulantes_screen.dart` no se migró al
  componente compartido `mostrarDialogoConfirmacion` (035) porque ese
  componente fija los botones "No"/"Sí" con estilo destructivo (rojo) para
  la acción afirmativa, y aquí los botones son "Cancelar"/"Seleccionar" sin
  semántica destructiva — reusarlo habría cambiado texto/color visibles,
  fuera del alcance de "solo tokens". Se tokenizó in-place con el mismo
  patrón (`AppRadios.tarjeta`, `textTheme.subtitulo`/`cuerpo` +
  `colorTextoFuerte`/`colorTextoSuave`).
- "Postularme" (`postularse_sheet.dart`, 20/w800) se mapeó a `titulo`
  (22/w700) y no a `numero` (20, tamaño exacto): `numero` es explícitamente
  para montos/precios con cifras tabulares, no para encabezados de hoja
  modal — mismo tipo de juicio semántico-sobre-tamaño que ya usó la 035.
- Hallazgo lateral, no corregido (mismo patrón que 034/035 ya dejaron
  anotado, distinto del que arregló `colorPrecio()`): en
  `tarjeta_postulante.dart` el avatar-inicial y el ícono de comillas pintan
  `AppColores.acento` como texto/ícono sobre un tinte muy claro del propio
  dorado (6–15% de opacidad), no sobre una superficie sólida blanca. Se
  anota para que QA o una tarea de contraste dedicada lo revise.
- Ver `docs/agent-reports/036-rediseno-postulaciones.md` para el detalle
  completo (mapeo de tokens, verificación, capturas).
