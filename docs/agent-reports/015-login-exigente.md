---
id: 015
tarea: docs/agent-tasks/015-login-exigente.md
agente: "security-agent"
fecha: 2026-08-26
---

## Objetivo (copiado de la tarea)

Encargo directo del dueño: *"dile al agente de seguridad que trabaje en el
login de manera exigente"*. Con **ADR-0009** el backend deja de ser código sin
consumidor y pasa a ser el sistema de autenticación real de la app, así que los
tres agujeros del login dejan de ser teóricos: sin freno a la fuerza bruta, JWT
de 7 días irrevocable y política de contraseñas floja.

## El ataque, ANTES (servidor real, no un test)

El backend desplegado era el mismo código que la rama base (`git diff` sobre
`backend/` entre el commit desplegado y mi punto de partida: solo diferían
líneas del README).

```
=== 20 intentos con password incorrecta ===
401 401 401 401 401 401 401 401 401 401 401 401 401 401 401 401 401 401 401 401
20 intentos en 2.058195989s
=== Tras 20 fallos, la contraseña CORRECTA sigue funcionando: ===
login correcto -> 200
```

~10 intentos/segundo en un bucle secuencial trivial, sin concurrencia, sin
proxies, sin nada. Nada distinguía a un atacante de un usuario, y nada dejaba
rastro consultable.

## El mismo ataque, DESPUÉS

```
=== MISMO ATAQUE: 20 intentos con password incorrecta ===
401 401 401 401 401 429 429 429 429 429 429 429 429 429 429 429 429 429 429 429
Cabecera del 429:
HTTP/1.1 429
Retry-After: 900
```

Los cinco primeros fallos responden `401` (un usuario despistado no nota nada);
del sexto en adelante, `429` con `Retry-After`.

## Lo que de verdad había que demostrar: que esto NO deja fuera al dueño

Es la parte del encargo que más fácil se hace mal. Un "bloqueo tras N fallos"
convierte el freno en un arma: cualquiera que sepa tu correo te deja fuera.

**Mi diseño no puede hacer eso porque no existe ningún estado en el que la
contraseña correcta sea rechazada por el freno de cuenta.** El atacante, por
definición, no conoce la contraseña: todos sus intentos caen en la rama
"fallido", que es la única que recibe 429. El dueño acierta, y quien acierta
entra.

Demostrado contra el servidor, con el atacante en `172.18.0.1` y la víctima
entrando **desde otra IP** (`172.18.0.3`, otro contenedor) y **desde la misma
IP que el atacante**:

```
=== 1. El ATACANTE intenta adivinar la password ===
  intento 1 -> 401     intento 4 -> 401
  intento 2 -> 401     intento 5 -> 401
  intento 3 -> 401     intento 6 -> 429
=== 2. La VICTIMA entra desde OTRA IP con su password correcta ===
    HTTP/1.1 200
=== 3. Y TAMBIEN desde la MISMA IP que el atacante ===
  login del dueno -> 200
  token recibido: si
=== 4. Tras el login correcto el contador de la cuenta queda limpio ===
  siguiente intento fallido -> 401 (contador reiniciado, no 429)
```

El punto 3 es el importante: **misma IP, cuenta ya en 429, contraseña correcta
→ 200**. Y hay un test que lo fija para que nadie lo rompa sin darse cuenta
(`AuthServiceTest.login_conContrasenaCORRECTA_entraAunqueLaCuentaEsteBajoAtaque`
y `LoginExigenteHttpTest.cuentaBajoAtaque_elDuenoSigueEntrando`).

## Sesión revocable (refresh tokens), verificado en el servidor

```
expiraEnSegundos = 900  (antes: 604800 = 7 dias)
=== REFRESH (rotacion) ===
  refresh nuevo distinto del viejo: si
  access token nuevo sirve -> 200
  reutilizar el refresh VIEJO -> 401 (deteccion de robo)
  y el nuevo tambien muere   -> 401 (familia revocada)
=== LOGOUT ===
  refresh ANTES del logout -> 200
  POST /api/auth/logout    -> 204
  refresh DESPUES          -> 401
=== En la BD solo hay HASHES ===
      hash_guardado      | revocado
 9WoxuWzPmLzdOEVA5xU3... | t
 Cb/N4Ac8sp/SDenMNE0K... | f
  el refresh real empezaba por: LmtL0YXykk8b...
```

## Cambios realizados

