---
id: 007
tarea: docs/agent-tasks/007-integridad-dinero-cartera-escrow.md
agente: backend-agent (implementación) + tech-lead (verificación y cierre)
fecha: 2026-08-21
---

> **Nota de proceso:** la sesión del `backend-agent` se cortó por límite de
> uso justo después de commitear el arreglo y el ADR, antes de escribir este
> reporte. El `tech-lead` retomó desde ahí: fijó la versión de Testcontainers
> que quedó sin commitear, desplegó al servidor, verificó de forma
> independiente y cerró la documentación. El código del arreglo es del
> `backend-agent`; la evidencia de abajo la produjo el `tech-lead`.

## Objetivo (copiado de la tarea)

Cerrar dos defectos que permitían **crear dinero de la nada**:

- **A (crítico):** lost update en `PagoService` — `saldo = saldo ± monto`
  leído y reescrito sin protección, con `READ COMMITTED`. Dos peticiones
  simultáneas se pisaban.
- **B (medio):** un monto de `0.005` no le cobraba nada al empleador pero se
  guardaba como `0.01` y el trabajador cobraba un centavo que nadie pagó.

## Cambios realizados

Enfoque completo y alternativas descartadas en **ADR-0006** (`docs/decisions.md`).
Resumen:

1. **Bloqueo pesimista** (`SELECT ... FOR UPDATE`) vía
   `@Lock(PESSIMISTIC_WRITE)` en `TrabajoRepository.findByIdParaActualizar` y
   `UsuarioRepository.findByIdParaActualizar`.
2. **Orden global de bloqueo para evitar deadlocks:** primero `trabajos`,
   después `usuarios`; y varias filas de `usuarios` siempre en orden
   ascendente de UUID. Con esas dos reglas el grafo de espera no puede tener
   ciclos.
3. **`@DynamicUpdate` en `Usuario`** — antes, editar el perfil o la
   reputación reescribía *todas* las columnas por dirty-checking, incluida
   `saldo` con un valor viejo. Era una segunda vía de pérdida de dinero, sin
   que nadie tocara la cartera.
4. **`CHECK (saldo >= 0)`** en la BD (`ck_usuarios_saldo_no_negativo`), como
   última línea de defensa independiente de Java.
5. **Validación de escala exacta** (`MontoDinero`): más de 2 decimales → 400.
   No se redondea en silencio, porque redondear en silencio *era* el defecto B.

## Archivos modificados

- `backend/src/main/java/com/trabajito/modules/pagos/PagoService.java`
- `backend/src/main/java/com/trabajito/modules/pagos/MontoDinero.java` (nuevo)
- `backend/src/main/java/com/trabajito/modules/trabajos/TrabajoService.java`
- `backend/src/main/java/com/trabajito/modules/trabajos/TrabajoRepository.java`
- `backend/src/main/java/com/trabajito/modules/usuarios/Usuario.java`
- `backend/src/main/java/com/trabajito/modules/usuarios/UsuarioRepository.java`
- `backend/src/main/java/com/trabajito/config/RestriccionSaldoNoNegativo.java` (nuevo)
- `backend/src/main/java/com/trabajito/modules/calificaciones/CalificacionService.java`
- `backend/src/main/java/com/trabajito/modules/postulaciones/PostulacionService.java`
- `backend/src/test/java/com/trabajito/modules/pagos/IntegridadCarteraConcurrenteTest.java` (nuevo)
- `backend/src/test/java/com/trabajito/modules/trabajos/TrabajoServiceTest.java`
- `backend/pom.xml` — Testcontainers **fijado a 1.20.6**: el que trae el BOM de
  Spring Boot 3.3.x (1.19.x) habla la API de Docker 1.32 y los Engine modernos
  la rechazan (*"Minimum supported API version is 1.44"*).
- `docs/decisions.md` — ADR-0006.

## Decisiones tomadas

