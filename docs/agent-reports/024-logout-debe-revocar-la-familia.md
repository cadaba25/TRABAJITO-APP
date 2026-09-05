---
id: 024
tarea: docs/agent-tasks/024-logout-debe-revocar-la-familia.md
agente: "security-agent"
fecha: 2026-08-30
---

## Objetivo (copiado de la tarea)

`RefreshTokenService.revocar()` marcaba **solo la fila del token presentado**,
así que cualquier otro token vivo de la misma familia seguía siendo aceptado
por el servidor. Cerrar sesión debía significar que la sesión terminó. Había
además que decidir y documentar si `logout` cierra la sesión de este
dispositivo o la de todos.

Aplica al **backend Spring Boot** (JWT propio, `modules/auth`), no a Firebase
Authentication, que ya no se usa (ADR-0009).

## Cambios realizados

1. **`RefreshTokenService.revocar(String)` → `cerrarSesion(String)`**: busca la
   fila por hash y revoca **toda su familia** con `repo.revocarFamilia(...)`,
   la consulta que ya existía y usaba la detección de reutilización. Se revoca
   la familia **aunque la fila presentada esté ya revocada o caducada** — es
   justo el caso de la renovación en vuelo, en el que el cliente manda un token
   que ya fue rotado. Sigue siendo idempotente: token desconocido, no hace nada.
2. **`RefreshTokenService.cerrarTodasLasSesiones(UUID)`**: revoca todas las
   familias del usuario, con `repo.revocarTodosDeUsuario(...)`, que llevaba
   escrito desde la tarea 015 con el comentario "uso futuro" y no lo llamaba
   nadie.
3. **Endpoint nuevo `POST /api/auth/logout-todos`** (204, sin cuerpo) en
   `AuthController`, vía `AuthService.logoutDeTodosLosDispositivos(UUID)`.
4. **`SecurityConfig`**: regla explícita `POST /api/auth/logout-todos` →
   `authenticated()`, colocada **antes** del `permitAll` de `/api/auth/**`
   (en Spring Security gana la primera regla que casa). Es la única ruta de ese
   prefijo que exige token de acceso.
5. **Trazas**: `INFO` con la familia y el número de tokens revocados en los dos
   caminos. Antes el `logout` no dejaba rastro ninguno. Se sigue el nivel que
   fijó ADR-0008 para auth y no se loguea ningún token.
6. **Tests nuevos** (`CierreDeSesionHttpTest`, 8 con MockMvc + H2).
7. **Script de regresión**: sección "CIERRE DE SESION - familia y todos los
   dispositivos", 12 comprobaciones. Ninguna gasta intentos fallidos del cupo
   por IP (todos los logins son correctos).
8. **ADR-0012** en `docs/decisions.md` y contrato en `docs/api.md`.
9. **Comentarios desactualizados en `lib/` y `test/`**: tres bloques afirmaban
   como hecho vigente que "el backend revoca solo el token que se le presenta,
   no la familia". Se corrigieron dejando claro que el candado 3 del cliente
   **sigue haciendo falta**. Son comentarios, no lógica: `flutter analyze`
   sigue en las mismas 62 issues. Toqué dominio ajeno (regla 3 de CLAUDE.md)
   porque una afirmación falsa sobre las garantías del servidor, escrita justo
   al lado del código que decide si se guarda una sesión, es exactamente lo que
   hace que el siguiente agente quite un candado que sí hace falta.

## Archivos modificados

- `backend/src/main/java/com/trabajito/modules/auth/RefreshTokenService.java`
- `backend/src/main/java/com/trabajito/modules/auth/AuthService.java`
- `backend/src/main/java/com/trabajito/modules/auth/AuthController.java`
- `backend/src/main/java/com/trabajito/config/SecurityConfig.java`
- `backend/src/test/java/com/trabajito/modules/auth/CierreDeSesionHttpTest.java` (nuevo)
- `backend/scripts/prueba-flujo-negocio.sh`
- `docs/decisions.md` (ADR-0012), `docs/api.md`,
  `docs/agent-context/repo-snapshot.md`
- `docs/agent-tasks/024-...` (cerrada), `docs/agent-tasks/025-...` (nueva)
- `lib/services/api/api_client.dart`, `test/api/renovacion_y_sesion_test.dart`
  (solo comentarios)

