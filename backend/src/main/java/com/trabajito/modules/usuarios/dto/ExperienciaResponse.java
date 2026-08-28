package com.trabajito.modules.usuarios.dto;

import com.trabajito.modules.usuarios.Experiencia;

import java.util.UUID;

/**
 * Un puesto del historial laboral. Los nombres de los campos son
 * deliberadamente los mismos que usa el modelo `Experiencia` de Flutter, para
 * que la migración (fase 2 de ADR-0009) no tenga que traducir nada.
 */
public record ExperienciaResponse(
        UUID id,
        String empresa,
        String puesto,
        String habilidades,
        String descripcion,
        String fechaInicio,
        String fechaFin,
        boolean trabajaActualmente
) {
    public static ExperienciaResponse de(Experiencia e) {
        return new ExperienciaResponse(e.getId(), e.getEmpresa(), e.getPuesto(),
                e.getHabilidades(), e.getDescripcion(), e.getFechaInicio(),
                e.getFechaFin(), e.isTrabajaActualmente());
    }
}
