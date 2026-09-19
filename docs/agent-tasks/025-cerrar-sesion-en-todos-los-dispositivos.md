---
id: 025
titulo: "Nadie puede llegar a 'cerrar sesión en todos los dispositivos', y ni el cambio de contraseña ni la baja de cuenta revocan sesiones"
estado: todo
agente: ""
creada: 2026-08-30
rama: ""
---

## Por qué existe

Hallazgo lateral de la tarea 024 (ADR-0012), que arregló el `logout` del
backend para que revoque la familia entera de refresh tokens y añadió
`POST /api/auth/logout-todos`.

Ese endpoint **funciona y está verificado contra el servidor**, pero hoy
**ningún usuario puede llegar a él**: la app no tiene botón. Es justo la acción
que uno busca cuando cree que le tocaron la cuenta, así que un endpoint sin
interfaz no resuelve el problema real, solo lo deja resuelto en el papel.

Y quedan dos huecos de la misma familia, ninguno explotable hoy pero los dos
del tipo "la seguridad depende de que nadie mire":

1. **Cambiar la contraseña no echará a las sesiones abiertas.** El endpoint no
   existe todavía (tarea 017), así que esto es una condición que hay que
   cumplir *cuando se implemente*: cambiar la contraseña sin revocar sesiones no
   expulsa a quien ya está dentro, que es el 90 % del motivo por el que alguien
   la cambia a las prisas.
2. **La baja de cuenta no limpia sus refresh tokens.** `DELETE /api/usuarios/me`
   pone `activo = false`, y eso ya corta el acceso (`JwtAuthFilter` y el
   `refresh` rechazan a un usuario inactivo), así que **no hay agujero abierto
   ahora mismo**. Pero las filas de `refresh_tokens` se quedan sin revocar: si
   la cuenta se reactiva a mano —cosa que ya se ha hecho en el servidor de
   pruebas, ver el reporte 008—, todas esas sesiones antiguas reviven.

## Qué habría que hacer

- **Flutter (`flutter-agent`)**: botón "Cerrar sesión en todos los
  dispositivos" en `ConfiguracionScreen`, con confirmación y un texto que diga
  claramente que también cierra ESTE dispositivo y habrá que volver a entrar.
  Llama a `POST /api/auth/logout-todos` (necesita `Authorization: Bearer`,
  a diferencia del `logout` normal) y después limpia la sesión local igual que
  el logout de siempre. Contrato en `docs/api.md`.
- **Backend (`backend-agent`)**: que `DELETE /api/usuarios/me` llame a
  `RefreshTokenService.cerrarTodasLasSesiones(id)`. Son dos líneas.
- **Cuando se haga la tarea 017**: el cambio de contraseña debe llamar a
  `cerrarTodasLasSesiones` del usuario. Decidir ahí si se deja viva la sesión
  desde la que se cambia (ADR-0012 descartó de momento el "cerrar las demás,
  menos esta", pero para el cambio de contraseña sí tiene sentido plantearlo).

## Criterios de aceptación

- [ ] Desde la app se puede cerrar sesión en todos los dispositivos y se
      comprueba en un emulador/dispositivo real (o, como mínimo, con dos
      sesiones abiertas contra el servidor de pruebas).
- [ ] Dar de baja la cuenta deja sus filas de `refresh_tokens` revocadas
      (`SELECT count(*) FROM refresh_tokens WHERE usuario_id = ... AND NOT
      revocado` → 0), comprobado contra el servidor.
- [ ] Tests: uno de Flutter para el botón y uno de backend para la baja.

## Notas del agente que la ejecuta

(pendiente)
