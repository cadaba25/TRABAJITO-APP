---
id: 009
titulo: "Errores de cliente devuelven HTTP 500 y no se registra nada en el log"
estado: hecho
agente: "backend-agent"
creada: 2026-08-21
rama: "fix/errores-http-no-mapeados"
---

## Objetivo

Cualquier error que no sea una `ApiException` acaba en
`GlobalExceptionHandler.handleGeneric(Exception)` → **HTTP 500 "Error interno
del servidor"**, incluidos errores que son claramente culpa del cliente (404,
405, 400). Peor: ese handler **no loguea nada**, así que en el servidor no
queda ni rastro.

Verificado contra el servidor real (tarea 006). Todos estos devolvieron
`500 {"error":"Internal Server Error","message":"Error interno del servidor"}`:

| Petición | Debería ser |
|---|---|
| `GET /api/no-existe` | 404 |
| `GET /api/cartera/recargar` (es POST) | 405 |
| `POST /api/cartera/recargar` con cuerpo `no soy json` | 400 |
| `POST /api/cartera/recargar` con `{"monto":"mil"}` | 400 |
| `POST /api/cartera/recargar` con `{}` (monto nulo) | 400 |
| `POST /api/cartera/recargar` con `{"monto":99999999999999999999}` | 400 |
| `GET /api/trabajos/no-es-uuid` | 400 |
| `POST /api/auth/registro` con `"rol":"SUPERJEFE"` | 400 |
| `POST /api/postulaciones` con `{"mensaje":"sin id"}` (trabajoId nulo) | 400 |
| `POST /api/calificaciones` con `{"estrellas":5}` (trabajoId nulo) | 400 |
| `POST /api/auth/login` de un usuario suspendido (`activo=false`) | 401/403 con mensaje |

Comprobación de que el log está mudo: tras provocar varios de estos 500,
`docker compose logs api --since 5m` devolvió **0 líneas**. Los únicos errores
que sí aparecen en el log son los que Hibernate registra por su cuenta
(violaciones de constraint). Un 500 en producción sería invisible.

Los `null` que revientan tienen una causa concreta: **11 de los 15
`@RequestBody` de los controllers no llevan `@Valid`**, así que las
anotaciones `@NotNull`/`@Positive`/`@Min`/`@Max` declaradas en los records de
request son código muerto. Por ejemplo `PagoController.recargar` recibe
`RecargaRequest(@NotNull @Positive BigDecimal monto)` sin `@Valid` → llega
`monto=null` → `monto.signum()` lanza NPE → 500.

Los que sí llevan `@Valid` (`registro`, `login`, `crear trabajo`,
`actualizar perfil`) responden 400 con el detalle por campo, que es
justamente el comportamiento correcto:

```
POST /api/trabajos  {"titulo":"   ","descripcion":"x"}
-> 400 {"error":"Bad Request","message":"Datos inválidos",
        "fields":{"titulo":"must not be blank"}, ...}
```

Importa porque cuando Flutter consuma esta API (ADR-0002) no podrá distinguir
"me equivoqué al enviar" de "el servidor está caído", y no habrá forma de
diagnosticar un incidente sin logs.

## Contexto relevante

- `backend/src/main/java/com/trabajito/common/exception/GlobalExceptionHandler.java`
- Controllers con `@RequestBody` sin `@Valid`: `admin`, `calificaciones`,
  `chats` (×3), `evidencias`, `pagos`, `postulaciones`, `reportes`,
  `trabajos` (`reservar-pago`, `solicitar-correccion`).
- `docs/api.md` — si se cambian los códigos de respuesta hay que actualizarlo.
- `docs/agent-reports/006-flujos-negocio-contra-postgres.md`

## Criterios de aceptación

- [ ] Cada fila de la tabla de arriba devuelve el código que le corresponde,
      con el mismo formato JSON de error que ya usa el proyecto
      (`{timestamp, status, error, message, fields?}`).
- [ ] `handleGeneric` **loguea** el stacktrace (nivel ERROR) antes de
      responder, sin exponer el detalle interno en el cuerpo de la respuesta.
- [ ] `@Valid` añadido donde falte, o validación explícita equivalente en el
      servicio. Un `null` en un campo obligatorio nunca debe llegar a
      producir un NPE.
