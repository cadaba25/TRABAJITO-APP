package com.trabajito.modules.reportes;

import com.trabajito.common.enums.EstadoReporte;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ReporteRepository extends JpaRepository<Reporte, UUID> {

    List<Reporte> findByEstadoOrderByCreadoEnAsc(EstadoReporte estado);

    /** Reportes de un trabajo en un estado concreto (cierre de disputas, ADR-0007). */
    List<Reporte> findByTrabajoIdAndEstado(UUID trabajoId, EstadoReporte estado);
}
