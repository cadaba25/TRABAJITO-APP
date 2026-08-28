---
id: 021
titulo: "Probar el flujo real app ↔ backend en un dispositivo (bloqueante para la demo)"
estado: todo
agente: ""
creada: 2026-08-28
rama: ""
---

## Por qué existe

El 2026-08-28 la app se ejecutó **por primera vez** desde que empezó la
migración (ADR-0009). Se arreglaron dos fallos que impedían siquiera
arrancarla (ver `docs/agent-reports/` y el commit de la fuente Sora), y la
pantalla de login **renderiza correctamente** con la marca y la tipografía.

**Pero el flujo de punta a punta app → backend NO está probado.** El
`tech-lead` intentó automatizarlo con `adb`, y no fue posible de forma fiable:

- El emulador (Pixel_9, Android 17, x86_64) es tan lento que el primer
  arranque provoca un ANR ("trabajito isn't responding"). Tras un reinicio
  limpio la app sí carga bien, así que **es lentitud del emulador, no un bug
  de la app** — pero vuelve a bloquearse al interactuar por script.
- La escritura de texto con `adb shell input text` no llegó a los campos: la
  pantalla mostró "Este campo es obligatorio" con los campos vacíos.
- Se comprobó en los logs del backend: **no llegó ninguna petición**. La app
  fue directa al login (no había sesión guardada) y el intento de login nunca
  salió porque el formulario estaba vacío.

Es decir: **nadie ha visto todavía a la app hablar con el backend**. Todo lo
demás está verificado (el backend responde, el `ApiClient` está probado con
tests contra respuestas copiadas del servidor real), pero el último cable no
se ha visto conducir.

## Qué hay que hacer

Una persona, a mano, en un emulador o un teléfono:

1. Levantar el backend y reenviar el puerto 8080 (ver
   `docs/development.md` → "Apuntar la app al backend").
2. `flutter run --dart-define=TRABAJITO_API_URL=http://10.0.2.2:8080`
   (emulador) o con la IP del PC si es un teléfono físico.
3. **Registrarse** desde la app con una cuenta nueva. Comprobar en el
   servidor que el usuario existe:
   `docker compose exec -T db psql -U trabajito -d trabajito -c "SELECT correo, rol FROM usuarios ORDER BY creado_en DESC LIMIT 3;"`
4. **Cerrar sesión y volver a entrar.** Comprobar que el perfil sigue
   completo (habilidades, experiencia, estudios) — este es el caso que más
   riesgo tiene, por el aviso de `null` vs. lista vacía de la tarea 020.
5. Editar el perfil y comprobar que **no se borra el CV**.
6. Provocar un error a propósito (contraseña mala) y ver que el mensaje sale
   en español y entendible.

Hay una cuenta de prueba ya creada en el servidor:
`demo@trabajito.com` / `DemoTrabajito2026`.

## Riesgos concretos a vigilar

- **`flutter_secure_storage` nunca se ha ejecutado de verdad** hasta ahora, y
  es por donde pasa el token de sesión. En el emulador se le vio inicializar
  (aparece en logcat), pero no se ha comprobado que guarde y recupere.
- La app está **mixta**: auth contra el backend, los otros 5 servicios contra
  Firestore. Una cuenta creada contra el backend **no encuentra datos** en las
  pantallas no migradas, porque su `uid` no existe en Firestore. Es esperado
  (lo documentó la tarea 020), pero desconcierta si no se sabe.
- Si el emulador va muy lento, probar en un **teléfono físico**: será mucho
  más representativo de lo que verán los inversionistas.

## Por qué bloquea la demo

Enseñar la app a socios e inversionistas sin haber visto nunca el flujo
completo funcionando es un riesgo innecesario. Esto se resuelve en una
sesión corta con el emulador ya montado.