Todas justificadas en ADR-0006, incluidas las **alternativas descartadas**
(`@Version` optimista, `UPDATE` atómico sin bloqueo, redondear en vez de
rechazar, `SERIALIZABLE`). Vale la pena destacar dos:

- **Se descartó `@Version` en `BaseEntity`** porque afectaba a las 11 tablas y
  obligaba a lógica de reintento en cada endpoint que mueve dinero; bajo la
  contención real que estábamos arreglando, degrada a reintentar hasta
  agotarse.
- **Se descartó redondear el monto** (`setScale(2, HALF_UP)`): redondear en
  silencio es exactamente lo que produjo el defecto B.

## Problemas encontrados

1. **Docker Desktop en la máquina de desarrollo (Windows) está caído** —
   `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine`.
   Por eso el test con Testcontainers **no se ha podido correr localmente**
   (ver "Pendientes"). La verificación se hizo contra el servidor Ubuntu, que
   es evidencia más fuerte de todos modos: es el entorno donde se reprodujo
   el bug original.
2. **Versión de Testcontainers incompatible** con los Docker Engine modernos
   (resuelto fijando 1.20.6).

## Tests ejecutados

### 1. Tests unitarios (máquina de desarrollo)

```
mvn test -Dtest='!IntegridadCarteraConcurrenteTest'
→ Tests run: 38, Failures: 0, Errors: 0  ·  BUILD SUCCESS
```
Antes de la tarea eran 34. `TrabajoServiceTest` subió a 19 tests (validación
de escala de montos).

### 2. Reproducción del ataque original (servidor Ubuntu, PostgreSQL real)

El ataque que antes creaba dinero: empleador con saldo **L. 1000.00**, dos
trabajos en `ASIGNADO`, dos `POST /api/trabajos/{id}/reservar-pago` de
`{"monto":1000}` **lanzados en paralelo**.

| | Antes (tarea 006) | Después (verificado hoy) |
|---|---|---|
| Respuestas HTTP | `200` y `200` | **`200` y `400`** |
| Escrows retenidos | 2 (de L.1000 c/u) | **1** |
| Saldo final del empleador | 0.00 con 2 escrows activos | **0.00 con 1 escrow** |
| Dinero | entró L.1000, salieron L.2000 | **cuadra** |

### 3. Script de regresión completo (servidor)

```
COMPOSE_DIR=$HOME/trabajito/backend bash backend/scripts/prueba-flujo-negocio.sh
```

| | Antes de la tarea 007 | Después |
|---|---|---|
| OK | 86 | **95** |
| Fallos conocidos | 19 | **10** |
| Fallos NO esperados | 0 | **0** |

**Cuadre contable (`usuarios.saldo == SUM(movimientos_cartera.monto)`):
pasa para los 7 usuarios de prueba.** Antes de esta tarea, 7 usuarios tenían
el saldo descuadrado respecto a su propio ledger (hasta −3000.00 de
diferencia).

Los 10 fallos conocidos que quedan son de las tareas **009** (errores de
cliente que devuelven 500) y **010** (cancelación unilateral tras la
entrega), ambas fuera del alcance de esta.

## Pendientes

- **`IntegridadCarteraConcurrenteTest` (Testcontainers) sigue sin ejecutarse.**
  Requiere Docker Desktop corriendo en la máquina de desarrollo, que hoy está
  caído. **No se ha verificado que este test pase, ni que falle sin el
  arreglo** — que era un criterio de aceptación de la tarea. La corrección
  está probada contra el servidor real (evidencia arriba), pero la red de
  seguridad automatizada todavía no se ha visto funcionar. Es lo primero que
  hay que correr cuando Docker vuelva.
- El `CHECK (saldo >= 0)` se aplica vía `RestriccionSaldoNoNegativo` porque el
  esquema lo genera Hibernate con `ddl-auto=update`. Cuando exista
  Flyway/Liquibase (pendiente conocido, tarea aparte), esto debería mudarse a
  una migración versionada.
- Sin probar todavía: WebSocket/chat, subida de archivos, resto del panel
  admin, expiración del JWT.
