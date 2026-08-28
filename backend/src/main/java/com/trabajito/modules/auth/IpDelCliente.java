package com.trabajito.modules.auth;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Resuelve la IP de origen de una peticion, para el conteo por IP del freno de
 * fuerza bruta (ADR-0010).
 *
 * <p><b>Por defecto NO se confia en {@code X-Forwarded-For}.</b> Esa cabecera
 * la pone cualquiera: si se leyera sin mas, un atacante mandaria una IP
 * distinta en cada peticion y el limite por IP no valdria nada. Solo se activa
 * ({@code trabajito.login.confiar-en-forwarded-for=true}) cuando delante hay un
 * proxy inverso de confianza que la sobrescribe — si no, la IP real es la de la
 * conexion ({@code getRemoteAddr}).
 */
@Component
public class IpDelCliente {

    private final boolean confiarEnForwardedFor;

    public IpDelCliente(
            @Value("${trabajito.login.confiar-en-forwarded-for:false}") boolean confiar) {
        this.confiarEnForwardedFor = confiar;
    }

    public String de(HttpServletRequest req) {
        if (confiarEnForwardedFor) {
            String xff = req.getHeader("X-Forwarded-For");
            if (xff != null && !xff.isBlank()) {
                // Formato: "cliente, proxy1, proxy2" -> la primera es el cliente.
                return xff.split(",")[0].trim();
            }
        }
        String remota = req.getRemoteAddr();
        return remota == null || remota.isBlank() ? "desconocida" : remota;
    }
}
