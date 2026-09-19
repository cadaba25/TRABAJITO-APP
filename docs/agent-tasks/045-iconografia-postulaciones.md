---
id: 045
titulo: "Iconografía — postulaciones (ADR-0017)"
estado: todo
agente: "flutter-agent"
creada: 2026-09-12
rama: "feature/iconografia-postulaciones"   # sobre feature/iconografia-fundamentos (043)
---

## Objetivo

Aplicar el mapa de la tarea 043 a la funcionalidad `postulaciones`: los 3
archivos que usan `Icons.*` hoy — `mis_postulaciones_screen.dart`,
`widgets/estados_postulantes.dart`, `widgets/tarjeta_postulante.dart`.

**Depende de la 043. No depende de 044/046/047** — puede ir en paralelo a la
044 si hace falta; es la tarea más chica de esta iniciativa.

## Contexto relevante

- ADR-0017. Reporte de la 043 para el mapa `Icons.*` → `LucideIcons.*`.
- `docs/agent-tasks/036-rediseno-postulaciones.md` y su reporte — cómo quedó
  la funcionalidad tras ADR-0016; no rehagas esa partición ni esos tokens,
  solo sustituye los iconos.

## Qué NO es esta tarea

- No cambia el contrato con `PostulacionService` ni el flujo de
  aceptar/rechazar postulantes.
- No toca `postulantes_screen.dart`, `postularse_sheet.dart` ni
  `widgets/cabecera_postulantes.dart` — no usan `Icons.*` hoy; si al empezar
  esta tarea descubres que sí (por un cambio posterior de otra tarea),
  inclúyelos y anótalo en el reporte.

## Qué hacer

1. Reemplaza cada `Icons.*` por su `LucideIcons.*` equivalente (mapa de la
   043) en los 3 archivos listados arriba.
2. Verifica los iconos de estado (aceptado/rechazado/pendiente en
   `estados_postulantes.dart`) contra el mapa — son los que más se repiten
   en la pantalla y los que más se notan si quedan inconsistentes con el
   resto de la app.

## Criterios de aceptación

- [ ] Los 3 archivos usan `LucideIcons.*`; cero `Icons.*` restantes
      (`grep -rn "Icons\." lib/funcionalidades/postulaciones` vacío, salvo
      un uso justificado y documentado).
- [ ] Ningún archivo pasa de 300 líneas como consecuencia de este cambio.
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde (incluidos
      los tests de `test/funcionalidades/postulaciones/`, actualizando
      cualquier `find.byIcon` que dependiera del icono viejo).
- [ ] Capturas antes/después de "Mis postulaciones" y de la lista de
      postulantes (claro y oscuro).
- [ ] Reporte en `docs/agent-reports/045-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
