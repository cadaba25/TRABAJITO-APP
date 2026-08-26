package com.trabajito.common.exception;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;

import java.io.IOException;

/**
 * Respuestas de error de la cadena de filtros de Spring Security (tarea 009).
 *
 * <p>Sin esto, una peticion sin token a un endpoint protegido caia en el
 * {@code Http403ForbiddenEntryPoint} por defecto y devolvia <b>403 con el
 * cuerpo vacio</b>. El cliente no puede distinguir "no has iniciado sesion"
 * (hay que reautenticar) de "has iniciado sesion pero esto no es tuyo" (no
 * sirve de nada reintentar). {@code GET /api/auth/yo} si daba 401 solo porque
 * esa ruta es {@code permitAll} y el 401 lo lanzaba el controller.
 *
 * <p>Los dos handlers escriben el mismo JSON que
 * {@link GlobalExceptionHandler}: el formato de error de la API es uno solo
 * (ADR-0008), venga del filtro o del controller.
 */
@Configuration
public class ManejadoresSeguridadHttp {

    private static final Logger log = LoggerFactory.getLogger(ManejadoresSeguridadHttp.class);

    /** 401 cuando no hay credenciales validas (sin token, token invalido o caducado). */
    @Bean
    public AuthenticationEntryPoint puntoDeEntradaNoAutenticado() {
        return (HttpServletRequest req, HttpServletResponse res, org.springframework.security.core.AuthenticationException ex) -> {
            log.info("401 {} {} - sin autenticacion valida: {}", req.getMethod(),
                    req.getRequestURI(), ex.getMessage());
            escribir(res, HttpStatus.UNAUTHORIZED,
                    "No autenticado. Inicia sesion para continuar.");
        };
    }

    /** 403 cuando si hay usuario autenticado pero le falta el rol/permiso. */
    @Bean
    public AccessDeniedHandler manejadorAccesoDenegado() {
        return (HttpServletRequest req, HttpServletResponse res, org.springframework.security.access.AccessDeniedException ex) -> {
            log.debug("403 {} {} - acceso denegado: {}", req.getMethod(), req.getRequestURI(),
                    ex.getMessage());
            escribir(res, HttpStatus.FORBIDDEN, "No tienes permiso para esta accion");
        };
    }

    private static void escribir(HttpServletResponse res, HttpStatus status, String mensaje)
            throws IOException {
        if (res.isCommitted()) return;
        RespuestaError.escribir(res, status, mensaje);
    }
}
