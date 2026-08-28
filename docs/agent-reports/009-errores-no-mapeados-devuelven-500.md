---
id: 009
tarea: docs/agent-tasks/009-errores-no-mapeados-devuelven-500.md
agente: "backend-agent"
fecha: 2026-08-26
---

## Objetivo (copiado de la tarea)

Cualquier error que no fuera una `ApiException` acababa en
`GlobalExceptionHandler.handleGeneric(Exception)` → **HTTP 500 "Error interno
del servidor"**, incluidos errores que son claramente culpa del cliente (404,
405, 400). Peor: ese handler **no logueaba nada**, así que en el servidor no
quedaba ni rastro. Además, `POST /api/auth/login` de una cuenta suspendida
devolvía 500, lo que permitía distinguir "cuenta suspendida" de "contraseña
incorrecta" desde un endpoint público.

## Cambios realizados

1. **`GlobalExceptionHandler` reescrito**: de 4 handlers a 16, uno por familia
   de fallo (404 ruta inexistente, 405 método, 400 cuerpo ilegible / tipo
   inválido / validación / parámetro ausente, 401 autenticación, 403
   autorización, 406/415 negociación de contenido, 409 integridad de BD, 413
   subida, 500 el resto). Se declararon a mano en vez de extender
   `ResponseEntityExceptionHandler` para no cambiar el cuerpo de error a
   `ProblemDetail` (RFC 7807) — ver ADR-0008.
2. **Logging en todos los caminos**: 5xx con stacktrace a nivel `ERROR`, 4xx
   en una línea a nivel `DEBUG`, fallos de autenticación a `INFO` (y `WARN`
   con el correo cuando la cuenta está suspendida). El cuerpo de la respuesta
   sigue sin exponer detalle interno.
3. **`RespuestaError` (nuevo)**: construye el cuerpo
   `{timestamp,status,error,message,fields?}` y sabe escribirlo directamente
   en la respuesta HTTP. Lo comparten el `@RestControllerAdvice` y los
   handlers de Spring Security.
4. **`ManejadoresSeguridadHttp` (nuevo) + `SecurityConfig`**: un
   `AuthenticationEntryPoint` (401 con JSON) y un `AccessDeniedHandler` (403
   con JSON) sustituyen al `Http403ForbiddenEntryPoint` por defecto, que
   respondía **403 con cuerpo vacío** a quien llegaba sin token.
5. **`@Valid` en los 11 `@RequestBody` que no lo tenían** (admin ×2,
   calificaciones, chats ×3, evidencias, pagos, postulaciones, reportes,
   trabajos ×4) y las anotaciones de Bean Validation que faltaban en los
   records de request cuyos campos son `NOT NULL` en la BD: `PostularRequest.
   trabajoId`, `CrearReporteRequest.motivo`, `EvidenciaRequest.texto`,
   `MensajeRequest.contenido`, `PagoRequest.monto`, `TiempoRequest.tiempo`.
6. **`AuthService.login`**: captura `DisabledException`/`LockedException` para
   dejar el motivo real en el log del servidor y relanza; el cliente recibe el
   mismo 401 que con una contraseña mala.
7. **`MapeoErroresHttpTest` (nuevo, 12 tests)**: primer test de la capa HTTP
   del backend (MockMvc + H2, sin Docker), uno por caso de esta tarea.
8. **`prueba-flujo-negocio.sh`**: las 10 comprobaciones marcadas `BUG-009`
   pierden la marca (pasan a ser regresión) y se añaden 11 comprobaciones
   nuevas (cuerpo vacío → 400, XML → 415, el 401 trae JSON con `message`, y el
   bloque completo del login de una cuenta suspendida).
9. **Docs**: ADR-0008, sección de errores en `docs/api.md` y en
   `backend/README.md`, snapshot actualizado.

## Tabla antes / después (respuestas reales contra el servidor)

