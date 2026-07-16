package com.trabajito.modules.admin;

import com.trabajito.common.enums.EstadoReporte;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.reportes.Reporte;
import com.trabajito.modules.reportes.ReporteRepository;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import com.trabajito.modules.trabajos.TrabajoRepository;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Panel de administración. Todo /api/admin/** requiere rol ADMIN
 * (ver SecurityConfig). En producción, además, servir la web de admin aparte
 * de la app.
 */
@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final ReporteRepository reportes;
    private final UsuarioRepository usuarios;
    private final TrabajoRepository trabajos;

    public AdminController(ReporteRepository reportes, UsuarioRepository usuarios,
                           TrabajoRepository trabajos) {
        this.reportes = reportes;
        this.usuarios = usuarios;
        this.trabajos = trabajos;
    }

    /** Estadísticas rápidas del sistema. */
    @GetMapping("/estadisticas")
    public Map<String, Long> estadisticas() {
        return Map.of(
                "usuarios", usuarios.count(),
                "trabajos", trabajos.count(),
                "reportesAbiertos",
                (long) reportes.findByEstadoOrderByCreadoEnAsc(EstadoReporte.ABIERTO).size());
    }

    /** Reportes abiertos pendientes de revisión. */
    @GetMapping("/reportes")
    public List<Reporte> reportesAbiertos() {
        return reportes.findByEstadoOrderByCreadoEnAsc(EstadoReporte.ABIERTO);
    }

    public record ResolverRequest(EstadoReporte estado, String resolucion) {}

    @PostMapping("/reportes/{id}/resolver")
    @Transactional
    public Reporte resolver(@PathVariable UUID id, @RequestBody ResolverRequest req) {
        Reporte r = reportes.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Reporte no encontrado"));
        r.setEstado(req.estado() == null ? EstadoReporte.RESUELTO : req.estado());
        r.setResolucion(req.resolucion());
        return reportes.save(r);
    }

    /** Suspende (desactiva) una cuenta de usuario. */
    @PostMapping("/usuarios/{id}/suspender")
    @Transactional
    public void suspender(@PathVariable UUID id) {
        Usuario u = usuarios.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        u.setActivo(false);
        usuarios.save(u);
    }

    /** Reactiva una cuenta suspendida. */
    @PostMapping("/usuarios/{id}/reactivar")
    @Transactional
    public void reactivar(@PathVariable UUID id) {
        Usuario u = usuarios.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        u.setActivo(true);
        usuarios.save(u);
    }
}
