---
tarea: 055-pulido-visual-demo
agente: flutter-agent (frontend visual)
estado: en-progreso
base: feature/barrido-contraste-dorado (051)
---

## Objetivo

Pulido visual para la demo a socios. Solo capa visual (widgets, tema, layout).

## Alcance

1. Hallazgos fuera de alcance de la 051: fondos dorados solidos con texto/icono blanco fijo
   (Badge de chats, FAB Publicar x2, camara de editar perfil) y `AppColores.dorado`
   como texto en `_badgeEstado` (detalle y tarjeta).
2. Estados vacio/carga/error y micro-interacciones sobrias en las pantallas del recorrido.
3. Sin dependencias nuevas.

## Fuera de alcance

`lib/services`, servicios de chat/cartera/calificacion, `backend/`, contratos de API.
