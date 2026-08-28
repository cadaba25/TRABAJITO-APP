package com.trabajito.common.exception;

import com.fasterxml.jackson.databind.exc.MismatchedInputException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.AccountExpiredException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.CredentialsExpiredException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpMediaTypeNotAcceptableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Traduce las excepciones a respuestas JSON uniformes (ADR-0008).
 * Estructura: <code>{ timestamp, status, error, message, fields? }</code>.
 *
 * <p><b>Por que hay tantos handlers explicitos (tarea 009).</b> Antes solo
 * existian cuatro; todo lo demas caia en {@code handleGeneric(Exception)} y
 * salia como <b>500</b>, incluidos errores que son claramente culpa del
 * cliente: una ruta que no existe, un metodo no permitido, un JSON malformado
 * o un UUID invalido en la URL. Spring MVC ya lanza una excepcion distinta
 * para cada uno de esos casos, pero {@code @ExceptionHandler(Exception.class)}
 * las capturaba todas antes de que nadie las mirara.
 *
 * <p>La alternativa estandar es extender {@code ResponseEntityExceptionHandler},
 * pero eso cambia el cuerpo por el formato {@code ProblemDetail} (RFC 7807) y
 * habria roto el contrato que ya publica {@code docs/api.md}. Se declaran los
 * handlers a mano para conservar el cuerpo actual.
 *
 * <p><b>Logging.</b> Ningun error se responde en silencio:
 * <ul>
 *   <li><b>5xx</b> - {@code ERROR} con stacktrace completo (el cuerpo de la
 *       respuesta sigue sin exponer el detalle interno).</li>
 *   <li><b>4xx</b> - {@code DEBUG} en una linea, sin stacktrace: son errores
 *       normales de cliente y no deben inundar el log.</li>
 *   <li>Fallos de autenticacion - {@code INFO}, para que quede rastro de los
 *       intentos sin llenar el log.</li>
 * </ul>
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /** Mismo texto para credenciales malas y cuenta suspendida: ver {@link #handleAuth}. */
    static final String CREDENCIALES_INVALIDAS = "Correo o contraseña incorrectos";

    // -- Errores de negocio --------------------------------------------
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Map<String, Object>> handleApi(ApiException ex, HttpServletRequest req) {
        return responder(ex.getStatus(), ex.getMessage(), null, req, ex);
    }

    /**
     * Demasiados intentos de login (ADR-0010). Es 429 con la cabecera
     * {@code Retry-After}, para que un cliente honesto sepa cuándo reintentar.
     * Se loguea en {@code INFO} (no DEBUG): un pico de estos es justo lo que
     * hay que poder ver, igual que los 401 de autenticación.
     */
    @ExceptionHandler(IntentosExcedidosException.class)
    public ResponseEntity<Map<String, Object>> handleIntentos(IntentosExcedidosException ex,
                                                              HttpServletRequest req) {
        log.info("429 {} {} - {}", req.getMethod(), req.getRequestURI(), ex.getMessage());
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .header("Retry-After", String.valueOf(ex.getRetryAfterSegundos()))
                .body(RespuestaError.cuerpo(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage(), null));
    }

    // -- Autenticacion / autorizacion ----------------------------------
    /**
     * Todo fallo de autenticacion responde <b>401</b> con el MISMO mensaje.
     *
     * <p>Incluye deliberadamente {@link DisabledException} (cuenta suspendida):
     * antes reventaba en 500, y ese 500 permitia distinguir desde un endpoint
     * publico "esta cuenta existe y esta suspendida" de "la contraseña esta
     * mal" - enumeracion de cuentas gratis. Decision de {@code security-agent}
     * al cerrar la tarea 008: el motivo real se queda en el log del servidor y
     * le llega al usuario por soporte, no en la respuesta.
     */
    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<Map<String, Object>> handleAuth(AuthenticationException ex,
                                                          HttpServletRequest req) {
        boolean esDeCredenciales = ex instanceof BadCredentialsException
                || ex instanceof UsernameNotFoundException
                || ex instanceof DisabledException
                || ex instanceof LockedException
                || ex instanceof AccountExpiredException
                || ex instanceof CredentialsExpiredException;
        String mensaje = esDeCredenciales
                ? CREDENCIALES_INVALIDAS
                : "No autenticado. Inicia sesion para continuar.";
        // INFO (no DEBUG): un pico de estos es justo lo que hay que poder ver.
        log.info("401 {} {} - {}: {}", req.getMethod(), req.getRequestURI(),
                ex.getClass().getSimpleName(), ex.getMessage());
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(RespuestaError.cuerpo(HttpStatus.UNAUTHORIZED, mensaje, null));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<Map<String, Object>> handleDenied(AccessDeniedException ex,
                                                            HttpServletRequest req) {
        return responder(HttpStatus.FORBIDDEN, "No tienes permiso para esta accion", null, req, ex);
    }

    // -- Validacion de entrada -----------------------------------------
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidation(MethodArgumentNotValidException ex,
                                                                HttpServletRequest req) {
        Map<String, String> campos = ex.getBindingResult().getFieldErrors().stream()
                .collect(Collectors.toMap(FieldError::getField,
                        f -> f.getDefaultMessage() == null ? "invalido" : f.getDefaultMessage(),
                        (a, b) -> a));
        return responder(HttpStatus.BAD_REQUEST, "Datos inválidos", campos, req, ex);
    }

    /** Validacion sobre parametros sueltos del metodo (@RequestParam/@PathVariable). */
    @ExceptionHandler(HandlerMethodValidationException.class)
    public ResponseEntity<Map<String, Object>> handleMetodo(HandlerMethodValidationException ex,
                                                            HttpServletRequest req) {
        return responder(HttpStatus.BAD_REQUEST, "Datos inválidos", null, req, ex);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConstraint(ConstraintViolationException ex,
                                                                HttpServletRequest req) {
        Map<String, String> campos = new LinkedHashMap<>();
        if (ex.getConstraintViolations() != null) {
            ex.getConstraintViolations().forEach(v ->
                    campos.put(String.valueOf(v.getPropertyPath()), v.getMessage()));
        }
        return responder(HttpStatus.BAD_REQUEST, "Datos inválidos",
                campos.isEmpty() ? null : campos, req, ex);
    }

    /**
     * Cuerpo ausente, no parseable o con un tipo imposible
     * ({@code {"monto":"mil"}}, un entero que no cabe en la columna, o
     * directamente texto que no es JSON).
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, Object>> handleCuerpoIlegible(
            HttpMessageNotReadableException ex, HttpServletRequest req) {
        Map<String, String> campos = null;
        String mensaje = "El cuerpo de la peticion no es un JSON valido";
        if (ex.getCause() instanceof MismatchedInputException mie && !mie.getPath().isEmpty()) {
            String campo = mie.getPath().stream()
                    .map(r -> r.getFieldName() == null ? "[" + r.getIndex() + "]" : r.getFieldName())
                    .collect(Collectors.joining("."));
            campos = Map.of(campo, "El valor no tiene el formato esperado");
            mensaje = "Datos inválidos";
        } else if (ex.getMessage() != null && ex.getMessage().startsWith("Required request body")) {
            mensaje = "Falta el cuerpo de la peticion";
        }
        return responder(HttpStatus.BAD_REQUEST, mensaje, campos, req, ex);
    }

    /** UUID/numero invalido en la ruta o en un query param. */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Map<String, Object>> handleTipo(MethodArgumentTypeMismatchException ex,
                                                          HttpServletRequest req) {
        String esperado = ex.getRequiredType() == null
                ? "valor valido" : ex.getRequiredType().getSimpleName() + " valido";
        return responder(HttpStatus.BAD_REQUEST,
                "El valor de '" + ex.getName() + "' no es un " + esperado,
                Map.of(ex.getName(), "formato invalido"), req, ex);
    }

    @ExceptionHandler({MissingServletRequestParameterException.class,
                       MissingRequestHeaderException.class,
                       MissingServletRequestPartException.class})
    public ResponseEntity<Map<String, Object>> handleFalta(Exception ex, HttpServletRequest req) {
        return responder(HttpStatus.BAD_REQUEST, "Falta un dato obligatorio en la peticion",
                null, req, ex);
    }

    // -- Protocolo HTTP ------------------------------------------------
    @ExceptionHandler({NoResourceFoundException.class, NoHandlerFoundException.class})
    public ResponseEntity<Map<String, Object>> handleNoExiste(Exception ex,
                                                              HttpServletRequest req) {
        return responder(HttpStatus.NOT_FOUND,
                "La ruta solicitada no existe: " + req.getMethod() + " " + req.getRequestURI(),
                null, req, ex);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<Map<String, Object>> handleMetodoNoPermitido(
            HttpRequestMethodNotSupportedException ex, HttpServletRequest req) {
        String permitidos = ex.getSupportedHttpMethods() == null ? ""
                : ex.getSupportedHttpMethods().stream().map(Object::toString)
                    .collect(Collectors.joining(", "));
        ResponseEntity.BodyBuilder resp = ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED);
        if (!permitidos.isEmpty()) resp = resp.header("Allow", permitidos);
        logar(HttpStatus.METHOD_NOT_ALLOWED, req, ex);
        return resp.body(RespuestaError.cuerpo(HttpStatus.METHOD_NOT_ALLOWED,
                "Metodo " + ex.getMethod() + " no permitido en esta ruta"
                        + (permitidos.isEmpty() ? "" : ". Usa: " + permitidos), null));
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<Map<String, Object>> handleMedia(HttpMediaTypeNotSupportedException ex,
                                                           HttpServletRequest req) {
        return responder(HttpStatus.UNSUPPORTED_MEDIA_TYPE,
                "Content-Type no soportado. Usa application/json", null, req, ex);
    }

    @ExceptionHandler(HttpMediaTypeNotAcceptableException.class)
    public ResponseEntity<Map<String, Object>> handleAccept(HttpMediaTypeNotAcceptableException ex,
                                                            HttpServletRequest req) {
        return responder(HttpStatus.NOT_ACCEPTABLE,
                "Esta API solo responde application/json", null, req, ex);
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<Map<String, Object>> handleSubida(MaxUploadSizeExceededException ex,
                                                            HttpServletRequest req) {
        return responder(HttpStatus.PAYLOAD_TOO_LARGE, "El archivo es demasiado grande",
                null, req, ex);
    }

    // -- Persistencia --------------------------------------------------
    /**
     * Choque contra una restriccion de la BD (unique, check, FK). Es 409 y no
     * 500: significa que el estado enviado no es compatible con el actual.
     * Se loguea como ERROR con stacktrace igualmente, porque casi siempre
     * indica una validacion que faltaba antes en el servicio.
     */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> handleIntegridad(DataIntegrityViolationException ex,
                                                                HttpServletRequest req) {
        log.error("409 {} {} - violacion de integridad en la BD", req.getMethod(),
                req.getRequestURI(), ex);
        return ResponseEntity.status(HttpStatus.CONFLICT).body(RespuestaError.cuerpo(
                HttpStatus.CONFLICT, "La operacion choca con los datos existentes", null));
    }

    // -- Ultimo recurso ------------------------------------------------
    /**
     * Cualquier cosa no prevista. SIEMPRE deja el stacktrace en el log: un 500
     * silencioso deja ciego a quien opere esto (era el segundo sintoma de la
     * tarea 009). El cuerpo sigue sin decir nada del detalle interno.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGeneric(Exception ex,
                                                             HttpServletRequest req) {
        log.error("500 {} {} - excepcion no controlada", req.getMethod(), req.getRequestURI(), ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(RespuestaError.cuerpo(
                HttpStatus.INTERNAL_SERVER_ERROR, "Error interno del servidor", null));
    }

    // -- Interno -------------------------------------------------------
    private ResponseEntity<Map<String, Object>> responder(HttpStatus status, String mensaje,
                                                          Object campos, HttpServletRequest req,
                                                          Exception ex) {
        logar(status, req, ex);
        return ResponseEntity.status(status).body(RespuestaError.cuerpo(status, mensaje, campos));
    }

    private void logar(HttpStatus status, HttpServletRequest req, Exception ex) {
        String metodo = req == null ? "?" : req.getMethod();
        String ruta = req == null ? "?" : req.getRequestURI();
        if (status.is5xxServerError()) {
            log.error("{} {} {} - {}", status.value(), metodo, ruta,
                    ex.getClass().getSimpleName(), ex);
        } else {
            // 4xx: una linea, sin stacktrace. Son errores de cliente normales.
            log.debug("{} {} {} - {}: {}", status.value(), metodo, ruta,
                    ex.getClass().getSimpleName(), ex.getMessage());
        }
    }
}
