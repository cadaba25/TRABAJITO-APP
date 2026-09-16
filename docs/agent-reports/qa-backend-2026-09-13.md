---
id: qa-backend-2026-09-13
tarea: (sin tarea formal en docs/agent-tasks/ — QA de diagnóstico pedido directamente)
agente: qa-agent
fecha: 2026-09-13
---

## Objetivo

QA completo del backend de Trabajito (Spring Boot + PostgreSQL) tras el
redespliegue de `develop` (commit `6705223`) en la VM de pruebas
(`docker compose build --no-cache api` + `docker compose up -d`). Verificar,
sin asumir nada:

1. `mvn test` local (Windows), documentando si Testcontainers se salta en
   silencio.
2. `backend/scripts/prueba-flujo-negocio.sh` contra la VM real.
3. `docker compose logs api` en la VM en busca de errores no capturados por
   el script.
4. Comparar contra los "FALLO CONOCIDO" documentados y distinguir regresión
   nueva de deuda ya conocida.
5. Verificar por cuenta propia cualquier hallazgo sospechoso antes de
   reportarlo.

No se tocó código de producción. No se hizo commit de nada.

## Entorno verificado

- **Local (Windows, `C:\Users\enigm\Desktop\EquipoAgentes\backend`)**: rama
  `feature/ui-ux` (misma base de `develop` para el backend). Maven 3.9.16,
  Java 21.0.10 (JBR de Android Studio). El pom pide Java 17 — Spring Boot
  3.3.4 arrancó sin problema con Java 21, no se investigó más porque no era
  el objeto del QA.
- **VM de pruebas** (`ssh -i ~/.ssh/trabajito_vm -p 2222 cadaba@127.0.0.1`):
  rama `develop`, commit `6705223` (verificado con `git log -1 --oneline`).
  `docker compose ps` antes y después de la prueba:
  - `trabajito-api` — `Up ... (healthy)`
  - `trabajito-db` — `Up ... (healthy)`
  - `trabajito-pgadmin` — `Up ...` (sin healthcheck definido, normal)

## 1. `mvn test` local

Comando exacto (excluyendo el test de Testcontainers, igual que documenta el
snapshot):

```
cd C:\Users\enigm\Desktop\EquipoAgentes\backend
mvn -Dtest='!IntegridadCarteraConcurrenteTest' test
```

Resultado (con salida completa redirigida a archivo para leer el resumen
real, no solo lo que cupo en la consola):

```
[INFO] Results:
[INFO]
[INFO] Tests run: 111, Failures: 0, Errors: 0, Skipped: 0
[INFO]
[INFO] BUILD SUCCESS
[INFO] Total time:  23.060 s
```

**111/111 pasan, 0 skipped.** Coincide con lo documentado en
`repo-snapshot.md` (111 tests tras la tarea 024). No hay regresión aquí.

Después corrí el test de Testcontainers por separado, a propósito, para
comprobar el fallo conocido "se salta en silencio":

```
cd C:\Users\enigm\Desktop\EquipoAgentes\backend
mvn -Dtest='IntegridadCarteraConcurrenteTest' test
```

Resultado:

```
15:25:31.180 [main] ERROR org.testcontainers.dockerclient.DockerClientProviderStrategy --
  Could not find a valid Docker environment. Please check configuration.
[WARNING] Tests run: 8, Failures: 0, Errors: 0, Skipped: 8, Time elapsed: 0.004 s
  -- in com.trabajito.modules.pagos.IntegridadCarteraConcurrenteTest
[INFO] BUILD SUCCESS
```

