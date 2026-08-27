---
id: 015
titulo: "Login exigente: fuerza bruta, política de contraseñas y sesión revocable"
estado: hecho
agente: "security-agent"
creada: 2026-08-26
rama: "security/login-exigente"
---

## Origen

Encargo directo del dueño del proyecto (2026-08-26): *"dile al agente de
seguridad que trabaje en el login de manera exigente"*.

Llega en el momento correcto. Con **ADR-0009** el backend deja de ser código
sin consumidor y pasa a ser **el sistema de autenticación real de la app**.
Todo lo que hoy es un fallo teórico en `/api/auth/**`, mañana es un fallo de
producción. Y según el plan de migración
(`docs/agent-tasks/014-migracion-de-firebase-al-backend.md`), el contrato de
autenticación hay que cerrarlo **antes** de reescribir el login de Flutter,
o se escribe dos veces.

## Estado actual (verificado, no asumido)

Lo que **ya está bien** y no hay que rehacer:

- Contraseñas con **BCrypt**, nunca en claro (verificado en PostgreSQL:
  hash `$2a$10$`, 60 caracteres).
- El registro público **no puede crear ADMIN** (tarea 008, ADR-0005): el rol
  no es expresable en la petición.
- Una cuenta suspendida **ya no se distingue** de una contraseña incorrecta:
  mismo 401, mismo mensaje; el motivo real solo va al log (tarea 009).
- Los errores de autenticación devuelven el código correcto y se loguean
  (tarea 009, ADR-0008).

Lo que **falta**:

1. **Sin rate limiting ni bloqueo por intentos.** Nada impide probar
   contraseñas contra `/api/auth/login` a la velocidad que aguante el
   servidor. Lo dejó anotado el propio `security-agent` al cerrar la tarea
   009: *"se cierra la fuga de información, no el ataque por fuerza bruta"*.
2. **Sin refresh tokens.** El JWT dura **7 días** (`JWT_EXPIRATION_MS=604800000`)
   y **no se puede revocar**: si lo roban, hay acceso durante una semana, y
   cerrar sesión no lo invalida. El dueño los pidió desde el principio como
   parte del stack objetivo, y nunca se implementaron.
3. **Política de contraseñas mínima.** Verificar qué se exige hoy (la tarea
   008 puso un mínimo de 12 caracteres para el ADMIN inicial, pero hay que
   comprobar qué aplica al registro normal) y decidir qué es razonable sin
   volverlo hostil para el usuario.

## Alcance

Trabaja **solo el backend** (`backend/`). La parte de Flutter llegará en la
fase 1 de la migración, cuando el contrato ya esté cerrado.

Decide tú el diseño concreto y documenta el porqué. Se espera que cubras al
menos:

- **Freno a la fuerza bruta.** Por IP y por cuenta (solo por IP se esquiva
  con una botnet; solo por cuenta permite bloquear a un usuario a propósito
  — es un vector de denegación de servicio contra una persona concreta, no
  lo introduzcas). Piensa qué pasa con un usuario legítimo que se equivoca
  tres veces.
- **Refresh tokens**, con el token de acceso corto y el de refresco
  revocable. Cerrar sesión debe invalidar de verdad.
- **Política de contraseñas** razonable, con mensajes en español.
- Qué se loguea de cada intento fallido, sin filtrar datos personales.

**Redis está en el stack objetivo pero no existe en el repo.** Si tu diseño
lo necesita para contar intentos, no lo des por hecho: o lo justificas y lo
añades (coordinando con `devops-agent`), o resuelves en base de datos. Di
explícitamente qué elegiste y por qué.

## Criterios de aceptación

- [x] ADR en `docs/decisions.md` (siguiente número libre) con el diseño y las
      alternativas descartadas, **escrito antes de implementar**.
- [x] N intentos fallidos seguidos dejan de responder como si nada.
      Demostrado contra el servidor real con peticiones de verdad.