"Antes" = ejecución del script de regresión del 2026-08-26 antes de tocar
nada (8 comprobaciones marcadas `BUG-009`). "Después" = cuerpo literal
devuelto por el backend desplegado en la VM con este commit.

| Caso | Antes | Después | Cuerpo real ahora |
|---|---|---|---|
| `POST /api/cartera/recargar` **sin token** | 403 (cuerpo vacío) | **401** | `{"status":401,"error":"Unauthorized","message":"No autenticado. Inicia sesion para continuar."}` |
| `POST /api/cartera/recargar` `{"monto":"mil"}` | 500 | **400** | `{"status":400,"message":"Datos inválidos","fields":{"monto":"El valor no tiene el formato esperado"}}` |
| `GET /api/no-existe` | 500 | **404** | `{"status":404,"message":"La ruta solicitada no existe: GET /api/no-existe"}` |
| `GET /api/cartera/recargar` (es POST) | 500 | **405** + `Allow: POST` | `{"status":405,"message":"Metodo GET no permitido en esta ruta. Usa: POST"}` |
| `POST /api/cartera/recargar` body `no soy json` | 500 | **400** | `{"status":400,"message":"El cuerpo de la peticion no es un JSON valido"}` |
| `GET /api/trabajos/no-es-uuid` | 500 | **400** | `{"status":400,"message":"El valor de 'id' no es un UUID valido","fields":{"id":"formato invalido"}}` |
| `POST /api/postulaciones` `{"mensaje":"sin id"}` | 500 | **400** | `{"status":400,"message":"Datos inválidos","fields":{"trabajoId":"Indica el trabajo al que te postulas"}}` |
| `POST /api/calificaciones` `{"estrellas":5}` | 404 | **400** | `{"status":400,"message":"Datos inválidos","fields":{"trabajoId":"must not be null"}}` |
| `POST /api/auth/login` de cuenta suspendida | 500 (distinguible de una contraseña mala) | **401**, idéntico a contraseña mala | `{"status":401,"error":"Unauthorized","message":"Correo o contraseña incorrectos"}` |

Extras verificados en la misma pasada (no estaban en la lista de 8, pero
también eran 500 o quedaban indefinidos):

| Caso | Después |
|---|---|
| `POST /api/cartera/recargar` `{}` (monto nulo) | `400` + `fields.monto` |
| `POST /api/cartera/recargar` sin cuerpo | `400` "Falta el cuerpo de la peticion" |
| `POST /api/cartera/recargar` con `Content-Type: application/xml` | `415` |
| `POST /api/trabajos` con `categoria` de 300 caracteres (columna `varchar(255)`) | `409` (antes 500), con el stacktrace en el log |

## ¿Se loguea? Sí — evidencia del log real del servidor

`docker compose logs api` tras provocar los mismos casos (antes de este
arreglo, la misma consulta devolvía **0 líneas**):

```
2026-08-26T23:49:32.730Z  INFO ... c.t.c.e.ManejadoresSeguridadHttp  : 401 POST /api/cartera/recargar - sin autenticacion valida: Full authentication is required to access this resource
2026-08-26T23:49:32.894Z DEBUG ... c.t.c.exception.GlobalExceptionHandler : 400 POST /api/cartera/recargar - HttpMessageNotReadableException: JSON parse error: Cannot deserialize value of type `java.math.BigDecimal` from String "mil"
2026-08-26T23:49:32.940Z DEBUG ... c.t.c.exception.GlobalExceptionHandler : 404 GET /api/no-existe - NoResourceFoundException: No static resource api/no-existe.
2026-08-26T23:49:32.975Z DEBUG ... c.t.c.exception.GlobalExceptionHandler : 405 GET /api/cartera/recargar - HttpRequestMethodNotSupportedException: Request method 'GET' is not supported
2026-08-26T23:49:33.046Z DEBUG ... c.t.c.exception.GlobalExceptionHandler : 400 GET /api/trabajos/no-es-uuid - MethodArgumentTypeMismatchException: Failed to convert value of type 'java.lang.String' to required type 'java.util.UUID'; Invalid UUID string: no-es-uuid
2026-08-26T23:49:33.102Z DEBUG ... c.t.c.exception.GlobalExceptionHandler : 400 POST /api/postulaciones - MethodArgumentNotValidException: ... default message [Indica el trabajo al que te postulas]
```