**Confirmado el fallo conocido documentado en `RETOMAR-AQUI.md`**: en esta
máquina Windows, Docker Desktop no lo encuentra vía Testcontainers (aunque
`docker compose` normal sí funciona para todo lo demás — es un problema
específico de Testcontainers/Docker Desktop en Windows, ya documentado) y
Maven reporta `BUILD SUCCESS` con `Skipped: 8` — **esos 8 tests NO se
ejecutaron, y el build verde no lo dice de forma obvia** salvo por el
contador. Nota aparte: el snapshot habla de "6/6" tests en este archivo; hoy
son **8**, no 6 — no lo investigué a fondo (no era parte del alcance),
puede ser solo desactualización de la cifra en la documentación o que se
añadieron 2 casos entre medias; lo marco para que quien mantenga
`repo-snapshot.md` lo confirme, no lo reporto como bug.

**Conclusión de esta sección: no hay forma de correr
`IntegridadCarteraConcurrenteTest` en este entorno Windows.** La única
prueba real de la integridad del dinero bajo concurrencia es el script de
flujo de negocio contra la VM (sección 2), que sí la ejercita con `curl`
real en paralelo (no Testcontainers).

## 2. `prueba-flujo-negocio.sh` contra la VM

Comando exacto:

```
ssh -i ~/.ssh/trabajito_vm -p 2222 cadaba@127.0.0.1 \
  "cd ~/trabajito && bash backend/scripts/prueba-flujo-negocio.sh"
```

(Sin variables de entorno adicionales — se usó `API_URL` y `COMPOSE_DIR` por
defecto, y `SIN_PSQL=0`, o sea que SÍ se hicieron los cuadres contra
PostgreSQL real vía `docker compose exec db psql`.)

Resultado exacto (resumen final del script):

```
==========================================================
RESUMEN
==========================================================
  OK:                  219
  Fallos conocidos:    0  (bugs diagnosticados, con tarea abierta)
  Fallos NO esperados: 0
RESULTADO: TODO VERDE
```

Desglose por sección, las 219 comprobaciones — **todas OK, ninguna en
amarillo (FALLO CONOCIDO) y ninguna en rojo**:

- Registro de actores (2/2)
- Flujo feliz, pasos 1-10: publicar → postularse → ver postulantes → aceptar
  → recargar cartera → reservar pago/escrow → iniciar → terminar (con
  evidencias) → aceptar y liberar pago → calificar ambas partes, con
  reputación separada por rol (35/35)
- Casos borde de autorización (8/8)
- Casos borde de máquina de estados (11/11)
- Casos borde de dinero, incluido reembolso por cancelación y cierre (18/18)
- **Redondeo sub-centavo (BUG-007)**: `reservar 0.005` rechazado por más de
  2 decimales, saldo intacto — **4/4 OK**
- **Doble toque y concurrencia (BUG-007)**: doble gasto simultáneo (2
  reservas de 1000 con solo 1000 de saldo), doble toque en liberar el pago,
  doble toque al postularse — **6/6 OK, sin la marca de FALLO CONOCIDO**.
  Es decir: **en esta corrida concreta la race condition de BUG-007 NO se
  manifestó** (el propio `RETOMAR-AQUI.md` avisa que ese fallo ha dado
  "positivos falsos" por no ser determinista en ejecuciones anteriores). No
  es una regresión ni una confirmación de arreglo — es exactamente el
  comportamiento no determinista ya documentado. Ver "Pendientes" abajo.
- Cancelación tras la entrega (BUG-010, arreglado) + reclamo a soporte y
  resolución de disputa por ADMIN (18/18)
- Escalada de privilegios (BUG-008, arreglado) (6/6)
- Mapeo de errores HTTP (antes BUG-009) (15/15)
- Login de cuenta suspendida (6/6)
- Login exigente: fuerza bruta, refresh, logout (tarea 015) (16/16)
- Cierre de sesión — familia y todos los dispositivos (tarea 024) (12/12)
- Perfil completo del trabajador (tarea 019), incluida privacidad del perfil
  ajeno (24/24)
- Cuadre contable (`saldo == SUM(movimientos_cartera)`) para **los 7
  usuarios de prueba** de esta corrida (empleador, trabajador, tercero,
  pobre, redondeo, concurrente, abusivo) — **7/7 OK**

