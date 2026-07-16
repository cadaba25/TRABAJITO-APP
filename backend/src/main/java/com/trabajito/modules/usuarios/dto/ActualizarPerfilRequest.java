package com.trabajito.modules.usuarios.dto;

/** Campos editables del perfil por su dueño (todos opcionales). */
public record ActualizarPerfilRequest(
        String nombres,
        String apellidos,
        String telefono,
        String presentacion,
        String departamento,
        String ciudad,
        String fotoUrl,
        String tipoEmpleador,
        String nombreEmpresa,
        String sectorEmpresa,
        String tamanoEmpresa,
        String sitioWeb
) {}