- **Freno de fuerza bruta** (`ControlFuerzaBruta`, `IntentoLogin`,
  `IntentoLoginRepository`, `IpDelCliente`): ventana deslizante de 15 min, 20
  fallos por IP (corta **antes** de BCrypt) y 5 por cuenta (429 solo en
  intentos ya fallidos). Un login correcto limpia los fallos de esa cuenta.
- **Refresh tokens** (`RefreshToken`, `RefreshTokenRepository`,
  `RefreshTokenService`, `RevocadorDeFamilias`): opacos, hasheados en BD,
  rotación en cada uso y revocación de familia ante reutilización.
- **Endpoints nuevos**: `POST /api/auth/refresh`, `POST /api/auth/logout`.
- **Access token de 15 min** (`JwtService`), con `JWT_EXPIRATION_MS` aceptado
  como respaldo para no romper despliegues existentes.
- **Política de contraseñas** (`@PasswordSegura` + `ValidadorPasswordSegura`):
  10–72 caracteres, lista de bloqueo, ni solo dígitos ni carácter repetido.
- **429 en el formato de error estándar** (`IntentosExcedidosException` +
  handler en `GlobalExceptionHandler`), con `Retry-After`.

## Archivos modificados

- Nuevos: `modules/auth/{ControlFuerzaBruta,IntentoLogin,IntentoLoginRepository,
  IpDelCliente,RefreshToken,RefreshTokenRepository,RefreshTokenService,
  RevocadorDeFamilias}.java`,
  `modules/auth/dto/{PasswordSegura,ValidadorPasswordSegura,RefreshRequest}.java`,
  `common/exception/IntentosExcedidosException.java`,
  `src/test/.../auth/LoginExigenteHttpTest.java`.
- Modificados: `modules/auth/{AuthService,AuthController}.java`,
  `modules/auth/dto/{AuthResponse,RegistroRequest}.java`,
  `security/JwtService.java`, `common/exception/GlobalExceptionHandler.java`,
  `src/main/resources/application.yml`, `src/test/resources/application-test.yml`,
  `.env.example`, `docker-compose.yml`, `scripts/prueba-flujo-negocio.sh`,
  `src/test/.../auth/AuthServiceTest.java`.
- Docs: `docs/decisions.md` (ADR-0010), `docs/api.md`,
  `docs/agent-context/repo-snapshot.md`, tareas 015/016/017.

## Decisiones tomadas

**1. Por qué el freno por cuenta no bloquea (y sí frena).** Ya explicado
arriba: el 429 por cuenta sustituye a un `401` que ya iba a ocurrir, nunca a un
`200`. El coste asumido es que, para poder dejar entrar al dueño, hay que
ejecutar BCrypt en cada intento contra esa cuenta; el tope por IP es lo que
acota ese gasto.

**2. Redis: descartado, se cuenta en PostgreSQL.** Redis está en el stack
objetivo pero **no existe en el repo**, y montar un servicio nuevo (compose,
dependencia, modo de fallo, coordinación con `devops-agent`) para un contador
no se sostiene con este volumen. La BD ya está en el camino del login, es
transaccional y deja rastro auditable. Se descartó también un contador en
memoria (Bucket4j/Caffeine): se pierde en cada reinicio —y el despliegue
reinicia la API en cada build, o sea que se borraría justo mientras alguien
ataca— y no sirve con más de una instancia. `IntentoLoginRepository` aísla el
almacén por si algún día se mueve.

**3. `token` no se renombró a `accessToken`.** Renombrarlo no aporta seguridad
y obligaba a reescribir el script de regresión y la documentación. Se añaden
`refreshToken`, `tokenType` y `expiraEnSegundos`; `token` sigue siendo el que
va en `Authorization`.

**4. Roles en el token: no se tocan** (era petición explícita, tarea 012
pendiente). Y el motivo por el que cambiarlo será barato queda escrito en
`JwtService`: el claim `rol` es **informativo**; la autorización carga al
usuario de la BD en cada petición (`JwtAuthFilter`), así que pasar a una lista
`roles` es un cambio local.

**5. `X-Forwarded-For` no se lee por defecto.** Es falsificable: si se leyera
sin un proxy de confianza delante, bastaría con mandar una IP distinta en cada
petición para saltarse el límite por IP. Queda tras el flag
`LOGIN_CONFIAR_EN_XFF` (por defecto `false`).

## Problemas encontrados

