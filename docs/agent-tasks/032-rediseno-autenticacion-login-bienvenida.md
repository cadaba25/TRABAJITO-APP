---
id: 032
titulo: "Rediseño visual — autenticación: login y bienvenida (ADR-0016)"
estado: todo
agente: "flutter-agent"
creada: 2026-09-11
rama: "feature/rediseno-autenticacion"   # sobre feature/rediseno-fundamentos (031)
---

## Objetivo

Aplicar los tokens de tipografía/espaciado de la tarea 031 a las dos
pantallas más pequeñas y de menor riesgo de `autenticacion`: `login_screen.dart`
(278 líneas) y `bienvenida_registro_screen.dart` (239 líneas). Sirven de
piloto: si el patrón de migración (reemplazar `TextStyle`/`SizedBox` literales
por los tokens) funciona bien aquí, las tareas siguientes lo repiten sin
reabrir preguntas de diseño.

**Depende de la 031 (`hecho` o `en-revision`) — no empezar antes.**

## Contexto relevante

- `docs/decisions.md` → ADR-0016 (alcance completo) y ADR-0015 (movimiento,
  no se toca).
- Reporte de la tarea 031 (`docs/agent-reports/031-*.md`) — ahí están los
  nombres finales de los roles de tipografía/espaciado/radio a usar.

## Qué NO es esta tarea

- No toca `registro_trabajador_screen.dart` ni `registro_empleador_screen.dart`
  (tarea 033, aparte por tamaño y complejidad).
- No cambia ningún flujo, validación ni llamada a `AuthService`/`PerfilService`.
- No añade ni quita animaciones fuera de lo que ya trae ADR-0015/tarea 028.

## Qué hacer

1. Reemplaza los `TextStyle(fontSize: ..., fontWeight: ...)` literales de
   ambas pantallas por los roles de `AppTipografia`.
2. Reemplaza los `SizedBox`/`EdgeInsets` de valores sueltos por
   `AppEspaciado`.
3. Unifica los radios de borde a los roles definidos en la 031.
4. Si alguna pantalla queda con una jerarquía visual distinta a la otra para
   el mismo tipo de elemento (p. ej. el título de bienvenida vs. el título de
   login), decide un tratamiento consistente entre ambas — es la primera
   comprobación real de que el type scale cubre los casos reales.
5. Verifica que el tema oscuro se vea bien en las dos (la app tiene toggle de
   tema, `notificadorTema`).

## Criterios de aceptación

- [ ] Ambos archivos usan los tokens de la 031; no queda ningún `TextStyle`
      con tamaño/peso literal fuera de un caso justificado y anotado en el
      reporte.
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde
      (`login_screen_test.dart` y los que monten estas pantallas).
- [ ] Capturas antes/después (claro y oscuro) de ambas pantallas.
- [ ] Reporte en `docs/agent-reports/032-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