**No se gastó ningún cupo extra de intentos de login fuera de lo que el
propio script ya contempla** (no se hicieron logins fallidos manuales
adicionales, respetando el límite de 20/15min por IP).

## 3. `docker compose logs api` en la VM

Comando: `docker compose logs api --since 15m` (cubre toda la ventana del
script, que corrió de 21:24 a 21:31 UTC aprox.).

- **0 líneas `ERROR`.**
- **0 stack traces / `Caused by:` / rutas `.java:NNN)`.**
- Los `WARN` que aparecen son **todos esperados y ya documentados por su
  propio nombre de logger**: `AuthService` avisando fuerza bruta y cuentas
  suspendidas, `RevocadorDeFamilias` avisando reutilización de refresh
  token detectada (es el mecanismo de seguridad de la tarea 024
  funcionando, no un error), y un aviso de Spring Data sobre serializar
  `PageImpl` (ruido conocido de Spring Data REST, no específico de este
  despliegue).
- **Un `WARN` que sí vale la pena anotar, sin ser una regresión de código**:

  ```
  2026-09-13T21:31:13.409Z WARN ... HikariPool-1 - Thread starvation or
  clock leap detected (housekeeper delta=5m31s143ms508µs651ns).
  ```

  Es un aviso de infraestructura (el reloj del contenedor/VM saltó ~5m31s,
  probablemente por una pausa del host VirtualBox entre mis propias
  sesiones SSH, no por el tráfico del script) — **no es un fallo del
  backend**, es HikariCP detectando que el housekeeper no corrió a tiempo.
  No hubo timeouts de conexión ni fallos de pool asociados a este aviso en
  el resto del log. Lo dejo anotado por transparencia, no lo cuento como
  hallazgo.

## 4. Comparación contra "FALLO CONOCIDO"

| Fallo conocido | Estado esta corrida | Comentario |
|---|---|---|
| BUG-007 (integridad del dinero, race condition) | **No se manifestó** — todas las comprobaciones de concurrencia y cuadre dieron OK | No determinista por diseño (documentado); no confirma que esté arreglado, tampoco es una regresión nueva |
| BUG-008 (escalada de privilegios) | Arreglado, verificado de nuevo (6/6 OK) | Test de regresión, sigue sólido |
| BUG-009 (errores 500 no mapeados) | Arreglado, verificado de nuevo (15/15 OK) | Test de regresión, sigue sólido |
| BUG-010 (cancelación tras la entrega) | Arreglado, verificado de nuevo (18/18 OK) | Test de regresión, sigue sólido |
| Testcontainers se salta en silencio (Windows) | **Confirmado, reproducido a propósito** | `Skipped: 8`, `BUILD SUCCESS` — sigue siendo una trampa real en este entorno, no una regresión (ya documentada) |

**No se encontró ninguna regresión nueva.** Ni en `mvn test` (111/111,
0 nuevos fallos) ni en el script de flujo de negocio (219/219, 0
inesperados) ni en los logs del contenedor (0 `ERROR`, 0 stack traces).

Sobre la tarea 030 (tarjetas + JWT en WebSocket): confirmado que **no
aplica a este despliegue** — no se probó `/api/cartera/tarjetas` ni la
validación de JWT en el `CONNECT` del WebSocket porque esa rama no está
fusionada a `develop`. No lo cuento como fallo.

## 5. Verificación propia de lo sospechoso

Lo único que ameritaba verificación activa era la trampa de Testcontainers
("se salta en silencio"): la reproduje deliberadamente corriendo SOLO
`IntegridadCarteraConcurrenteTest` y confirmé que Maven dice `BUILD SUCCESS`
con `Skipped: 8` en vez de fallar o avisar con claridad — el mismo patrón
que `RETOMAR-AQUI.md` advierte que ya ha pasado antes. No fue necesario
romper código de producción a propósito porque no apareció ningún
resultado dudoso que necesitara esa comprobación (todo lo demás fue
consistente: 111/111 local, 219/219 contra el servidor real, 0 errores en
logs).

