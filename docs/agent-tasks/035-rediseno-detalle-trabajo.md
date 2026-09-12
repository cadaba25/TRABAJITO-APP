---
id: 035
titulo: "Rediseño visual — detalle_trabajo_screen.dart (ADR-0016)"
estado: todo
agente: "flutter-agent"
creada: 2026-09-11
rama: "feature/rediseno-detalle-trabajo"   # sobre feature/rediseno-trabajos (034)
---

## Objetivo

Aplicar los tokens de la tarea 031 a `detalle_trabajo_screen.dart`
(1 150 líneas — el archivo Dart más grande del proyecto). Tarea aparte de la
034 por su tamaño y porque ADR-0014 ya lo señaló como "una sola clase `State`:
~15 métodos `_widget()`, 6 `AlertDialog` inline, y la máquina de estados del
negocio duplicada en el cliente", dejado a propósito para cuando se migre el
chat (`_reservarPago` todavía lee el acuerdo de pago del chat de Firestore).

**Depende de la 034 (para no chocar si ambas tocan `AppColores`/tokens
compartidos a la vez). No depende de que el chat se migre.**

## Contexto relevante

- ADR-0014, sección 2 de "Contexto" (por qué este archivo está donde está) y
  "Cómo se aplica" (por qué se dejó para la migración del chat).
- ADR-0016, decisión 5 (el techo de 300 sigue vigente; aquí aplica con más
  fuerza que en ningún otro archivo).
- `docs/agent-context/RETOMAR-AQUI.md` — la costura `_reservarPago` con el
  chat de Firestore: no la toques, no es esta tarea.

## Juicio que le toca a quien ejecute esta tarea (documéntalo, no lo evadas)

Este archivo es el candidato más claro para partirse, y esta tarea lo va a
abrir de todas formas para aplicar tokens visuales. La postura de ADR-0016 es
**no forzar** el refactor completo (la máquina de estados y `_reservarPago`
son alcance de la migración del chat, no de un rediseño visual), pero:

- **Los 6 `AlertDialog` inline sí deben salir a sus propios archivos** en
  `pantallas/widgets/` (mismo patrón que el resto de la app desde la 027
  B-2b) — es un cambio de organización de código de bajo riesgo que además
  reduce el archivo de forma real mientras aplicas tokens a cada diálogo.
- **No toques la lógica de la máquina de estados ni las llamadas a
  `PublicacionService`** más allá de mover código literal (extraer un
  `AlertDialog` a un widget que recibe callbacks, sin cambiar qué hace cada
  callback).
- Si tras extraer los diálogos el archivo sigue sobre 300 (es probable — solo
  los diálogos no lo resuelven del todo), **queda como excepción viva
  documentada**, igual que `gestor_sesion.dart` — no es aceptable dejarlo sin
  anotar por qué.

## Qué NO es esta tarea

- No migra el chat ni toca Firestore.
- No cambia la máquina de estados de negocio ni ningún endpoint consumido.
- No resuelve la costura `_reservarPago`.

## Criterios de aceptación

- [ ] Tokens de la 031 aplicados en toda la pantalla y en los diálogos
      extraídos.
- [ ] Los 6 `AlertDialog` viven en `pantallas/widgets/`, cada uno con su
      propio archivo.
- [ ] Decisión sobre el tamaño final del archivo, documentada explícitamente
      en el reporte (partido del todo / parcialmente / excepción viva y por
      qué).
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde.
- [ ] Recorrido manual o con test de los estados visibles del trabajo (activo,
      asignado, en progreso, esperando confirmación, en disputa, completado)
      con capturas.
- [ ] Reporte en `docs/agent-reports/035-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