**Un bug real que cazó el test nuevo, no la revisión a ojo.** La detección de
reutilización de refresh tokens revocaba la familia y acto seguido lanzaba el
401… dentro de la misma transacción. La excepción hacía **rollback de la
revocación**: el token robado seguía vivo, es decir, la defensa no defendía
nada. Se arregló moviendo la revocación a su propia transacción
(`RevocadorDeFamilias`, `REQUIRES_NEW`, en un bean aparte porque
`@Transactional` no se aplica en auto-invocación). Lo detectó
`LoginExigenteHttpTest.refreshRota`.

**Off-by-one en el tope por cuenta.** El quinto fallo ya devolvía 429 con
`max-por-cuenta=5`. Corregido a "los 5 primeros responden 401, el sexto frena",
que es lo que dice la configuración.

**La IP que ve el backend es la del gateway de Docker.** Medido, no supuesto:
todas las peticiones originadas en el host llegan como `172.18.0.1`. Para ese
tráfico el límite "por IP" es casi global — de hecho, en la primera prueba el
dueño legítimo recibió 429 **por el tope de IP** (no por el de cuenta) al
entrar desde la misma máquina donde acababa de correr el ataque de 20 intentos.
No lo arreglo aquí (es infraestructura): queda en la tarea **016**, y es la
razón de que el tope por IP sea generoso (20) y la ventana corta (15 min).

**Hallazgo lateral: no hay forma de cambiar ni recuperar la contraseña.**
Verificado en el código: la única escritura de `passwordHash` es el registro.
Hoy lo tapa Firebase Auth; con ADR-0009 desaparece. Tarea **017**.

## Tests ejecutados

```
mvn test -Dtest='!IntegridadCarteraConcurrenteTest' -DfailIfNoSpecifiedTests=false
→ Tests run: 85, Failures: 0, Errors: 0, Skipped: 0   BUILD SUCCESS
```

85 ejecutados = **71 previos + 14 nuevos** (4 en `AuthServiceTest`, que pasa de
7 a 11, y 10 en `LoginExigenteHttpTest`). Cubren: tope por IP antes de BCrypt,
429 por cuenta, **el dueño entra con la cuenta bajo ataque**, rotación de
refresh, detección de reutilización, logout, cuenta suspendida que no renueva,
y la política de contraseñas.

**Sobre la cifra "77" de la ficha de la tarea:** con este mismo comando yo
cuento **71** ejecutados antes de mi cambio (12 `MapeoErroresHttpTest` + 7
`AuthServiceTest` + 11 `RegistroRolTest` + 40 `TrabajoServiceTest` + 1 de
contexto), que es justo lo que decía el snapshot. La diferencia de 6 son los
tests de `IntegridadCarteraConcurrenteTest`, que este comando excluye. No lo
doy por resuelto de memoria: si la cifra importa, cuéntala con el comando.
`IntegridadCarteraConcurrenteTest` (6 tests, Testcontainers) **no se ejecutó**:
solo corre en el servidor Ubuntu; en Windows el cliente de Testcontainers
recibe 400 de Docker Desktop. No lo toqué, no debería verse afectado.

**Script de regresión contra el servidor real** (PostgreSQL de verdad):

```
cd ~/trabajito && COMPOSE_DIR=$HOME/trabajito/backend bash backend/scripts/prueba-flujo-negocio.sh
  OK:                  175
  Fallos conocidos:    0
  Fallos NO esperados: 0
  RESULTADO: TODO VERDE
```

De 155 a **175** comprobaciones: +20 de esta tarea. No se relajó ninguna
existente. El bloque nuevo va al final a propósito, porque gasta intentos
fallidos y el cupo por IP lo comparte todo el script.

## Pendientes

- **Tarea 016** — fuerza bruta distribuida (WAF/CAPTCHA/2FA), la IP real detrás
  de Docker, y retención/borrado de `intentos_login` y `refresh_tokens` (hoy
  crecen sin límite y guardan datos personales: correo + IP).
- **Tarea 017** — cambio y recuperación de contraseña (no existen).
- **2FA**: propuesta dentro de la 016, no implementada (fuera de alcance).
- **Revocación inmediata del access token**: tras `logout`, el JWT ya emitido
  vale hasta 15 min. Corte instantáneo exigiría lista negra o consulta por
  petición; con 15 min no compensa. Si algún día hace falta, es un ADR nuevo.
- **Flyway/Liquibase** sube otra vez de prioridad: esta tarea añade dos tablas
  creadas por `ddl-auto=update`.
- Estas dos tablas nuevas conviene que las mire `qa-agent` desde el ángulo de
  carga: el login ahora hace 2-3 consultas más por intento.
