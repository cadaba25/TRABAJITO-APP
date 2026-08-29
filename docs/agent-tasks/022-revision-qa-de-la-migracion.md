---
id: 022
titulo: "Revisión de QA de todo lo migrado, antes de seguir con la fase 2b"
estado: en-progreso
agente: "qa-agent"
creada: 2026-08-29
rama: "qa/revision-migracion"
---

## Por qué existe

Encargo del dueño del proyecto: *"no quiero ir dejando bugs atrás sin
resolver y que después se nos olviden"*. Antes de migrar los 5 servicios que
faltan (fase 2b), hay que revisar lo que ya se construyó.

Se ha hecho mucho en pocos días y **nada de la parte Flutter ha pasado por
una revisión independiente**. Concretamente:

- **Tarea 018** (capa HTTP, `ApiClient`) y **tarea 020** (auth contra el
  backend): el propio `flutter-agent` las dejó marcadas como **pendientes de
  revisión de `security-agent`**. Nadie las ha mirado con ojos ajenos.
- **Tarea 019** (perfil completo): tocó la privacidad de los datos —
  `UsuarioResponse` pasó a tener vista de dueño y vista pública. El
  `backend-agent` pidió explícitamente que lo revisara `security-agent`.
- El `tech-lead` arregló a mano dos fallos del build (fuente Sora empaquetada
  y `compileSdk`) sin que nadie los revisara.

## Ámbito de la revisión

Lo migrado, no todo el proyecto. En orden de importancia:

1. **`lib/services/api/`** — el `ApiClient`, la renovación de token con sus
   dos candados, el manejo de errores, el almacén seguro. Es el cimiento de
   todo lo que venga después: un fallo aquí se multiplica por 6 servicios.
2. **`lib/services/auth_service.dart` y `lib/services/sesion_usuario.dart`** —
   el estado de sesión que sustituyó a `authStateChanges()` de Firebase.
3. **Las pantallas adaptadas** en la tarea 020 (login, los dos registros,
   editar perfil, configuración, inicio, las dos pestañas de personas).
4. **La privacidad del perfil** (backend, tarea 019): que un tercero no vea
   saldo, DNI, teléfonos ni fecha de nacimiento. Ya lo verificó el
   `tech-lead` por API, pero conviene mirar el código.

## Puntos calientes concretos (no empieces a ciegas)

Estos son los sitios donde ya se sabe que hay riesgo:

- **El CV se puede borrar sin querer.** `habilidades`, `experiencia` y
  `estudios` llegan `null` en login y registro (`null` = "no viene", no "no
  tiene"). El `flutter-agent` puso tres barreras. **Compruébalas de verdad**:
  es el fallo más caro que podría quedar vivo, porque destruye datos del
  usuario en silencio.
- **La renovación de token.** Dos refrescos a la vez con el mismo token hacen
  que el backend revoque **toda la familia** y el usuario quede fuera. Hay
  dos candados y tests con un backend falso. Intenta romperlo.
- **Pantallas que ya no pueden dar por hecho lo de antes**: el perfil ajeno
  ahora trae `null` en varios campos. ¿Alguna pantalla revienta con eso?
- **429 del login** (freno de fuerza bruta): ¿se muestra un mensaje
  entendible o un error genérico?
- **La app está mixta**: auth contra el backend, los otros 5 servicios contra
  Firestore. Documentado y esperado — **no lo reportes como bug**, pero mira
  si produce estados raros en pantalla (por ejemplo, una pantalla que se
  queda cargando para siempre en vez de decir que no hay datos).

## Puedes probar en un dispositivo de verdad

**Usa el emulador `Pixel_6` (Android 13), NO el `Pixel_9`** (Android 17
preview: va lentísimo y provoca bloqueos que no son de la app).

```bash
flutter emulators --launch Pixel_6
flutter run -d emulator-5554 --dart-define=TRABAJITO_API_URL=http://10.0.2.2:8080
```

El backend corre en la VM (ver `docs/development.md`). Cuenta ya creada:
`demo@trabajito.com` / `DemoTrabajito2026`.

**El caso que más falta por probar**, y que el dueño querría ver cubierto:
registrarse desde la app rellenando los 5 pasos (habilidades, experiencia,
estudios), cerrar sesión, volver a entrar y comprobar que **el CV sigue
completo**. Y después editar el perfil y comprobar que **tampoco lo borra**.

## Qué hacer con lo que encuentres

El dueño pidió que se arregle, no solo que se diagnostique:

- **Arregla** lo que sea claro y esté dentro del ámbito de arriba.
- Si algo es grande o cambia una decisión de producto, **no lo arregles**:
  créale tarea y dilo en el reporte.
- Cada arreglo con su test, para que no vuelva.

## Criterios de aceptación

- [ ] Revisados los cuatro puntos del ámbito.
- [ ] Los puntos calientes probados de verdad, no leídos por encima.
- [ ] Cada fallo encontrado: qué es, cómo reproducirlo, y arreglado o con
      tarea abierta.
- [ ] `flutter analyze` sin errores nuevos; `flutter test` pasa (hoy **135**).
- [ ] Backend intacto: `mvn test` sigue en **103** y el script de regresión en
      **207 OK / 0 inesperados**, si tocas algo de ahí.
- [ ] Si NO encuentras nada, dilo claramente: "revisado X, sin hallazgos" es
      un resultado válido y útil. No inventes hallazgos para justificar la
      tarea.

## Fuera de alcance

- La fase 2b (migrar los otros 5 servicios): va después de esto.
- Los 5 servicios que siguen en Firestore: no los revises, se van a reescribir.
- Rediseñar la interfaz.

## Notas del agente que la ejecuta

(vacío — en progreso)