- [x] El bloqueo **no** permite que un atacante deje fuera a un usuario
      legítimo a voluntad. Explica en el reporte por qué tu diseño lo evita.
- [x] Existen refresh tokens: el de acceso es corto, el de refresco se puede
      revocar, y cerrar sesión invalida la sesión de verdad (demostrado:
      token viejo → 401).
- [x] Un usuario legítimo con contraseña correcta **no** queda bloqueado por
      el mecanismo nuevo.
- [x] Tests. Los 77 existentes siguen pasando; los nuevos cubren el bloqueo,
      el refresco y la revocación.
- [x] `backend/scripts/prueba-flujo-negocio.sh` sigue en **0 fallos
      inesperados**. Si tu cambio altera lo que devuelve el login, actualiza
      el script — pero no lo relajes para que pase.
- [x] `docs/api.md` refleja los endpoints y contratos nuevos.

## Fuera de alcance

- `lib/**` (Flutter) — llega en la fase 1 de la tarea 014.
- El doble rol de la tarea 012: **no decidas** cómo se representan los roles
  en el token. Está pendiente de una decisión de producto. Si tu diseño
  toca el contenido del JWT, déjalo preparado para que quepan varios roles,
  pero no lo implementes.
- 2FA / verificación en dos pasos: si crees que hace falta, propónlo como
  tarea aparte.

## Notas del agente que la ejecuta

Cerrada el 2026-08-26 por `security-agent`. Diseño en **ADR-0010** (escrito
antes de implementar). Reporte con la evidencia real:
`docs/agent-reports/015-login-exigente.md`.

**Lo que se hizo**, en una línea cada cosa:

- **Freno de fuerza bruta en dos ejes**, contado en PostgreSQL (`intentos_login`):
  20 fallos/15 min por IP → 429 antes de BCrypt; 5 fallos/15 min por cuenta →
  429 **solo para los intentos con contraseña incorrecta**.
- **La contraseña correcta nunca se rechaza.** Es lo que evita convertir el
  freno en una forma de dejar fuera a un usuario concreto. Verificado contra el
  servidor: con la cuenta bajo ataque (6 fallos, ya en 429), el dueño entró con
  su contraseña **desde la misma IP del atacante** y desde otra distinta, las
  dos veces 200.
- **Refresh tokens**: acceso de 15 min (antes 7 días irrevocables) + refresh
  opaco de 30 días, guardado hasheado, rotativo, con revocación de familia si
  se reutiliza uno ya rotado. `POST /api/auth/logout` invalida la sesión.
- **Política de contraseñas**: 10–72 caracteres, sin reglas de composición,
  con lista de bloqueo y rechazo de "solo dígitos" y carácter repetido.
- **Redis: descartado**, se resuelve en PostgreSQL (razón en ADR-0010).
- Tests 85/85 (+8) y script de regresión **175 OK / 0 inesperados** (antes 155).

**Lo que NO se hizo, y dónde quedó anotado:**

- Fuerza bruta **distribuida** (muchas IPs, ritmo bajo): no se puede frenar sin
  bloquear cuentas. Va a `016-fuerza-bruta-distribuida-y-retencion.md`, junto
  con dos hallazgos: la API ve la IP del gateway de Docker (`172.18.0.1`) para
  todo el tráfico originado en el host —lo que vuelve el límite por IP casi
  global en ese camino— y que nadie borra las filas viejas de `intentos_login`
  / `refresh_tokens`.
- **No existe cambio ni recuperación de contraseña** en el backend (hallazgo
  lateral, se verificó): `017-cambio-y-recuperacion-de-contrasena.md`.
- **2FA**: propuesto dentro de la 016, no implementado (fuera de alcance).
- **Roles en el token**: intactos a propósito. El claim `rol` sigue siendo uno
  solo y es **informativo** — la autorización lee el rol de la BD en cada
  petición (`JwtAuthFilter`), así que la tarea 012 puede cambiarlo a una lista
  sin tocar nada más. Anotado en el javadoc de `JwtService`.