## Decisiones tomadas

**`logout` cierra ESTE dispositivo; cerrar todos es una acción aparte.**
Una familia = una sesión = un dispositivo. Cerrar sesión en el móvil no cierra
la de la tablet: lo contrario sería un efecto sorpresa desproporcionado para
una acción cotidiana y empujaría a la gente a no cerrar sesión nunca. La
necesidad real de "creo que alguien entró en mi cuenta" existe, es distinta, y
se cubre con `POST /api/auth/logout-todos`, que **incluye la sesión desde la
que se pide**: quien pulsa eso quiere el estado limpio, y dejar viva justo esa
obligaría al cliente a un caso especial para ganar cero seguridad. Se descartó
por ahora la variante "cerrar las demás, menos esta": es comodidad, no
seguridad. Razonamiento completo en ADR-0012.

**`logout-todos` exige token de acceso y `logout` no.** `logout` no puede
exigirlo: quien cierra sesión suele tener el access caducado (15 min) y el
refresh que presenta ya es la credencial de esa sesión; si el logout fallara
por falta de token, dejaría la sesión **abierta**, que es el peor desenlace
posible. `logout-todos` sí lo exige porque es destructivo sobre todas las
sesiones. Honestamente: no frena a quien ya robó un refresh (podría canjearlo
por un access), pero evita que un refresh filtrado y caducado sirva para echar
al dueño de todos sus dispositivos, y ata la acción a una identidad en el log.

**Revocar la familia aunque el token presentado ya esté revocado.** Es la
decisión que hace que el arreglo funcione: si se exigiera un token vigente, el
caso de la renovación en vuelo —el que motivó la tarea— seguiría abierto. El
peor efecto de equivocarse aquí es cerrar una sesión de más; nunca dejar una
abierta.

**No se implementó revocación inmediata del access token.** ADR-0010 ya lo
descartó (sin lista negra de JWT); sigue siendo válido y ahora hay un test que
lo fija (`elAccessTokenSobreviveAlLogout`) para que se lea como decisión y no
como olvido. Si algún día hace falta corte inmediato, es un ADR nuevo con su
coste: BD en cada petición o `tokenVersion` por usuario.

## Problemas encontrados

- **La VM de pruebas estaba apagada** (SSH: `Connection refused`, el puerto
  2222 ni siquiera escuchaba). Contra lo que decía el encargo, `VBoxManage.exe`
  sí está instalado en este equipo, así que arranqué la VM
  `TrabajitoTestServer` en modo headless para poder verificar. **Queda
  encendida.**
- **Docker Hub falló dos veces por IPv6** en esa VM: la interfaz tiene una
  dirección ULA de la NAT de VirtualBox y todo el tráfico IPv6 saliente da
  `connection refused`, mientras que IPv4 funciona (`curl -6` → 000, `curl -4`
  → 200). El `docker compose build` moría en `load metadata for
  eclipse-temurin:17-jre-alpine`. **No hizo falta tocar nada**: un
  `docker pull eclipse-temurin:17-jre-alpine` a la tercera entró por IPv4, y
  con la imagen ya en local el build fue normal. Lo apunto porque volverá a
  pasar y porque no hay `sudo` sin contraseña en esa VM: si algún día se
  atasca de verdad, no se puede arreglar por `/etc/docker/daemon.json` ni por
  `/etc/hosts` sin la contraseña.
- Ningún conflicto con otras tareas: nadie más está tocando `modules/auth`.

## Tests ejecutados

**Backend, en la máquina de desarrollo** (`JAVA_HOME` = JBR de Android Studio,
Maven 3.9.16):

```
mvn test -Dtest='!IntegridadCarteraConcurrenteTest' -DfailIfNoSpecifiedTests=false
→ BUILD SUCCESS, Tests run: 111, Failures: 0, Errors: 0, Skipped: 0
```

111 = los 103 de antes + los 8 nuevos. `IntegridadCarteraConcurrenteTest`
(Testcontainers) se excluye como siempre; en Windows no corre.

**Test que falla sin el arreglo** (comprobado de verdad, devolviendo
`cerrarSesion` a la lógica de una sola fila y volviendo a correr):

