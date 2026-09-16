---
id: 033
titulo: "Rediseño visual — autenticación: registro de trabajador y de empleador (ADR-0016)"
estado: todo
agente: "flutter-agent"
creada: 2026-09-11
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

- [ ] Los dos archivos usan los tokens de la 031.
- [ ] Se documenta explícitamente la decisión sobre partir o no partir cada
      archivo (ver sección de juicio arriba) — no puede quedar implícita.
- [ ] `flutter analyze` sin errores nuevos; `flutter test` verde (incluido
      `registro_empleador_screen_test.dart`; si no existe test del registro
      de trabajador, no es alcance de esta tarea crearlo — ver tarea 029 de
      `qa-agent` para cobertura pendiente).
- [ ] Los 5 pasos del registro de trabajador y los 3 del de empleador se
      probaron manualmente o con test de widget tras el cambio (capturas de
      cada paso, claro y oscuro).
- [ ] Reporte en `docs/agent-reports/033-*.md`.

## Notas del agente que la ejecuta

(Se va llenando mientras se trabaja.)
