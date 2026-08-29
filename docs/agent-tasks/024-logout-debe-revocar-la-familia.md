---
id: 024
titulo: "Cerrar sesión debería revocar la familia de tokens, no solo el presentado"
estado: todo
agente: "security-agent"
creada: 2026-08-29
rama: ""
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

- [ ] Cerrar sesión invalida **todos** los tokens vivos de esa familia,
      demostrado contra el servidor: token viejo → 401, token nuevo → 401.
- [ ] Cerrar sesión en un dispositivo **no** cierra los demás (salvo que se
      decida lo contrario, y entonces documentarlo).
- [ ] Test que falle sin el arreglo.
- [ ] `mvn test` sigue pasando (hoy 103) y el script de regresión en 0 fallos
      inesperados.
- [ ] Actualizar ADR-0010 o escribir uno nuevo si cambia el contrato.

## Nota

Esta tarea **no bloquea** la fase 2b: el fallo concreto ya no ocurre gracias
al arreglo del cliente. Es endurecimiento del servidor, no una brecha abierta.
