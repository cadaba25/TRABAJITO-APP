# Contexto compartido entre agentes

Ningún agente debe depender de recordar una conversación anterior para saber
el estado del proyecto — cada sesión de Claude Code puede ser nueva. Esta
carpeta existe para que el estado real quede escrito, no en memoria.

## `repo-snapshot.md`

Es el resumen corto (no una copia de `docs/architecture.md`, que es más
narrativo) de "qué existe hoy, en 30 segundos de lectura". Cualquier agente
lo lee primero, antes de leer nada más.

**Se actualiza cuando la realidad cambia de forma visible** — se conectó
Flutter a un endpoint, se agregó una migración, se rompió/arregló el build,
etc. Lo actualiza el agente que causó el cambio, como parte de cerrar su
tarea (no es trabajo aparte de `docs-agent`, aunque `docs-agent` audita
periódicamente que siga siendo verdad).

Si `repo-snapshot.md` contradice lo que ves en el código, **confía en el
código** y corrige el snapshot — no al revés.
