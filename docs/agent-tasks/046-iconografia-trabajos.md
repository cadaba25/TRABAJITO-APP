---
id: 046
titulo: "Iconografía — trabajos: feed, mis publicaciones, publicar/editar/detalle (ADR-0017)"
estado: bloqueada
agente: "flutter-agent"
creada: 2026-09-12
rama: ""   # se crea sobre feature/iconografia-fundamentos (043) SOLO cuando la 041 esté hecha y mergeada
---

## Objetivo

Aplicar el mapa de la tarea 043 a la funcionalidad `trabajos`: los 12
archivos que usan `Icons.*` hoy — `detalle_trabajo_screen.dart`,
`editar_trabajo_screen.dart`, `mis_publicaciones_screen.dart`,
`publicar_trabajo_screen.dart`, y los widgets
`widgets/{barra_busqueda_trabajos,dialogo_agregar_evidencia,estados_feed,
estados_mis_publicaciones,hoja_filtros_trabajos,selector_tarifa,
tarjeta_mi_publicacion,tarjeta_trabajo}.dart`.

## Por qué está `bloqueada` y no `todo`

**La tarea `041-flutter-editar-trabajo` está en curso ahora mismo sobre
exactamente estos mismos archivos** (`detalle_trabajo_screen.dart`,
`editar_trabajo_screen.dart`, `publicar_trabajo_screen.dart`,
`trabajos_tab.dart`, `widgets/encabezado_feed.dart`,
`datos/publicacion_service.dart` — ver `docs/agent-tasks/041-flutter-editar-trabajo.md`
y el estado real del working tree, no solo el campo `estado:` del archivo de
la 041, que puede no estar actualizado).

**No se despacha esta tarea hasta que `041` esté en `en-revision` o `hecho` y
esos cambios estén estables** (mergeados o al menos ya no en curso). Empezar
antes es la misma situación que la propia 041 describió para la 039: mismo
archivo, mismo widget, conflicto de merge seguro. Verifica el estado real de
la 041 (no asumas) antes de crear la rama de esta tarea.

También depende de la 043 (mapa y paquete instalados).

## Contexto relevante

- ADR-0017. Reporte de la 043 para el mapa `Icons.*` → `LucideIcons.*`.
- El reporte de la 041, una vez exista, para saber en qué quedaron
  exactamente esos archivos (esta tarea migra iconos sobre el código que deje
  la 041, no sobre el que había antes).
- `docs/agent-reports/034-rediseno-trabajos.md` y
  `docs/agent-reports/035-*.md` (ADR-0016) — cómo quedaron tokens de
  tipografía/espaciado en esta funcionalidad; no los toques, solo iconos.

## Qué NO es esta tarea

- No reactiva ni cambia el flujo de edición de trabajo (eso ya lo hizo/hace
  la 041).
- No cambia el contrato con `PublicacionService` ni la paginación
  (`pagina`/`tamano`).
- No toca tokens de tipografía/espaciado/paleta.

## Qué hacer

1. Antes de tocar nada, confirma en `docs/agent-tasks/041-flutter-editar-trabajo.md`
   que el estado es `en-revision` o `hecho`, y que la rama de la 041 ya está
   mergeada (o pide confirmación al `tech-lead` si no es obvio desde el
   repo).
2. Reemplaza cada `Icons.*` por su `LucideIcons.*` equivalente (mapa de la
   043) en los 12 archivos listados arriba.
3. Presta atención especial a `tarjeta_trabajo.dart` y
   `tarjeta_mi_publicacion.dart`: son los componentes más repetidos y más
   vistos de toda la app.
4. `detalle_trabajo_screen.dart` es una excepción viva al techo de 300
   líneas (ADR-0014) — no la agraves; si el cambio de iconos por algún motivo
   le añade líneas de forma notable, revisa por qué (no debería pasar en una
   sustitución 1:1) antes de darlo por bueno.

## Criterios de aceptación

- [ ] Confirmado y anotado en el reporte que la 041 estaba `hecho`/mergeada
      antes de empezar.
- [ ] Los 12 archivos usan `LucideIcons.*`; cero `Icons.*` restantes
      (`grep -rn "Icons\." lib/funcionalidades/trabajos` vacío, salvo un uso
      justificado y documentado).
- [ ] Ningún archivo pasa de 300 líneas como consecuencia de este cambio
      (`trabajos_tab.dart` estaba cerca del techo tras ADR-0016 — verifica su
      línea actual antes de tocarlo).
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde, incluidos
      los tests nuevos que haya dejado la 041 y cualquier `find.byIcon`
      existente.
- [ ] Capturas antes/después del feed, "Mis publicaciones", detalle de
      trabajo y el formulario de editar (claro y oscuro).
- [ ] Reporte en `docs/agent-reports/046-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja. El `tech-lead` debe cambiar `estado` a
`todo` cuando confirme que la 041 está `hecho`/mergeada — no lo cambies tú
mismo sin esa confirmación si no eres quien la verificó.)
