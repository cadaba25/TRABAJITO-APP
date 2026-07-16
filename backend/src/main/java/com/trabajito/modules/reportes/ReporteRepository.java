package com.trabajito.modules.reportes;

import com.trabajito.common.enums.EstadoReporte;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ReporteRepository extends JpaRepository<Reporte, UUID> {

    List<Reporte> findByEstadoOrderByCreadoEnAsc(EstadoReporte estado);
}
