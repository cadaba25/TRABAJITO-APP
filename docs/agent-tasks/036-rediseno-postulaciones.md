---
id: 036
titulo: "Rediseño visual — postulaciones (ADR-0016)"
estado: todo
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

- [ ] Los 5 archivos usan los tokens de la 031.
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde.
- [ ] Capturas antes/después (claro y oscuro) de la lista de postulantes con
      0, 1 y varios candidatos.
- [ ] Reporte en `docs/agent-reports/036-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
