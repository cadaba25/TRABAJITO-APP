package com.trabajito.modules.calificaciones.dto;

import com.trabajito.common.enums.RolCalificado;
import com.trabajito.modules.calificaciones.Calificacion;

import java.time.Instant;
import java.util.UUID;

/**
 * Vista de una calificación. Existe desde la tarea 019: hasta entonces el
 * controller devolvía la entidad JPA tal cual, contra la norma del proyecto de
 * no exponer entidades en un body.
 */
public record CalificacionResponse(
        UUID id,
        UUID trabajoId,
        UUID autorId,
        UUID receptorId,
        RolCalificado rolCalificado,
        int estrellas,
        String comentario,
        Instant creadoEn
) {
    public static CalificacionResponse de(Calificacion c) {
        return new CalificacionResponse(c.getId(), c.getTrabajoId(), c.getAutorId(),
                c.getReceptorId(), c.getRolCalificado(), c.getEstrellas(),
                c.getComentario(), c.getCreadoEn());
    }
}
