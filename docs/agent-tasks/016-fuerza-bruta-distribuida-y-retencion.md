---
id: 016
titulo: "Fuerza bruta distribuida, IP real detrás de Docker y retención de intentos_login"
estado: todo
agente: ""   # candidato: security-agent + devops-agent (toca infraestructura)
creada: 2026-08-26
rama: ""
---

## Objetivo

Cerrar los tres cabos que la tarea 015 (ADR-0010) dejó abiertos a propósito
porque no se resuelven en la capa de aplicación.

## 1. La IP que ve el backend es la del gateway de Docker, no la del cliente

**Hallazgo real de la tarea 015, medido en el servidor.** Toda petición que
sale del propio host llega a la API como `172.18.0.1` (el gateway de la red de
Docker). Comprobado en la tabla `intentos_login`:

```
     ip     | fallos
------------+--------
 172.18.0.1 |     20
```

Consecuencia: para ese tráfico, el límite "por IP" del ADR-0010 **degenera en
un límite global**. Si alguien quema los 20 fallos de esa IP, cualquier otra
persona que entre por el mismo camino recibe 429 durante la ventana. Se vio en
vivo: tras 20 fallos, un login con la contraseña correcta desde el mismo origen
respondió 429.

No afecta al límite **por cuenta** (ese va por correo y sigue siendo exacto), ni
a un cliente externo que llega por DNAT (ahí sí se conserva la IP de origen),
pero hay que verificarlo con tráfico externo real y decidir:

- ¿Se pone un proxy inverso (nginx/Caddy) delante que fije `X-Forwarded-For` y
  se activa `LOGIN_CONFIAR_EN_XFF=true`? Ojo: activar ese flag **sin** un proxy
  que sobrescriba la cabecera es peor que no tenerlo — cualquiera manda una IP
  distinta en cada petición y el límite deja de existir.
- ¿O se desactiva el userland proxy de Docker para conservar la IP de origen?

Relacionado con `011-exposicion-del-servidor-de-pruebas.md`.

## 2. Fuerza bruta distribuida (el límite honesto del ADR-0010)

El freno por cuenta **no bloquea** la cuenta a propósito (si lo hiciera,
cualquiera podría dejar fuera a un usuario a voluntad). El precio: un atacante
con muchas IPs, cada una por debajo del cupo, puede seguir probando contraseñas
contra una cuenta a ritmo bajo. Contra eso hace falta algo que la capa de
aplicación no tiene:

- Rate limiting en el borde (WAF / nginx `limit_req` / Cloudflare).
- Un reto (CAPTCHA) cuando la cuenta está "con fricción", en vez de solo 429.
- **2FA / verificación en dos pasos** — deliberadamente fuera del alcance de la
  015. Es la única defensa que sobrevive a que la contraseña ya esté
  comprometida. Si el dueño la quiere, merece su propia tarea con decisión de
  producto (SMS en Honduras vs. TOTP vs. correo).

## 3. Retención: `intentos_login` y `refresh_tokens` crecen sin límite

Hoy nadie borra filas viejas. `intentos_login` guarda correo + IP + fecha (son
**datos personales**, misma salvedad que ADR-0008 sobre los logs) y
`refresh_tokens` acumula tokens revocados y caducados.

Hace falta un borrado periódico (`@Scheduled` o un job): intentos más viejos que
la ventana no sirven para nada, y un refresh caducado o revocado tampoco. Definir
cuánto se guarda para poder investigar un incidente sin acumular datos
personales indefinidamente.

## Criterios de aceptación

- [ ] Medido con tráfico **externo** qué IP ve realmente el backend, y decidido
      (con ADR si cambia la arquitectura) proxy inverso o no.
- [ ] `LOGIN_CONFIAR_EN_XFF` queda documentado como "solo con proxy de
      confianza delante", y su valor real en el servidor es coherente con eso.
- [ ] Existe borrado periódico de `intentos_login` y `refresh_tokens` con una
      retención escrita y justificada.
- [ ] Propuesta escrita (no necesariamente implementada) sobre CAPTCHA/2FA para
      el caso distribuido.

## Notas del agente que la ejecuta

(vacío)
