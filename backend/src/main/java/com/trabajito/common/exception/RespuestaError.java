package com.trabajito.common.exception;

import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Cuerpo único de error de la API (ADR-0008).
 *
 * <p>Formato: <code>{timestamp, status, error, message, fields?}</code>. Vive
 * fuera de {@link GlobalExceptionHandler} porque hay dos productores de
 * errores: el {@code @RestControllerAdvice} (errores que ocurren dentro del
 * DispatcherServlet) y los handlers de Spring Security, que responden desde
 * la cadena de filtros, antes de que exista un controller. Los dos tienen que
 * escribir exactamente el mismo JSON: si no, el cliente tendría que saber
 * distinguir "me rechazó el filtro" de "me rechazó el controller".
 */
public final class RespuestaError {

    private RespuestaError() {
    }

    /** Construye el cuerpo. {@code campos} puede ser null (se omite la clave). */
    public static Map<String, Object> cuerpo(HttpStatus status, String mensaje, Object campos) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", Instant.now().toString());
        body.put("status", status.value());
        body.put("error", status.getReasonPhrase());
        body.put("message", mensaje);
        if (campos != null) body.put("fields", campos);
        return body;
    }

    /**
     * Escribe el cuerpo directamente en la respuesta HTTP. Se usa desde la
     * cadena de filtros de Spring Security, donde no hay un
     * {@code ResponseEntity} que devolver.
     *
     * <p>Se serializa a mano (sin Jackson) porque el mensaje lo controlamos
     * nosotros y así este camino no depende de que el {@code ObjectMapper}
     * esté disponible en el filtro.
     */
    public static void escribir(HttpServletResponse response, HttpStatus status, String mensaje)
            throws IOException {
        response.setStatus(status.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write(
                "{\"timestamp\":\"" + Instant.now() + "\","
                        + "\"status\":" + status.value() + ","
                        + "\"error\":\"" + escapar(status.getReasonPhrase()) + "\","
                        + "\"message\":\"" + escapar(mensaje) + "\"}");
    }

    private static String escapar(String s) {
        return s == null ? "" : s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