El camino de **ERROR con stacktrace** (el que importa para un 500 real) se
comprobó forzando una violación de integridad en la BD:

```
2026-08-26T23:50:02.108Z ERROR ... c.t.c.exception.GlobalExceptionHandler : 409 POST /api/trabajos - violacion de integridad en la BD

org.springframework.dao.DataIntegrityViolationException: could not execute statement
  [ERROR: value too long for type character varying(255)] [insert into trabajos ...]
    at org.springframework.orm.jpa.vendor.HibernateJpaDialect.convertHibernateAccessException(...)
    at org.springframework.orm.jpa.JpaTransactionManager.doCommit(...)
    ...
```

Y el del login de una cuenta suspendida, que es la parte que **no** viaja al
cliente:

```
WARN  com.trabajito.modules.auth.AuthService : Login rechazado: la cuenta ...@trabajito.local está suspendida (LockedException)
INFO  c.t.c.exception.GlobalExceptionHandler : 401 POST /api/auth/login - LockedException: User account is locked
```

`logging.level.com.trabajito: DEBUG` ya estaba en `application.yml`, así que
los 4xx se ven sin tocar configuración. Si algún despliegue sube ese nivel a
`INFO`, los 4xx dejarán de verse **a propósito** (son ruido de cliente); los
5xx y los fallos de auth se seguirán viendo.

## Archivos modificados

- `backend/src/main/java/com/trabajito/common/exception/GlobalExceptionHandler.java` (reescrito)
- `backend/src/main/java/com/trabajito/common/exception/RespuestaError.java` (nuevo)
- `backend/src/main/java/com/trabajito/common/exception/ManejadoresSeguridadHttp.java` (nuevo)
- `backend/src/main/java/com/trabajito/config/SecurityConfig.java` (**requiere revisión de `security-agent`**)
- `backend/src/main/java/com/trabajito/modules/auth/AuthService.java`
- `backend/src/main/java/com/trabajito/modules/{admin,calificaciones,chats,evidencias,pagos,postulaciones,reportes,trabajos}/*Controller.java`
- `backend/src/test/java/com/trabajito/common/exception/MapeoErroresHttpTest.java` (nuevo)
- `backend/scripts/prueba-flujo-negocio.sh`
- `backend/README.md`, `docs/api.md`, `docs/decisions.md` (ADR-0008),
  `docs/agent-context/repo-snapshot.md`, `docs/agent-tasks/009-*.md`

## Decisiones tomadas

- **Handlers explícitos, no `ResponseEntityExceptionHandler`.** La vía
  estándar habría cambiado el cuerpo de error a `ProblemDetail` (RFC 7807),
  que no es el formato que publica `docs/api.md`. Justificación completa en
  ADR-0008.
- **Cuenta suspendida = mismo 401 y mismo mensaje que contraseña incorrecta**,
  tal como pidió `security-agent` al cerrar la tarea 008. El motivo real se
  queda en el log (`WARN` con el correo).
- **`DataIntegrityViolationException` → 409, no 500.** Es un choque con el
  estado existente, no un fallo del servidor. Se sigue logueando como `ERROR`
  **con stacktrace** porque casi siempre delata una validación que faltaba
  antes en el servicio.
- **Validaciones nuevas solo donde la columna es `NOT NULL`.** No se
  endurecieron campos opcionales (por ejemplo `EvidenciaRequest.archivoUrl` o
  `CancelarRequest.motivo`) para no cambiar contratos fuera del alcance de
  esta tarea.
