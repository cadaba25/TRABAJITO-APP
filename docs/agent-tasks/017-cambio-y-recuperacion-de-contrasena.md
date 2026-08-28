---
id: 017
titulo: "No existe forma de cambiar ni de recuperar la contraseña"
estado: todo
agente: ""   # candidato: backend-agent + security-agent
creada: 2026-08-26
rama: ""
---

## Objetivo

Hallazgo lateral de la tarea 015 (login exigente): **el backend no tiene ningún
endpoint para cambiar la contraseña ni para recuperarla si se olvida.**
Verificado, no supuesto: en `AuthController` solo hay `registro`, `login`,
`refresh`, `logout` y `yo`; en `UsuarioController`, `PUT /api/usuarios/me` edita
el perfil y no toca `passwordHash`. La única escritura de contraseña en todo el
backend es la del registro y la del `AdminInicialSeeder`.

Hoy no se nota porque la app usa Firebase Auth, que trae "restablecer
contraseña" de fábrica. **Con ADR-0009 (se abandona Firebase) eso desaparece**:
el día que la app hable con este backend, un usuario que olvide su contraseña
se queda fuera para siempre y solo se le puede ayudar con SQL a mano.

Es también el complemento natural de la 015: de nada sirve exigir contraseñas
buenas y frenar la fuerza bruta si el usuario no puede rotar una contraseña que
sospecha comprometida.

## Alcance propuesto

1. **Cambio de contraseña autenticado** (`POST /api/auth/cambiar-password`):
   exige la contraseña actual (no basta con el token: si roban el token, no
   deben poder cambiarla), aplica la misma política `@PasswordSegura` del
   ADR-0010 y **revoca todas las sesiones** del usuario salvo la actual
   (`RefreshTokenRepository.revocarTodosDeUsuario` ya existe y hoy no se usa).
2. **Recuperación por correo**: token de un solo uso, corto y guardado
   hasheado (mismo patrón que `refresh_tokens`), con envío de correo — hoy el
   backend **no tiene ningún servicio de correo**, así que hay que decidirlo.
   La respuesta debe ser la misma exista o no la cuenta (no convertir el
   endpoint en un oráculo de qué correos están registrados, misma regla que el
   login desde la tarea 008).
3. El endpoint de recuperación necesita su propio freno de fuerza bruta: es
   público y manda correos. Reutilizar `ControlFuerzaBruta`.

## Criterios de aceptación

- [ ] Se puede cambiar la contraseña conociendo la actual, y las demás sesiones
      se caen al hacerlo.
- [ ] La política de contraseñas del ADR-0010 se aplica también aquí.
- [ ] La recuperación no revela si un correo existe.
- [ ] Tests + comprobación contra el servidor real.

## Notas del agente que la ejecuta

(vacío)
