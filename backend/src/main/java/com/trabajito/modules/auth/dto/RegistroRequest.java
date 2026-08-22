package com.trabajito.modules.auth.dto;

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
        // OJO: RolPublico, NO el enum de dominio Rol. El registro público es
        // permitAll y no puede crear administradores (ADR-0005). Un valor no
        // reconocido llega aquí como null y el @NotNull lo convierte en 400.
        @NotNull(message = "El rol debe ser TRABAJADOR o EMPLEADOR") RolPublico rol,
        String departamento,
        String ciudad
) {}
