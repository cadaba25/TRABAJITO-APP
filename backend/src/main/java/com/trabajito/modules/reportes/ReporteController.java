package com.trabajito.modules.reportes;

import com.trabajito.common.enums.EstadoReporte;
import com.trabajito.security.SecurityUtils;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/** Creación de reportes por parte de los usuarios (la gestión vive en admin). */
@RestController
@RequestMapping("/api/reportes")
public class ReporteController {

    private final ReporteRepository repo;

    public ReporteController(ReporteRepository repo) {
        this.repo = repo;
    }

    public record CrearReporteRequest(UUID trabajoId, UUID reportadoId,
                                      String motivo, String descripcion) {}

    @PostMapping
    public Reporte crear(@RequestBody CrearReporteRequest req) {
        return repo.save(Reporte.builder()
                .reportanteId(SecurityUtils.idActual())
                .trabajoId(req.trabajoId())
                .reportadoId(req.reportadoId())
                .motivo(req.motivo())
                .descripcion(req.descripcion())
                .estado(EstadoReporte.ABIERTO)
                .build());
    }
}
