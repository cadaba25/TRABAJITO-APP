---
id: 033
titulo: "Rediseño visual — autenticación: registro de trabajador y de empleador (ADR-0016)"
estado: hecho
agente: "flutter-agent"
creada: 2026-09-11
completada: 2026-09-11
rama: "feature/rediseno-registros"   # sobre feature/rediseno-autenticacion (032)
---

## Objetivo

Aplicar los tokens de la tarea 031 a `registro_trabajador_screen.dart`
(1 042 líneas, 5 pasos) y `registro_empleador_screen.dart` (920 líneas). Son
las dos excepciones vivas al techo de 300 líneas de ADR-0014, dejadas a
propósito para la tarea 012 (doble rol, **en pausa por decisión del dueño,
sin fecha**). Esta tarea NO espera a la 012.

**Depende de la 032 (`hecho` o `en-revision`).**

## Contexto relevante

- ADR-0016 (decisión 5: el techo de 300 líneas de ADR-0014 sigue vigente sin
  excepción nueva — si tocar estas pantallas las deja igual de grandes o
  peor, hay que decidir si se parten).
- ADR-0014, sección "Cómo se aplica" — documenta por qué estos dos archivos
  quedaron sin partir en la 027, y a qué tarea futura los dejó.
- `docs/agent-tasks/012-doble-perfil-trabajador-contratista.md` — sigue
  `todo`, sin fecha. No la esperes.

## Juicio que le toca a quien ejecute esta tarea (documéntalo, no lo evadas)

Al aplicar los tokens vas a tocar la mayoría de líneas de estos dos archivos
de todas formas. Evalúa en ese momento:

- Si extraer cada paso del formulario a su propio widget (mismo patrón que
  usó la 027 B-2b con `trabajos_tab`/`postulantes_screen`) es un cambio
  natural dado que ya estás tocando esas líneas → hazlo, y el archivo baja de
  300.
- Si el estado compartido entre pasos (validaciones cruzadas, controllers)
  hace que partirlo sea un refactor de comportamiento y no solo de
  presentación → **no lo fuerces aquí**. Aplica los tokens dejando la
  estructura de archivo como está, y anota en el reporte por qué, igual que
  ADR-0014 anotó `gestor_sesion.dart` y `publicacion_service.dart` como
  excepciones justificadas. No es aceptable dejarlo sin decidir ni sin
  documentar.

## Qué NO es esta tarea

- No es la tarea 012 (doble rol). No cambies qué campos se piden, qué rol se
  puede elegir, ni el orden de los pasos.
- No cambia ninguna validación (`ReglasCuenta`, edad mínima, etc.).
- No toca `PerfilService`/`AuthService` ni sus contratos.

## Criterios de aceptación

- [x] Los dos archivos usan los tokens de la 031 (`AppTipografia`,
      `AppEspaciado`, `AppRadios`).
- [x] Se documenta explícitamente la decisión sobre partir o no partir cada
      archivo (ver sección de juicio arriba) — no puede quedar implícita.
      **Decisión: SÍ se partió, en los dos casos, con un matiz** — ver el
      reporte para el detalle completo (`docs/agent-reports/033-*.md`).
- [x] `flutter analyze` sin errores nuevos (bajó de 33 a 19 issues: se limpió
      de paso lo que ya tenían estos dos archivos); `flutter test` verde
      (253/253, mismo total que antes — incluido
      `registro_empleador_screen_test.dart`, sus 4 casos siguen pasando sin
      tocar sus aserciones). No existe test del registro de trabajador; sigue
      sin ser alcance de esta tarea crearlo (tarea 029 de `qa-agent`).
- [x] Los 5 pasos del registro de trabajador y los 3 del de empleador se
      probaron con test de widget (no en el emulador — había una sesión ajena
      viva, ver el reporte). Capturas de los 8 pasos en claro y oscuro (16
      PNG) en `docs/agent-reports/capturas/033-*.png`.
- [x] Reporte en `docs/agent-reports/033-rediseno-autenticacion-registros.md`.

## Notas del agente que la ejecuta

**Resumen de la decisión de partir-o-no-partir (ver el reporte para el
detalle completo con líneas exactas):**

Los 5/3 pasos de cada formulario SÍ se extrajeron a sus propios widgets
(`pantallas/widgets/registro_trabajador/paso_*.dart` y
`.../registro_empleador/paso_*.dart`, más 6 widgets compartidos entre ambos
registros en `.../widgets/registro/` que antes estaban duplicados byte a
byte) — es exactamente el patrón de la 027 B-2b, y era un cambio natural
dado que aplicar los tokens tocaba de todas formas casi cada línea de esos
métodos `_pasoN()`.

Eso solo no bastó para bajar de 300: la lógica de avanzar/validar/guardar
(`_avanzarPasoN`, `_finalizarRegistro`, `_esMayor18`) SÍ depende de sí misma
entre pasos (edad mínima antes de guardar, orden de llamadas a
`PerfilService`, ramas persona/empresa) y por eso NO se movió a los widgets
sin estado — exactamente el criterio que pedía la tarea. Para bajar del
techo sin forzar ese refactor de comportamiento, esa lógica se movió a un
archivo `part of` (`registro_trabajador_logica.dart` /
`registro_empleador_logica.dart`): comparte biblioteca con la pantalla, así
que conserva acceso completo a los campos privados del `State` sin exponer
nada nuevo. Es una técnica distinta a la de la 027 B-2b (que no la necesitó
porque sus pantallas no tenían tanta lógica de avanzar por paso) y se
documenta como tal en el reporte.

Resultado: `registro_trabajador_screen.dart` 1 042→**231** líneas (+**200**
en el `part`), `registro_empleador_screen.dart` 920→**200** líneas (+**181**
en el `part`). Los 15 widgets nuevos, todos ≤170 líneas.

**Incidente de emulador evitado, no repetido:** había una sesión ajena viva
en el único emulador disponible (`emulator-5554`) en el momento de verificar.
Siguiendo la instrucción explícita de esta tarea y la de `flutter-agent.md`,
no se instaló nada encima ni se levantó un segundo emulador (evitando el
incidente de la tarea 032). La verificación de los 8 pasos en claro/oscuro
se hizo con un test de widget que renderiza cada paso aislado y guarda un
PNG real (`test/manual/generar_capturas_registro.dart`, no se ejecuta en la
suite normal — no termina en `_test.dart`). No se tocó el emulador en ningún
momento de esta tarea.
