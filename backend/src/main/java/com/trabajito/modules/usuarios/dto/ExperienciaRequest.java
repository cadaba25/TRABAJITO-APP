package com.trabajito.modules.usuarios.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Alta/edición de un puesto del historial laboral.
 *
 * <p>Los {@code @Size} no son decoración: las columnas tienen ese ancho, y sin
 * la validación un texto más largo saldría como 500 desde el driver en vez de
 * como un 400 con el campo señalado (la lección de ADR-0008).
 */
public record ExperienciaRequest(
        @NotBlank(message = "Indica la empresa") @Size(max = 150) String empresa,
        @NotBlank(message = "Indica el puesto") @Size(max = 150) String puesto,
        @Size(max = 300) String habilidades,
        @Size(max = 1000) String descripcion,
        @Size(max = 20) String fechaInicio,
        @Size(max = 20) String fechaFin,
        boolean trabajaActualmente
) {}
