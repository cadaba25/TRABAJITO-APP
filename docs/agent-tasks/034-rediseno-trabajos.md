---
id: 034
titulo: "Rediseño visual — trabajos: feed, mis publicaciones, publicar/editar (ADR-0016)"
estado: hecho
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

- [x] Los 14 archivos usan los tokens de la 031; ninguno pasa de 300 líneas
      como consecuencia de este cambio (si alguno ya estaba cerca, anótalo).
      `trabajos_tab.dart` estaba en 297 antes de esta tarea y quedó en 299
      (el más cercano al techo de los 14; ver reporte).
- [x] `flutter analyze` sin errores nuevos (19 issues, 0 errores, idéntico a
      la línea base de la 033; ninguno en archivos tocados); `flutter test`
      verde (253/253, mismo total que antes de la tarea). Los tests de
      `tarjeta_trabajo`/`tarjeta_mi_publicacion` y el resto de
      `test/funcionalidades/trabajos/widgets/` **no necesitaron ningún
      cambio**: solo afirman sobre texto/callbacks, no sobre valores
      visuales concretos.
- [x] Capturas antes/después del feed y de "Mis publicaciones" (claro y
      oscuro, con y sin resultados) — 16 PNG en
      `docs/agent-reports/capturas/034-*.png`, generadas montando las
      pantallas reales con un backend falso (`test/manual/generar_capturas_trabajos.dart`),
      no un harness ni el emulador.
- [x] Reporte en `docs/agent-reports/034-rediseno-trabajos.md`.

## Notas del agente que la ejecuta

- El color de precio/presupuesto (`AppColores.acento` en texto, ver punto 3
  de "Qué hacer") **sí resultó tener un problema de contraste real** en modo
  claro (dorado sobre blanco/superficie ≈ 1.63:1, el mismo par numérico que
  arregló la 031, solo que con los roles de texto/fondo invertidos — el
  contraste WCAG es simétrico). El agente de la 034 lo dejó documentado sin
  corregir, por estar fuera del alcance que se le dio.

  **Corregido después, en la misma rama (2026-09-12), a petición explícita
  del dueño**, siguiendo exactamente el patrón de la 031: se añadió
  `AppColores.doradoTexto` (`#8B6914`, variante oscurecida del dorado, solo
  para usarse como texto — no es un color de marca nuevo) y el rol
  `colorPrecio(context)` en `colores_por_tema.dart` (dorado normal en
  oscuro, que ya pasaba; `doradoTexto` en claro, ~5.08:1). Aplicado en
  `tarjeta_trabajo.dart` y `tarjeta_mi_publicacion.dart`. Test nuevo en
  `test/nucleo/tema/colores_por_tema_test.dart` que calcula el contraste con
  la misma fórmula WCAG de `app_tema_test.dart` — roto a propósito
  (`colorPrecio` devolviendo `AppColores.acento` sin condición) y confirmado
  en rojo antes de restaurar el arreglo. `flutter analyze` 19/0, `flutter
  test` 254/254 (+1).
- Se aplicó el rol `AppTipografia.numero` (el que ADR-0016 documenta para
  "montos y precios") al precio de ambas tarjetas — es el único caso de todo
  el archivo donde el nombre del rol coincide literalmente con el uso.
- Emulador: no se tocó ninguno. Se generaron las capturas con
  `test/manual/generar_capturas_trabajos.dart`, montando `TrabajosTab`/
  `MisPublicacionesScreen` reales con `PublicacionService`/
  `PostulacionService` sobre un `MockClient` en memoria (mismo patrón que
  `trabajos_y_postulaciones_test.dart`), y comparando antes/después con
  `git stash` sobre los 12 archivos de `lib/` tocados (sin tocar el propio
  generador) — mismo patrón de verificación que usó la 033.
