package com.trabajito.security;

import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.usuarios.Usuario;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.UUID;

/** Utilidades para obtener al usuario autenticado en los servicios/controllers. */
public final class SecurityUtils {

    private SecurityUtils() {}

    public static UsuarioPrincipal principalActual() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UsuarioPrincipal p)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "No autenticado");
        }
        return p;
    }

    public static Usuario usuarioActual() {
        return principalActual().getUsuario();
    }

    public static UUID idActual() {
        return principalActual().getId();
    }
}
