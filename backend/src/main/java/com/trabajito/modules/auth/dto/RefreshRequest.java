package com.trabajito.modules.auth.dto;

import jakarta.validation.constraints.NotBlank;

/** Cuerpo de {@code POST /api/auth/refresh} y {@code POST /api/auth/logout}. */
public record RefreshRequest(
        @NotBlank(message = "Falta el refreshToken") String refreshToken
) {}