- [ ] Un `POST` sin token a un endpoint protegido responde **401**, no 403 con
      cuerpo vacío (hoy `GET /api/auth/yo` sin token sí da 401, pero
      `POST /api/cartera/recargar` sin token da 403 vacío — la app no puede
      decidir si reautenticar).
- [ ] `bash backend/scripts/prueba-flujo-negocio.sh` deja de reportar
      `BUG-009`.

## Notas del agente que la ejecuta

Ojo con dos detalles al tocar `GlobalExceptionHandler`:

1. `@ExceptionHandler(Exception.class)` también captura las excepciones de
   Spring MVC (`NoResourceFoundException`, `HttpRequestMethodNotSupportedException`,
   `HttpMessageNotReadableException`, `MethodArgumentTypeMismatchException`).
   Extender `ResponseEntityExceptionHandler` es la vía estándar, pero cambia
   el formato del cuerpo por defecto: hay que sobreescribir `handleExceptionInternal`
   para conservar el JSON actual, o declarar handlers explícitos.
2. El caso del login de un usuario suspendido es una `DisabledException` de
   Spring Security, no una `BadCredentialsException`; el handler actual solo
   contempla la segunda. Decidir qué mensaje se devuelve (revelar "cuenta
   suspendida" da información a un atacante — consultar con `security-agent`).

**Añadido por `security-agent` al cerrar la tarea 008 (2026-08-21):**

3. Una de las filas de la tabla de arriba ya **no** aplica: `POST
   /api/auth/registro` con `"rol":"SUPERJEFE"` ahora devuelve **400** con
   `{"message":"Datos inválidos","fields":{"rol":"El rol debe ser TRABAJADOR o
   EMPLEADOR"}}`. No se tocó `GlobalExceptionHandler` para conseguirlo: el
   enum `RolPublico` deserializa a `null` cualquier valor no permitido y el
   `@NotNull` del DTO hace el resto (ADR-0005). Los otros 10 casos siguen
   igual. En `prueba-flujo-negocio.sh` esa comprobación ya perdió la marca
   `BUG-009`, así que si vuelve a dar 500 el script lo reportará como
   regresión, no como fallo conocido.
4. Sobre el punto 2 (login de cuenta suspendida), la respuesta de
   `security-agent`: **devolver el mismo 401 y el mismo mensaje que las
   credenciales incorrectas.** Hoy el 500 ya distingue una cuenta suspendida
   de una contraseña mala, que es justo la fuga que hay que cerrar; el motivo
   real ("tu cuenta fue suspendida") debe llegar al usuario por un canal
   autenticado o por soporte, no en la respuesta de un endpoint público. Deja
   el detalle en el log del servidor, que es donde hace falta.

**Cierre por `backend-agent` (2026-08-26):**

5. Hecho. Los 8 casos que el script marcaba `BUG-009` y el login de cuenta
   suspendida devuelven ya el código correcto contra el servidor real; el
   script pasa a **155 OK / 0 fallos conocidos / 0 inesperados**. Los cinco
   criterios de aceptación quedan cumplidos (el del `"rol":"SUPERJEFE"` ya lo
   había cerrado la tarea 008 y sigue verde). Detalle, respuestas reales y
   evidencia del log en
   `docs/agent-reports/009-errores-no-mapeados-devuelven-500.md`.
6. Se decidió **no** extender `ResponseEntityExceptionHandler` (punto 1 de
   estas notas): habría cambiado el cuerpo a `ProblemDetail` (RFC 7807). Se
   declararon handlers explícitos y el formato
   `{timestamp,status,error,message,fields?}` se conserva — ahora también en
   los 401/403 que emite la cadena de filtros de Spring Security, que antes
   respondían con el cuerpo vacío. Registrado como **ADR-0008**.
7. Sobre el punto 2/4 (cuenta suspendida): implementado tal cual lo pidió
   `security-agent`. Ojo a un detalle de implementación: `UsuarioPrincipal`
   devuelve `activo` tanto en `isEnabled()` como en `isAccountNonLocked()`, así
   que Spring lanza `LockedException` **antes** que `DisabledException`. El
   handler cubre las dos (y el resto de `AuthenticationException`), no solo la
   que citaba la tarea.
8. **Toca `config/SecurityConfig.java`** (un `exceptionHandling(...)` con los
   dos handlers nuevos). Requiere revisión de `security-agent` antes de
   mergear, según los límites de dominio.
