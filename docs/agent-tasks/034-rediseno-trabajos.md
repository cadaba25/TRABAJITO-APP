---
id: 034
titulo: "Rediseño visual — trabajos: feed, mis publicaciones, publicar/editar (ADR-0016)"
estado: todo
agente: "flutter-agent"
creada: 2026-09-11
rama: "feature/rediseno-trabajos"   # sobre feature/rediseno-registros (033)
---

## Objetivo

Aplicar los tokens de la tarea 031 a la funcionalidad `trabajos`, salvo
`detalle_trabajo_screen.dart` (tarea 035 aparte, por tamaño). Cubre:
`trabajos_tab.dart` (297), `mis_publicaciones_screen.dart` (217),
`publicar_trabajo_screen.dart` (263), `editar_trabajo_screen.dart` (205), y
los widgets extraídos en `pantallas/widgets/` (`tarjeta_trabajo.dart`,
`tarjeta_mi_publicacion.dart`, `barra_busqueda_trabajos.dart`,
`hoja_filtros_trabajos.dart`, `toggle_feed_trabajos.dart`,
`encabezado_feed.dart`, `estados_feed.dart`, `estados_mis_publicaciones.dart`,
`fila_feed.dart`, `entrada_escalonada.dart`).

**Depende de la 031. No depende de 032/033** (funcionalidad distinta) — puede
ir en paralelo si hace falta, pero **sí conviene mergear 031 primero** para no
duplicar la definición de tokens. Se numera después de 033 por orden lógico
de features, no por dependencia real.

## Contexto relevante

- ADR-0016. Reporte de la 031 para los nombres de tokens.
- `docs/agent-reports/027b2b-partir-archivos.md` — cómo quedó repartida esta
  funcionalidad; no rehagas esa partición, solo aplica tokens visuales sobre
  ella.

## Qué NO es esta tarea

- No toca `detalle_trabajo_screen.dart` (tarea 035).
- No cambia el contrato con `PublicacionService` ni la paginación
  (`pagina`/`tamano` — ver regla de oro 3 de `CLAUDE.md`, no la confundas con
  nada de esto).
- No añade animación nueva fuera de la lista cerrada de ADR-0015 (el stagger
  de la primera carga y el flip de color de los chips de filtro ya existen —
  no los dupliques ni los "mejores" aquí).

## Qué hacer

1. Reemplaza `TextStyle`/`SizedBox`/`EdgeInsets`/`BorderRadius.circular`
   literales por los tokens de la 031 en los 14 archivos listados arriba.
2. Presta atención especial a `tarjeta_trabajo.dart` y
   `tarjeta_mi_publicacion.dart`: son los componentes más repetidos y más
   vistos de toda la app (el feed se ve decenas de veces al día) — la
   consistencia aquí es la que más se nota.
3. Verifica que el color de precio/presupuesto (hoy `AppColores.acento` en
   texto sobre fondo blanco/superficie — no el caso de contraste roto de la
   031, que era fondo dorado) siga siendo legible tras cualquier ajuste de
   paleta que haya salido de la 031.

## Criterios de aceptación

- [ ] Los 14 archivos usan los tokens de la 031; ninguno pasa de 300 líneas
      como consecuencia de este cambio (si alguno ya estaba cerca, anótalo).
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde, incluidos
      los tests de widget de `tarjeta_trabajo`/`tarjeta_mi_publicacion`
      (`test/funcionalidades/trabajos/widgets/`) — si sus aserciones
      dependían de un valor visual concreto que cambió, actualízalas y
      anótalo, no las borres.
- [ ] Capturas antes/después del feed y de "mis publicaciones" (claro y
      oscuro, con y sin resultados).
- [ ] Reporte en `docs/agent-reports/034-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
