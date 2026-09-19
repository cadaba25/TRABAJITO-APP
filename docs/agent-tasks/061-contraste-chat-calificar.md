---
tarea: 061-contraste-chat-calificar
agente: flutter-agent
estado: en-revision
---

# 061 - Contraste dorado en chat y "Calificar"

Solo capa visual, sin servicios ni backend. Cuatro hallazgos del emulador:

1. Boton "Calificar al trabajador": texto blanco sobre dorado.
2. Burbuja de mensaje propio: texto blanco sobre dorado.
3. Titulo del trabajo en la lista de chats: dorado sobre blanco.
4. Botones "Contraproponer"/"Proponer": dorado sobre fondo palido.

Reglas: reutilizar `colorAcentoTexto` y `AppColores.principal`; sin colores
nuevos ni dependencias. Barrido de la misma familia en chat, calificaciones
y trabajos. Tests de contraste >= 4.5:1 en ambos temas.
