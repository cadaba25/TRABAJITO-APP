---
id: 037
titulo: "Rediseño visual — perfil e inicio (ADR-0016)"
estado: todo
agente: "flutter-agent"
creada: 2026-09-11
rama: "feature/rediseno-perfil-inicio"   # sobre feature/rediseno-postulaciones (036)
---

## Objetivo

Aplicar los tokens de la tarea 031 al resto de pantallas que quedan:
`perfil_tab.dart` (197), `editar_perfil_screen.dart` (211),
`configuracion_screen.dart` (245), `detalle_trabajador_screen.dart` (163),
`trabajadores_tab.dart` (268), `ranking_tab.dart` (283),
`inicio_screen.dart` (218, el shell del `BottomNav`), y los widgets de
`perfil/pantallas/widgets/` (`accesos_rapidos_perfil`,
`aviso_perfil_no_disponible`, `avisos_perfil`, `cabecera_perfil`,
`formulario_editar_perfil`, `info_personal_perfil`, `piezas_perfil`).

Con esta tarea se cierra la cobertura de `lib/funcionalidades/**` completa
(excepto los 4 archivos de `lib/screens/` explícitamente fuera de alcance).

**Depende de la 031. Puede ir en paralelo a 034/035/036.**

## Contexto relevante

- ADR-0016. Reporte de la 031.
- ADR-0015: el cambio de pestaña del `BottomNav` está en la lista cerrada de
  "dónde NO hay movimiento nuevo" — no lo animes al tocar `inicio_screen.dart`.

## Qué NO es esta tarea

- No cambia qué se puede editar del perfil ni las reglas de `ReglasCuenta`.
- No toca `datosSinConfirmar`/`cvCargado` ni la lógica de ADR-0013.
- No añade sondeo ni cambia cuándo se recarga cada pestaña.

## Criterios de aceptación

- [ ] Los archivos listados usan los tokens de la 031.
- [ ] El aviso de "datos sin confirmar" (`PerfilTab`) y la tarjeta de "CV sin
      cargar" siguen siendo visualmente distinguibles como advertencia tras
      el cambio de paleta — verifícalo explícitamente, es un caso de
      contraste real, no cosmético.
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde
      (`perfil_tab_test.dart`, `editar_perfil_screen_test.dart`, y los de
      widgets extraídos).
- [ ] Capturas antes/después de las 5 pestañas del `BottomNav`, claro y
      oscuro.
- [ ] Reporte en `docs/agent-reports/037-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
