package com.trabajito.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * Genera y valida los JWT de <b>acceso</b>.
 *
 * <p>Desde la tarea 015 (ADR-0010) este token es de vida corta (15 min por
 * defecto, antes 7 días) y NO es el que mantiene la sesión: eso lo hace el
 * refresh token, que sí es revocable
 * ({@code com.trabajito.modules.auth.RefreshTokenService}). Un JWT firmado no
 * se puede invalidar antes de que caduque; por eso la ventana es corta.
 *
 * <p><b>Nota para la tarea 012 (doble rol).</b> El token lleva el rol en un
 * único claim {@code rol} — igual que antes, no se cambia aquí. Es seguro
 * cambiarlo cuando esa tarea decida el modelo: <b>ese claim es informativo</b>,
 * la autorización NO lo lee. {@link JwtAuthFilter} carga al usuario de la BD en
 * cada petición y las authorities salen de {@code Usuario.rol}, así que pasar a
 * un claim {@code roles} (lista) es un cambio local a esta clase.
 */
@Service
public class JwtService {

    private final SecretKey key;
    private final long expirationMs;

    public JwtService(
            @Value("${trabajito.jwt.secret}") String secret,
            // Nombre nuevo (ADR-0010) con el viejo como respaldo, para que un
            // despliegue que aun exporte JWT_EXPIRATION_MS no se quede sin
            // configuracion al actualizar.
            @Value("${trabajito.jwt.access-expiration-ms:${trabajito.jwt.expiration-ms:900000}}")
            long expirationMs) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMs = expirationMs;
    }

    /** Vida del token de acceso, en segundos (va en la respuesta de login). */
    public long expiracionSegundos() {
        return expirationMs / 1000;
    }

    /** Crea un token con el id del usuario como 'subject' y su rol como claim. */
    public String generarToken(String usuarioId, String correo, String rol) {
        Date ahora = new Date();
        return Jwts.builder()
                .subject(usuarioId)
                .claim("correo", correo)
                .claim("rol", rol)
                .issuedAt(ahora)
                .expiration(new Date(ahora.getTime() + expirationMs))
                .signWith(key)
                .compact();
    }

    public String extraerUsuarioId(String token) {
        return parse(token).getSubject();
    }

    public boolean esValido(String token) {
        try {
            parse(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private Claims parse(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
