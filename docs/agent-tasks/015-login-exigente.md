---
id: 015
titulo: "Login exigente: fuerza bruta, política de contraseñas y sesión revocable"
estado: en-progreso
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

- [ ] ADR en `docs/decisions.md` (siguiente número libre) con el diseño y las
      alternativas descartadas, **escrito antes de implementar**.
- [ ] N intentos fallidos seguidos dejan de responder como si nada.
      Demostrado contra el servidor real con peticiones de verdad.
- [ ] El bloqueo **no** permite que un atacante deje fuera a un usuario
      legítimo a voluntad. Explica en el reporte por qué tu diseño lo evita.
- [ ] Existen refresh tokens: el de acceso es corto, el de refresco se puede
      revocar, y cerrar sesión invalida la sesión de verdad (demostrado:
      token viejo → 401).
- [ ] Un usuario legítimo con contraseña correcta **no** queda bloqueado por
      el mecanismo nuevo.
- [ ] Tests. Los 77 existentes siguen pasando; los nuevos cubren el bloqueo,
      el refresco y la revocación.
- [ ] `backend/scripts/prueba-flujo-negocio.sh` sigue en **0 fallos
      inesperados**. Si tu cambio altera lo que devuelve el login, actualiza
      el script — pero no lo relajes para que pase.
- [ ] `docs/api.md` refleja los endpoints y contratos nuevos.

## Fuera de alcance

- `lib/**` (Flutter) — llega en la fase 1 de la tarea 014.
- El doble rol de la tarea 012: **no decidas** cómo se representan los roles
  en el token. Está pendiente de una decisión de producto. Si tu diseño
  toca el contenido del JWT, déjalo preparado para que quepan varios roles,
  pero no lo implementes.
- 2FA / verificación en dos pasos: si crees que hace falta, propónlo como
  tarea aparte.

## Notas del agente que la ejecuta

(vacío — tarea en progreso)