## Qué NO se pudo verificar

- **`IntegridadCarteraConcurrenteTest` (Testcontainers) no corrió en este
  entorno Windows** — Docker Desktop no es compatible con el cliente de
  Testcontainers aquí (documentado, no es hallazgo nuevo). Esa cobertura
  específica de concurrencia con PostgreSQL real vía JUnit **no se
  ejecutó**; la única evidencia de concurrencia de esta sesión es la del
  script de flujo de negocio (curl en paralelo contra la VM), que sí pasó.
- **No se corrió el script varias veces para forzar la aparición de
  BUG-007** (el propio bug es una race condition no determinista); una
  corrida en verde no es prueba de que esté arreglado ni de que siga
  fallando bajo más presión de concurrencia. Si se necesita una conclusión
  definitiva sobre BUG-007, hace falta correr el script repetidas veces o
  correr `IntegridadCarteraConcurrenteTest` en un entorno con Testcontainers
  funcional (el propio servidor Ubuntu, según el snapshot).
- No se revisaron `docker compose logs db` ni `docker compose logs
  pgadmin` (fuera del alcance pedido: "logs api").
- No se tocó ni verificó nada de la rama `feature/tarjetas-y-websocket-jwt`
  / `review/tarea-030-fix-403-tarjetas` (tarea 030) — explícitamente fuera
  de alcance porque no está desplegada en la VM.

## Resumen de comandos y resultados (para trazabilidad)

```
# 1. Unitarios (excluyendo Testcontainers)
cd C:\Users\enigm\Desktop\EquipoAgentes\backend
mvn -Dtest='!IntegridadCarteraConcurrenteTest' test
# -> Tests run: 111, Failures: 0, Errors: 0, Skipped: 0 — BUILD SUCCESS

# 1b. Solo Testcontainers, para confirmar el fallo conocido
mvn -Dtest='IntegridadCarteraConcurrenteTest' test
# -> Tests run: 8, Failures: 0, Errors: 0, Skipped: 8 — BUILD SUCCESS
#    ("Could not find a valid Docker environment" de Testcontainers)

# 2. Flujo de negocio real contra la VM
ssh -i ~/.ssh/trabajito_vm -p 2222 cadaba@127.0.0.1 \
  "cd ~/trabajito && bash backend/scripts/prueba-flujo-negocio.sh"
# -> OK: 219  Fallos conocidos: 0  Fallos NO esperados: 0
#    RESULTADO: TODO VERDE

# 3. Logs del contenedor api durante la ventana del script
ssh -i ~/.ssh/trabajito_vm -p 2222 cadaba@127.0.0.1 \
  "cd ~/trabajito/backend && docker compose logs api --since 15m"
# -> 0 líneas ERROR, 0 stack traces, solo WARN esperados
```

## Pendientes (candidatos a tarea nueva, no arreglados aquí)

- **Confirmar de forma determinista si BUG-007 sigue vivo o ya se cerró**:
  correr `IntegridadCarteraConcurrenteTest` en el servidor Ubuntu (donde sí
  funciona Testcontainers, según el snapshot) y/o correr
  `prueba-flujo-negocio.sh` varias veces seguidas para intentar forzar la
  race condition. Esta sesión no lo hizo por estar fuera del pedido
  explícito (QA de diagnóstico de esta corrida, no cierre de BUG-007).
- **Discrepancia de documentación menor**: `repo-snapshot.md` dice
  "6 tests con Testcontainers" para `IntegridadCarteraConcurrenteTest`; hoy
  son 8. No es un bug, es una nota para `docs-agent`/`tech-lead` al
  actualizar el snapshot.
