package com.trabajito.modules.auth.dto;

import com.trabajito.modules.usuarios.dto.UsuarioResponse;

/**
 * Respuesta de login/registro/refresh.
 *
 * <p>Desde la tarea 015 (ADR-0010) la sesión tiene dos piezas:
 * <ul>
 *   <li>{@code token} — JWT de <b>acceso</b>, de vida corta (15 min por
 *       defecto). Es el que va en {@code Authorization: Bearer}. Se conserva el
 *       nombre {@code token} a propósito: renombrarlo no aporta seguridad y
 *       obligaría a reescribir el script de regresión y la documentación.</li>
 *   <li>{@code refreshToken} — cadena opaca, larga duración, <b>revocable</b>.
 *       Sirve para pedir un token de acceso nuevo en
 *       {@code POST /api/auth/refresh} y se invalida en
 *       {@code POST /api/auth/logout}.</li>
 * </ul>
 *
 * <p>{@code expiraEnSegundos} es la vida del token de ACCESO, para que el
 * cliente sepa cuándo renovar sin tener que decodificar el JWT.
 */
public record AuthResponse(
        String token,
        String refreshToken,
        String tokenType,
        long expiraEnSegundos,
        UsuarioResponse usuario
) {
    public static AuthResponse de(String token, String refreshToken,
                                  long expiraEnSegundos, UsuarioResponse usuario) {
        return new AuthResponse(token, refreshToken, "Bearer", expiraEnSegundos, usuario);
    }
}
