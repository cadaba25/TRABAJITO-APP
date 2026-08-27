package com.trabajito.modules.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/** Datos para registrar un nuevo usuario. */
public record RegistroRequest(
        @NotBlank @Email String correo,
        // Politica de contrasenas: ADR-0010 (tarea 015). Antes era
        // @Size(min = 8) sin tope maximo; el tope importa porque BCrypt trunca
        // en 72 bytes y aceptar mas daba una falsa sensacion de fortaleza.
        @NotBlank @PasswordSegura String password,
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
