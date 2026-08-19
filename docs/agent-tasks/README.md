# Tareas de agentes

Una tarea = un archivo. Se crea **antes** de escribir código, normalmente por
`tech-lead` (o por el agente especializado si la tarea es chica y obvia,
avisando al `tech-lead` de todos modos si toca más de un módulo).

## Convención de nombres

`NNN-slug-descriptivo.md` — numeración secuencial, `NNN` con 3 dígitos.
Revisa el último número usado en esta carpeta antes de crear el siguiente.

## Estados

`todo` → `en-progreso` → `en-revision` → `hecho` (o `bloqueada` si algo
externo lo impide — documenta qué).

## Cuándo una tarea es "grande" y necesita plan del `tech-lead` primero

Si toca más de un módulo (ej. Flutter + backend), cambia un contrato de API
ya consumido, o cambia el modelo de datos — no se empieza a programar sin que
el archivo de tarea tenga, además de la plantilla base, una sección
"Módulos afectados y orden de trabajo" llenada por `tech-lead`.

Usa `TEMPLATE.md` como base para cada tarea nueva.
