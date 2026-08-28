package com.trabajito.modules.usuarios.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Alta/edición de un estudio. Ver la nota sobre {@code @Size} en {@link ExperienciaRequest}. */
public record EstudioRequest(
        @NotBlank(message = "Indica el nivel de estudios") @Size(max = 100) String nivel,
        @NotBlank(message = "Indica el centro de estudios") @Size(max = 150) String centro,
        @Size(max = 20) String fechaInicio,
        @Size(max = 20) String fechaFin,
        boolean cursandoActualmente
) {}
