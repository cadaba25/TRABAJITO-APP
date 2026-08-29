---
id: 021
titulo: "Probar el flujo real app ↔ backend en un dispositivo (bloqueante para la demo)"
estado: hecho
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

---

## VERIFICADO el 2026-08-29 — el flujo funciona

El dueño indicó que tenía un segundo emulador (**Pixel_6, Android 13**) mucho
más rápido que el `Pixel_9` (Android 17 preview) con el que se había
intentado. Con ese sí se pudo automatizar, y **el problema era el emulador,
no la app**: con Android 13 no hay ANR, la app arranca en segundos y responde
a la interacción con normalidad.

**Resultado, con capturas en el informe:**

| Paso | Resultado |
|---|---|
| La app arranca y renderiza el login | ✅ con la marca y la tipografía correctas |
| Escribir credenciales en el formulario | ✅ |
| `POST /api/auth/login` contra el backend | ✅ entra al feed |
| El nombre que muestra viene del backend | ✅ **"Hola, Carlos Demo"** — ese usuario solo existe en PostgreSQL, se creó por API y nunca estuvo en Firestore |
| Cerrar la app y volver a abrirla | ✅ **va directa al feed, sin pedir login otra vez** |

Ese último punto es el que cierra el riesgo que quedaba abierto desde la
tarea 018: **`flutter_secure_storage` guarda y recupera la sesión de verdad**.
Nunca se había ejecutado hasta ahora, y es por donde pasa el token. La cadena
completa (almacén seguro → `restaurarSesion()` → `GET /api/auth/yo` →
pantalla) funciona.

**Lo esperado que también se vio:** el feed dice "Aún no hay trabajos
publicados". Correcto: los trabajos siguen en Firestore (fase 2b pendiente) y
esta cuenta nació en el backend, así que no tiene datos allí. Es la
consecuencia de la app mixta que documentó la tarea 020, no un fallo.

**Sigue sin probarse:** registro completo de 5 pasos desde la app (con
habilidades, experiencia y estudios), y que editar el perfil no borre el CV.
Es el caso de más riesgo que queda; se puede hacer ya con este emulador.

**Nota para quien retome:** usar `Pixel_6`, no `Pixel_9`.
`flutter emulators --launch Pixel_6`.
