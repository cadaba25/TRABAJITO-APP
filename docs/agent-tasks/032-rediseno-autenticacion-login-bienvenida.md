---
id: 032
titulo: "Rediseño visual — autenticación: login y bienvenida (ADR-0016)"
estado: hecho
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

- [x] Ambos archivos usan los tokens de la 031; no queda ningún `TextStyle`
      con tamaño/peso literal fuera de un caso justificado y anotado en el
      reporte.
- [x] `flutter analyze` sin errores nuevos; `flutter test` verde
      (`login_screen_test.dart` y los que monten estas pantallas).
- [x] Capturas antes/después (claro y oscuro) de ambas pantallas.
- [x] Reporte en `docs/agent-reports/032-*.md`.

## Notas del agente que la ejecuta

- Criterio de consistencia (punto 4 del "Qué hacer"): el renglón "hero" de
  ambas pantallas usa `tituloGrande` (28/w800) y el renglón de apoyo usa
  `titulo` (22/w700). En `login_screen` el único título ("Bienvenido a
  Trabajito") pasa de `headlineSmall` recompuesto a mano a `tituloGrande`
  directo; en `bienvenida_registro_screen` "¡Hola!" pasa a `tituloGrande` y
  "¿Qué te trae a Trabajito?" a `titulo` — antes eran 28/w900 y 22/w800
  sueltos, ahora exactamente los pesos de los roles (w800/w700).
- Casos con literal fuera de un rol, justificados en el reporte
  (`docs/agent-reports/032-*.md`): `EdgeInsets.all(20)` → `AppEspaciado.lg`
  (16, el 20 no cae exacto en la escala), `BorderRadius.circular(10)` de la
  insignia de icono → `AppRadios.campo` (12), y el badge "Pronto"
  (`BorderRadius.circular(4)`, no alcanzable desde la UI hoy) que se deja
  literal con el mismo criterio que el checkbox de `AppTema` en la 031.
- No se tocó ningún color role de `colores_por_tema.dart`
  (`colorSuperficieAlterna`/`colorDeshabilitado`) — fuera de alcance
  explícito de esta tarea (solo tipografía/espaciado/radios), aunque el
  reporte de 031 los señalaba en este mismo archivo. Sí se limpiaron los 2
  `withOpacity` deprecados de `bienvenida_registro_screen.dart` a
  `withValues(alpha:)` por tocar esas líneas de todos modos.
- **Incidente de emulador (reportado en detalle en el reporte de tarea):**
  había una sesión ajena corriendo en `emulator-5554` (usuario "Mario
  Kempes", `InicioScreen`). Para no interferir, levanté un emulador nuevo
  propio (`Pixel_9` → `emulator-5556`) para las capturas y nunca instalé
  nada sobre el `emulator-5554` ajeno. Aun así, en algún punto (probable
  contención de recursos al correr dos emuladores Android a la vez) ese
  emulador se cayó solo. Lo reinicié (era el AVD `Pixel_6`) y la sesión de
  Mario Kempes volvió a autenticarse sola (token persistido) con el feed
  cargando datos reales — no se perdió la cuenta ni sus datos, pero si
  estaba en medio de navegar a una pantalla específica o con un formulario
  a medio llenar, eso sí se perdió (vive solo en memoria). Ver reporte para
  el detalle completo.