```
mvn test -Dtest='CierreDeSesionHttpTest'
→ Tests run: 8, Failures: 2
   CierreDeSesionHttpTest.logoutRevocaLaFamiliaEntera
     [el token rotado durante el logout debe morir con la familia]
   CierreDeSesionHttpTest.logoutConTokenYaRotadoVariasVeces
```

Los otros 6 pasan con y sin el arreglo a propósito: fijan lo que **no** debe
cambiar (un dispositivo no arrastra a los demás, 204 con token inventado,
idempotencia) y lo que es decisión asumida (el access sobrevive ≤15 min).

**Contra el servidor real** (VM Ubuntu, PostgreSQL 16, imagen reconstruida
desde esta rama). Cuenta `qa024.1788130750@trabajito.test`, tres familias
—registro, móvil, tablet—:

```
== dispositivo 1 (movil): login + renovacion EN VUELO   (A1 -> A2)
== dispositivo 2 (tablet): login                        (B1)
   logout(A1, el token YA rotado)  -> 204
   refresh(A1)                     -> 401
   refresh(A2)                     -> 401   <- el arreglo (antes: 200)
   refresh(B1)                     -> 200   <- el otro dispositivo sigue
   logout-todos SIN token          -> 401
   logout-todos CON token          -> 204
   refresh(B3)                     -> 401   <- incluye la sesion que lo pidio
   GET /api/auth/yo con el access  -> 200   <- limite asumido (ADR-0010)
```

Con el cuadre en la BD (`refresh_tokens` agrupado por familia, columna
`vivos` = `count(*) filter (where not revocado)`):

| momento | familia registro | familia móvil | familia tablet |
|---|---|---|---|
| antes del logout | 1 vivo | 1 vivo (de 2 filas) | 1 vivo |
| tras `logout` del móvil | 1 vivo | **0 vivos** | 1 vivo |
| tras `logout-todos` | **0 vivos** | 0 vivos | **0 vivos** |

Y en `docker compose logs api`:
`Cierre de sesión: revocados 1 refresh tokens de la familia <uuid>` y
`Cierre de sesión en TODOS los dispositivos del usuario <uuid>: revocados 2`.

**Script de regresión, en el servidor:**

```
bash backend/scripts/prueba-flujo-negocio.sh   → exit 0
OK: 219   Fallos conocidos: 0   Fallos NO esperados: 0
```

219 = 207 + las 12 nuevas. Las 12 en verde a la primera; no hizo falta esperar
por ningún 429 (la sección no gasta intentos fallidos).

**Flutter:** `flutter analyze` → **62 issues**, las mismas de antes (solo toqué
comentarios). **No** corrí `flutter test` ni probé en emulador: esta tarea no
cambia una línea de lógica de cliente.

## Pendientes

- **Tarea 025 (creada):** la app no tiene botón de "cerrar sesión en todos los
  dispositivos", así que el endpoint existe pero ningún usuario llega a él.
  Incluye además dos huecos de la misma familia: `DELETE /api/usuarios/me`
  debería revocar los refresh tokens del usuario (hoy `activo = false` ya corta
  el acceso, pero las filas se quedan sin revocar y reviven si se reactiva la
  cuenta a mano — cosa que ya se ha hecho en este servidor), y el futuro cambio
  de contraseña (tarea 017) tiene que llamar a `cerrarTodasLasSesiones`.
- **Limpieza de `refresh_tokens`** (ya venía de ADR-0010 → tarea 016): las
  filas revocadas y caducadas no se borran nunca. Ahora crecen algo más rápido,
  porque un `logout` toca la familia entera en vez de una fila.
- **No hay tests de la capa de seguridad como tal** (`JwtAuthFilter`,
  `SecurityConfig`) más allá de lo que se ejercita por HTTP. Sigue siendo el
  hueco que ya señalaban los reportes 003 y 008.
- **El servidor de pruebas queda con la VM encendida**, con la rama
  `security/logout-revoca-familia` desplegada (no `develop`) y con las cuentas
  que dejó esta tarea: `qa024.*@trabajito.test` y las `qa.sesion.*` /
  `qa.sesion.otro.*` del script de regresión.
