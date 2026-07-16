package com.trabajito.modules.evidencias;

import com.trabajito.common.enums.EstadoTrabajo;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.trabajos.Trabajo;
import com.trabajito.modules.trabajos.TrabajoService;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.security.SecurityUtils;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/** Avances/evidencias de un trabajo. */
@RestController
@RequestMapping("/api/trabajos/{trabajoId}/evidencias")
public class EvidenciaController {

    private final EvidenciaRepository evidencias;
    private final TrabajoService trabajoService;

    public EvidenciaController(EvidenciaRepository evidencias, TrabajoService trabajoService) {
        this.evidencias = evidencias;
        this.trabajoService = trabajoService;
    }

    /** Ambas partes ven los avances. */
    @GetMapping
    public List<Evidencia> listar(@PathVariable UUID trabajoId) {
        Trabajo t = trabajoService.porId(trabajoId);
        exigirParticipante(t);
        return evidencias.findByTrabajoIdOrderByCreadoEnAsc(trabajoId);
    }

    public record EvidenciaRequest(String texto, String archivoUrl) {}

    /** Solo el trabajador asignado agrega avances, y solo mientras esté en progreso. */
    @PostMapping
    @Transactional
    public Evidencia agregar(@PathVariable UUID trabajoId, @RequestBody EvidenciaRequest req) {
        Usuario yo = SecurityUtils.usuarioActual();
        Trabajo t = trabajoService.porId(trabajoId);
        if (t.getTrabajadorAsignadoId() == null
                || !t.getTrabajadorAsignadoId().equals(yo.getId())) {
            throw ApiException.prohibido("Solo el trabajador asignado agrega avances");
        }
        if (t.getEstado() != EstadoTrabajo.EN_PROGRESO) {
            throw ApiException.conflicto("Solo puedes agregar avances con el trabajo en progreso");
        }
        return evidencias.save(Evidencia.builder()
                .trabajoId(trabajoId)
                .autorId(yo.getId())
                .autorNombre(yo.getNombreCompleto())
                .texto(req.texto())
                .archivoUrl(req.archivoUrl())
                .build());
    }

    private void exigirParticipante(Trabajo t) {
        UUID yo = SecurityUtils.idActual();
        boolean participa = t.getEmpleadorId().equals(yo)
                || (t.getTrabajadorAsignadoId() != null && t.getTrabajadorAsignadoId().equals(yo));
        if (!participa) throw ApiException.prohibido("No participas en este trabajo");
    }
}
