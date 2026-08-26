package com.trabajito.modules.admin;

import com.trabajito.common.enums.EstadoReporte;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.reportes.Reporte;
import com.trabajito.modules.reportes.ReporteRepository;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import com.trabajito.modules.trabajos.TrabajoRepository;
import com.trabajito.modules.trabajos.TrabajoService;
import com.trabajito.modules.trabajos.dto.TrabajoResponse;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Locale;
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
    private final TrabajoService trabajoService;

    public AdminController(ReporteRepository reportes, UsuarioRepository usuarios,
                           TrabajoRepository trabajos, TrabajoService trabajoService) {
        this.reportes = reportes;
        this.usuarios = usuarios;
        this.trabajos = trabajos;
        this.trabajoService = trabajoService;
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

    // ── Disputas (ADR-0007) ───────────────────────────────────
    /**
     * Cola de trabajos EN_DISPUTA: tienen el escrow congelado y esperan a que
     * soporte decida. Ninguna de las dos partes puede tocar ese dinero.
     */
    @GetMapping("/trabajos/en-disputa")
    public List<TrabajoResponse> trabajosEnDisputa() {
        return trabajoService.enDisputa().stream().map(TrabajoResponse::de).toList();
    }

    public record ResolverDisputaRequest(String aFavorDe, String resolucion) {}

    /**
     * Resuelve una disputa descongelando el dinero en UNA sola dirección:
     * {@code aFavorDe = "TRABAJADOR"} libera el escrow al trabajador
     * (COMPLETADO), {@code "EMPLEADOR"} se lo reembolsa (CANCELADO). No hay
     * repartos parciales todavía (fuera del alcance de la tarea 010).
     */
    @PostMapping("/trabajos/{id}/resolver-disputa")
    public TrabajoResponse resolverDisputa(@PathVariable UUID id,
                                           @RequestBody(required = false) ResolverDisputaRequest req) {
        String favor = req == null || req.aFavorDe() == null ? "" : req.aFavorDe().trim();
        TrabajoService.FavorDisputa aFavorDe;
        try {
            aFavorDe = TrabajoService.FavorDisputa.valueOf(favor.toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            // Se parsea a mano para responder 400 en vez del 500 que daría un
            // enum inválido deserializado por Jackson (ver tarea 009).
            throw ApiException.solicitudInvalida(
                    "Indica aFavorDe: \"TRABAJADOR\" (libera el pago) o \"EMPLEADOR\" (reembolsa)");
        }
        return TrabajoResponse.de(trabajoService.resolverDisputa(id, aFavorDe, req.resolucion()));
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
