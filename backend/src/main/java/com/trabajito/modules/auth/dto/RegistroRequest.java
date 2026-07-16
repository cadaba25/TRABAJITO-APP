package com.trabajito.modules.auth.dto;

import com.trabajito.common.enums.Rol;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Datos para registrar un nuevo usuario. */
public record RegistroRequest(
        @NotBlank @Email String correo,
        @NotBlank @Size(min = 8, message = "La contraseña debe tener al menos 8 caracteres")
        String password,
        @NotBlank String nombres,
        @NotBlank String apellidos,
        String dni,
        String telefono,
        @NotNull Rol rol,
        String departamento,
        String ciudad
) {}
