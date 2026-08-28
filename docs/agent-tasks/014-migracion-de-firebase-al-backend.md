---
id: 014
titulo: "Migración: sacar la app de Firebase y ponerla contra el backend propio"
estado: todo
agente: ""   # épica: se ejecuta por fases, cada una con su tarea hija
creada: 2026-08-26
rama: ""
---

## Objetivo

Ejecutar la decisión de **ADR-0009**: Trabajito deja de depender de Firebase
(Firestore **y** Authentication) y pasa a usar su propio backend Spring Boot
+ PostgreSQL.

**Esta ficha es la épica, no una tarea ejecutable.** Cada fase de abajo se
convierte en su propia tarea cuando llegue su turno.

## Lo que hace esta migración mucho más barata de lo normal

El dueño confirmó que **los datos de Firebase son de prueba y se descartan**.
Eso elimina de un plumazo lo más caro y arriesgado de una migración: no hay
exportación, ni reconciliación, ni ventana de mantenimiento, ni convivencia
de dos fuentes de verdad. Se corta y ya.

## Estado de partida (verificado)

| | |
|---|---|
| Flutter | 23 pantallas, 6 servicios, 7 modelos — **todos hablan Firestore directo** |
| `pubspec.yaml` | **no tiene ningún cliente HTTP** (`http`/`dio`): hay que añadirlo |
| Backend | 12 módulos, corriendo en el servidor, 77 tests, 155 checks de regresión en verde |
| Auth actual | `firebase_auth` envuelto en `lib/services/auth_service.dart` |
| Auth destino | JWT propio, ya probado (registro/login/`/api/auth/yo`) |

## Orden de fases (propuesto por el `tech-lead`)

El criterio del orden: **cerrar primero los contratos que, si cambian
después, obligan a reescribir el cliente dos veces.**

### Fase 0 — Cerrar el contrato de autenticación (ANTES de tocar Flutter)

1. **Refresh tokens.** Hoy el JWT dura 7 días y no se puede revocar. Es el
   pendiente más urgente: define el contrato de sesión que el cliente va a
   implementar. Hacerlo después significa reescribir el login de la app.
2. **Login exigente** — ver `docs/agent-tasks/015-login-exigente.md`
   (rate limiting, bloqueo por intentos, política de contraseñas).
3. **Decidir el modelo de roles** de la tarea 012 (doble perfil), porque
   afecta a qué lleva el token y a la forma de `usuarios`.

### Fase 1 — Cimientos del cliente

4. Añadir cliente HTTP a `pubspec.yaml` y crear una capa `ApiClient` única:
   URL base configurable, cabecera `Authorization`, manejo del formato de
   error estándar del backend (ADR-0008), renovación de token.
5. Almacenamiento seguro del token en el dispositivo (no en texto plano).
6. Adaptar los modelos: de `desdeFirestore()`/`aFirestore()` a
   `desdeJson()`/`aJson()`.

### Fase 2 — Migrar servicio por servicio

Un servicio por tarea, con sus tests. Orden sugerido, de menos a más riesgo:

| # | Servicio | Notas |
|---|---|---|
| 7 | `auth_service.dart` | el primero: todo lo demás necesita el token |
| 8 | `publicacion_service.dart` | feed y publicación de trabajos |
| 9 | `postulacion_service.dart` | |
| 10 | `calificacion_service.dart` | |
| 11 | `cartera_service.dart` | **dinero**: revisión obligatoria de `security-agent` |
| 12 | `chat_service.dart` | el más complejo: pasa de streams de Firestore a WebSocket/STOMP, que **nunca se ha probado** |

### Fase 3 — Cerrar

13. Pantallas nuevas que el backend ya soporta y la app no tiene: entregar
    con evidencias, reclamar a soporte, elegir cerrar/reabrir al cancelar,
    notificaciones, reportes.
14. Quitar `firebase_core`, `firebase_auth`, `cloud_firestore` de
    `pubspec.yaml`; borrar `firestore.rules`, `firestore.indexes.json` y
    `google-services.json`.
15. Cerrar la tarea 004 como "ya no aplica" (endurecer Firestore cuando
    Firestore ya no existe no tiene sentido).

### Fase 4 — Producción de verdad

16. Flyway/Liquibase **antes** de que esa base de datos guarde datos reales.
17. HTTPS + reverse proxy + dominio; backups de PostgreSQL.
18. CI que corra los tests en cada PR.
19. Pasarela de pago real (hoy la cartera es prototipo: cualquiera se recarga
    saldo sin pagar).

## Riesgos a vigilar

- **El chat es el punto más incierto.** Firestore da streams en tiempo real
  gratis; el backend usa WebSocket/STOMP que **no se ha probado nunca**, y
  además tiene un `TODO` de seguridad: no valida el JWT en la conexión del
  socket. Conviene probar el WebSocket **antes** de comprometerse con la
  fase 2.
- **Se pierde el modo offline** que Firestore daba de serie. Hay que decidir
  si importa para el caso de uso (trabajadores en la calle, con conexión
  intermitente) y, si importa, qué se hace.
- **El backend pasa a ser crítico.** Hoy, si se cae, no pasa nada porque
  nadie lo usa. Después, si se cae, la app no funciona. Eso obliga a mirar
  en serio los puntos de la fase 4.
- **La app queda a medias durante la migración.** Hay que decidir si se
  migra en una rama larga o si se puede tener una app que hable con los dos
  lados temporalmente (lo primero es más simple, dado que los datos son
  desechables).

## Fuera de alcance de esta ficha

No implementar. Esta épica existe para fijar el orden y que ninguna fase
empiece antes de la que la bloquea.
