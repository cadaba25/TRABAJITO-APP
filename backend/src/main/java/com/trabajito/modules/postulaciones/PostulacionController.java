package com.trabajito.modules.postulaciones;

import com.trabajito.security.SecurityUtils;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/postulaciones")
public class PostulacionController {

    private final PostulacionService service;

    public PostulacionController(PostulacionService service) {
        this.service = service;
    }

    public record PostularRequest(UUID trabajoId, String mensaje) {}

    /** El trabajador se postula. */
    @PostMapping
    public Postulacion postular(@RequestBody PostularRequest req) {
        return service.postular(req.trabajoId(), SecurityUtils.idActual(), req.mensaje());
    }

    /** Postulantes de un trabajo (solo el dueño). */
    @GetMapping
    public List<Postulacion> porTrabajo(@RequestParam UUID trabajoId) {
        return service.porTrabajo(trabajoId, SecurityUtils.idActual());
    }

    /** Postulaciones propias (trabajador). */
    @GetMapping("/mias")
    public List<Postulacion> mias() {
        return service.misPostulaciones(SecurityUtils.idActual());
    }

    /** El empleador acepta una postulación. */
    @PostMapping("/{id}/aceptar")
    public Postulacion aceptar(@PathVariable UUID id) {
        return service.aceptar(id, SecurityUtils.idActual());
    }

    /** El trabajador retira su postulación. */
    @DeleteMapping("/{id}")
    public void retirar(@PathVariable UUID id) {
        service.retirar(id, SecurityUtils.idActual());
    }
}
