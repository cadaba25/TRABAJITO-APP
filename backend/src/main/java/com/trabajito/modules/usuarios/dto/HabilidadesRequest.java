package com.trabajito.modules.usuarios.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Reemplaza la lista completa de habilidades del trabajador.
 *
 * <p>Es un reemplazo y no un "añadir una": el formulario de la app maneja las
 * etiquetas como un conjunto y manda siempre el conjunto entero. Con un tope
 * de 30 etiquetas de 60 caracteres para que nadie use el perfil como almacén.
 */
public record HabilidadesRequest(
        @NotNull(message = "Manda la lista de habilidades")
        @Size(max = 30, message = "Como máximo 30 habilidades")
        List<@Size(max = 60, message = "Cada habilidad admite 60 caracteres") String> habilidades
) {}
