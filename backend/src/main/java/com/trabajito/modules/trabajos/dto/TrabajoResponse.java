package com.trabajito.modules.trabajos.dto;

import com.trabajito.common.enums.EstadoTrabajo;
import com.trabajito.modules.trabajos.Trabajo;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record TrabajoResponse(
        UUID id,
        UUID empleadorId,
        String autorNombre,
        String titulo,
        String descripcion,
        String categoria,
        String departamento,
        String ciudad,
        String zona,
        String presupuesto,
        String plazo,
        EstadoTrabajo estado,
        UUID trabajadorAsignadoId,
        String trabajadorAsignadoNombre,
        BigDecimal montoAcordado,
        String tiempoAcordado,
        Instant fechaAcuerdo,
        Instant fechaInicio,
        boolean pagoRetenido,
        boolean entregado,
        boolean pagoLiberado,
        boolean correccionSolicitada,
        String motivoCorreccion,
        Instant fechaSolicitudCorreccion,
        UUID disputaAbiertaPorId,
        String motivoDisputa,
        String resolucionDisputa,
        boolean calificadoPorEmpleador,
        boolean calificadoPorTrabajador,
        Instant creadoEn
) {
    public static TrabajoResponse de(Trabajo t) {
        return new TrabajoResponse(
                t.getId(), t.getEmpleadorId(), t.getAutorNombre(), t.getTitulo(),
                t.getDescripcion(), t.getCategoria(), t.getDepartamento(), t.getCiudad(),
                t.getZona(), t.getPresupuesto(), t.getPlazo(), t.getEstado(),
                t.getTrabajadorAsignadoId(), t.getTrabajadorAsignadoNombre(),
                t.getMontoAcordado(), t.getTiempoAcordado(), t.getFechaAcuerdo(),
                t.getFechaInicio(), t.isPagoRetenido(), t.isEntregado(), t.isPagoLiberado(),
                t.isCorreccionSolicitada(), t.getMotivoCorreccion(),
                t.getFechaSolicitudCorreccion(), t.getDisputaAbiertaPorId(),
                t.getMotivoDisputa(), t.getResolucionDisputa(),
                t.isCalificadoPorEmpleador(), t.isCalificadoPorTrabajador(), t.getCreadoEn());
    }
}
