package com.trabajito.modules.trabajos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CrearTrabajoRequest(
        @NotBlank @Size(max = 50, message = "El título no puede superar 50 caracteres")
        String titulo,
        @NotBlank String descripcion,
        String categoria,
        String departamento,
        String ciudad,
        String zona,
        String presupuesto,
        String plazo
) {}
