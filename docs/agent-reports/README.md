# Reportes de agentes

Al cerrar una tarea de `docs/agent-tasks/NNN-slug.md`, el agente que la
ejecutó crea `docs/agent-reports/NNN-slug.md` (mismo número y slug) con
`TEMPLATE.md` como base. Es el registro de lo que pasó de verdad, para que
el siguiente agente (o el `tech-lead`, o el usuario) no tenga que releer todo
el diff para saber qué se hizo, qué se decidió y qué quedó pendiente.

No se borra ni se sobreescribe un reporte viejo. Si una tarea se retoma más
adelante, se referencia el reporte anterior desde la tarea nueva.
