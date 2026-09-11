---
id: 029
titulo: "Tests de pantalla para trabajos_tab, mis_publicaciones_screen y postulantes_screen"
estado: todo
agente: "qa-agent"
creada: 2026-09-10
rama: ""
---

## Objetivo

Hallazgo de `qa-agent` en la revisión de la tarea 027 B-2b: `trabajos_tab`,
`mis_publicaciones_screen` y `postulantes_screen` **nunca tuvieron test de
pantalla** (a diferencia de `perfil_tab`/`editar_perfil_screen`, que sí los
tienen desde la tarea 022/023). Eso deja sin cobertura transitiva a las
piezas que B-2b extrajo de ellas: `barra_busqueda_trabajos.dart`,
`hoja_filtros_trabajos.dart`, `toggle_feed_trabajos.dart`,
`encabezado_feed.dart`, `estados_mis_publicaciones.dart`,
`estados_postulantes.dart`, `cabecera_postulantes.dart`.

No es una regresión de B-2b (el hueco es preexistente), pero ahora que las
piezas están separadas es mucho más barato probarlas. Prioridad: media — no
bloquea nada, pero es la puerta que ADR-0014 abrió y todavía no se cruzó del
todo.

## Contexto relevante

- `docs/agent-reports/027b2b-partir-archivos.md` — sección "Revisión antes
  del PR", nota de `qa-agent`.
- Patrón a seguir: `test/funcionalidades/perfil/perfil_tab_test.dart` y
  `test/funcionalidades/perfil/editar_perfil_screen_test.dart` (inyectan
  `ApiClient.fijarInstancia()` + servicios falsos vía `provider`).

## Criterios de aceptación

- [ ] `trabajos_tab_test.dart`: primera carga, paginar (`_cargarMas`),
      alternar Trabajos/Mis publicaciones, aplicar/limpiar filtros desde la
      hoja, buscar por texto, estado de error con "deslizar para
      reintentar", estado vacío distinto para empleador/trabajador.
- [ ] `mis_publicaciones_screen_test.dart`: lista, estado de error, estado
      vacío.
- [ ] `postulantes_screen_test.dart`: lista con badges de estado, aceptar un
      postulante, estado de error, estado vacío.
- [ ] Ninguno abre socket real ni toca `flutter_secure_storage`.
- [ ] `flutter analyze` no sube de la línea base; `flutter test` sube desde
      la línea base de cuando se tome esta tarea.
- [ ] Reporte en `docs/agent-reports/029-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