- **No se tocó el `@JsonCreator`/`RolPublico` de la tarea 008.** Se comprobó
  que `"rol":"SUPERJEFE"` sigue devolviendo 400 con `fields.rol` (está en el
  script como test de regresión, sin marca de bug).

## Problemas encontrados

- **La cuenta suspendida lanza `LockedException`, no `DisabledException`**
  como suponía la tarea: `UsuarioPrincipal` devuelve `activo` en
  `isEnabled()` **y** en `isAccountNonLocked()`, y Spring evalúa el bloqueo
  antes. El handler cubre toda `AuthenticationException`, así que da igual
  cuál de las dos llegue.
- **El 401/403 de la cadena de filtros no lo ve un `@RestControllerAdvice`**:
  ocurre antes del `DispatcherServlet`. De ahí que hicieran falta el
  `AuthenticationEntryPoint` y el `AccessDeniedHandler`, y que el cuerpo se
  extrajera a `RespuestaError` para no tener dos formatos de error.
- `GET /api/no-existe` **sin token** responde 401, no 404: la cadena de
  seguridad rechaza antes de que exista un handler. Es correcto (no revelar
  qué rutas existen a un anónimo), pero conviene saberlo al probar a mano.
- Los mensajes por defecto de Bean Validation salen en inglés
  (`"must not be null"`) salvo que el record declare `message`. Se dejó así
  donde ya existía la anotación para no cambiar textos de otra tarea.

## Tests ejecutados

- Unitarios, en la máquina de desarrollo (Maven 3.9.16, JDK 21 de Android
  Studio, `-Dtest='!IntegridadCarteraConcurrenteTest'`):
  **71/71 pasan, 0 skipped** (59 previos + 12 nuevos de
  `MapeoErroresHttpTest`). `mvn -q compile` limpio.
- Integración contra el servidor real (VM Ubuntu, PostgreSQL 16 y la imagen
  reconstruida con este commit):
  `COMPOSE_DIR=$HOME/trabajito/backend bash backend/scripts/prueba-flujo-negocio.sh`
  → **155 OK / 0 fallos conocidos / 0 fallos inesperados**, cuadre contable
  correcto para los 7 usuarios de prueba. Antes de este cambio: 137 OK / 8
  fallos conocidos (todos `BUG-009`) / 0 inesperados.
- `IntegridadCarteraConcurrenteTest` (Testcontainers) **no se ejecutó**: solo
  corre en el servidor Ubuntu (en Windows, Docker Desktop responde 400 al
  cliente de Testcontainers). Este cambio no toca la ruta de dinero, y el
  cuadre contable del script de integración —que sí corrió en el servidor—
  pasó entero.
- Comprobación manual de los 9 casos de la tabla y del log, con `curl` y
  `docker compose logs api` dentro de la VM (salidas pegadas arriba).

## Pendientes

- **Revisión de `security-agent`** antes de mergear: este cambio toca
  `config/SecurityConfig.java` y el comportamiento de 401/403.
- **Mensajes de validación en español.** Los que no declaran `message` salen
  como `"must not be null"`. Candidato a tarea pequeña (o a un
  `ValidationMessages.properties`).
- **`GET /api/postulaciones` sin `trabajoId`** ahora responde 400 genérico
  ("Falta un dato obligatorio en la peticion") sin decir qué parámetro falta.
  Mejorable.
- **Rate limiting en `/api/auth/login`.** Este arreglo cierra la fuga de
  información, pero no impide probar contraseñas en bucle: el login sigue sin
  límite de intentos. No era alcance de esta tarea; conviene abrir una para
  `security-agent`.
- **`GET /api/auth/yo` sigue devolviendo 401 desde el controller** (la ruta es
  `permitAll`), no desde la cadena de filtros. El código y el cuerpo coinciden
  con el resto, pero son dos caminos distintos para el mismo resultado.
- **Adoptar `ProblemDetail`/RFC 7807** si algún día se quiere el formato
  estándar; hoy sería un cambio de contrato para todos los clientes futuros y
  necesita su propio ADR.
