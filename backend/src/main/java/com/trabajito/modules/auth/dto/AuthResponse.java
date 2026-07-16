package com.trabajito.modules.auth.dto;

import com.trabajito.modules.usuarios.dto.UsuarioResponse;

/** Respuesta de login/registro: token JWT + datos del usuario. */
public record AuthResponse(
        String token,
        UsuarioResponse usuario
) {}
