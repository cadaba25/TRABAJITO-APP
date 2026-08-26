package com.trabajito.modules.postulaciones;

import com.trabajito.security.SecurityUtils;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
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

    /**
     * {@code trabajoId} es obligatorio: sin el {@code @NotNull} + el
     * {@code @Valid} de abajo, un cuerpo {@code {"mensaje":"..."}} llegaba con
     * null hasta el repositorio y salia como 500 (tarea 009).
     */
    public record PostularRequest(
            @NotNull(message = "Indica el trabajo al que te postulas") UUID trabajoId,
            String mensaje) {}

    /** El trabajador se postula. */
    @PostMapping
    public Postulacion postular(@Valid @RequestBody PostularRequest req) {
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
