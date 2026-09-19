---
id: 024
titulo: "Cerrar sesión debería revocar la familia de tokens, no solo el presentado"
estado: hecho
agente: "security-agent"
creada: 2026-08-29
rama: "security/logout-revoca-familia"
---

## Origen

Lo destapó la revisión de QA (tarea 022) al reproducir un fallo real: si el
usuario cerraba sesión **mientras había una renovación de token en vuelo**,
el refresco terminaba después y guardaba en el dispositivo un par de tokens
recién emitido. Ese par **seguía siendo válido en el servidor**, así que al
siguiente arranque la app entraba sola con una sesión que el usuario creía
cerrada.

El `qa-agent` lo arregló **en el cliente** (tercer candado en `ApiClient`), y
está bien: el caso concreto ya no ocurre. Pero la causa de fondo sigue en el
backend.

## El problema

`RefreshTokenService.revocar()` (verificado por el `tech-lead`):

```java
public void revocar(String valorPresentado) {
    repo.findByTokenHash(hash(valorPresentado)).ifPresent(fila -> {
        if (!fila.isRevocado()) { fila.setRevocado(true); repo.save(fila); }
    });
}
```

Marca **solo la fila del token presentado**. Cualquier otro token vivo de la
misma familia sigue siendo aceptado.

Es llamativo porque el mismo servicio **sí sabe revocar familias**: lo hace
cuando detecta que se reutilizó un token ya rotado (`RevocadorDeFamilias`,
ADR-0010). La capacidad existe; el `logout` simplemente no la usa.

## Por qué importa aunque el cliente ya esté arreglado

1. **"Cerrar sesión" debería significar que la sesión terminó.** Hoy
   significa "olvida este token concreto". Si el usuario cierra sesión porque
   cree que alguien le tocó el teléfono, esperaría lo primero.
2. **Defensa en profundidad.** El arreglo del cliente depende de que el
   cliente se comporte. Un cliente futuro, otra plataforma, o un bug nuevo
   pueden volver a dejar un token huérfano vivo. El servidor no debería
   confiar en eso.
3. Es un cambio pequeño: la capacidad ya está construida.

## Qué habría que decidir

- ¿`logout` revoca la familia (esta sesión, este dispositivo) o **todas** las
  del usuario (todos los dispositivos)? Lo normal es lo primero, y ofrecer lo
  segundo como "cerrar sesión en todos lados". Decidirlo y documentarlo.
- ¿Hace falta un endpoint explícito de "cerrar sesión en todos los
  dispositivos"? Es lo que uno espera al sospechar que le robaron la cuenta.

## Criterios de aceptación

- [x] Cerrar sesión invalida **todos** los tokens vivos de esa familia,
      demostrado contra el servidor: token viejo → 401, token nuevo → 401.
- [x] Cerrar sesión en un dispositivo **no** cierra los demás (salvo que se
      decida lo contrario, y entonces documentarlo).
- [x] Test que falle sin el arreglo.
- [x] `mvn test` sigue pasando (hoy 103) y el script de regresión en 0 fallos
      inesperados.
- [x] Actualizar ADR-0010 o escribir uno nuevo si cambia el contrato.

## Nota

Esta tarea **no bloquea** la fase 2b: el fallo concreto ya no ocurre gracias
al arreglo del cliente. Es endurecimiento del servidor, no una brecha abierta.

## Notas del agente que la ejecuta

Hecha el 2026-08-30 por `security-agent`. Reporte:
`docs/agent-reports/024-logout-debe-revocar-la-familia.md`. Decisión de diseño
en **ADR-0012**, escrita antes de implementar.

Los cinco criterios de aceptación quedan cumplidos:

- `logout` revoca la familia entera. Contra el servidor real: tras cerrar
  sesión con el token viejo, **el viejo → 401 y el rotado durante el logout →
  401** (antes ese daba 200). En la BD, la familia pasa de 1 token vivo a 0.
- Cerrar sesión en un dispositivo **no** cierra el otro: el refresh de la
  segunda sesión sigue devolviendo 200. Se decidió así a propósito, y la
  acción "cerrar en todos" es un endpoint aparte,
  **`POST /api/auth/logout-todos`** (el único de `/api/auth/**` que exige token
  de acceso).
- Test que falla sin el arreglo: `CierreDeSesionHttpTest` → 2 de sus 8 tests
  fallan si se devuelve `cerrarSesion` a la lógica de una sola fila
  (comprobado, no supuesto).
- `mvn test` → **111/111** (103 + 8). Script de regresión → **219 OK, 0 fallos
  conocidos, 0 inesperados** (207 + 12 nuevas).
- ADR-0012 escrito; corrige la Decisión 3 de ADR-0010, que decía "revoca el
  refresh presentado".

Dos cosas que conviene saber:

- **El tercer candado del cliente (tarea 022) se queda.** Ya no es la única
  defensa, pero sigue evitando que el dispositivo *guarde* tokens de una sesión
  cerrada —sin él la app arrancaría creyendo que tiene sesión y solo se
  enteraría al primer 401— y cubre el caso de "aquí ya hay otra sesión", que el
  servidor no puede ver. Se corrigieron los comentarios de `lib/` y `test/` que
  seguían afirmando que el backend revoca una sola fila.
- **Hallazgo lateral → tarea 025:** el endpoint nuevo no tiene botón en la app,
  `DELETE /api/usuarios/me` no revoca las sesiones (solo pone `activo = false`,
  que ya corta el acceso pero deja las filas vivas para una eventual
  reactivación) y el futuro cambio de contraseña (017) tendrá que revocarlas.
