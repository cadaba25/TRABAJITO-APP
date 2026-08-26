package com.trabajito.modules.calificaciones;

import com.trabajito.security.SecurityUtils;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/calificaciones")
public class CalificacionController {

    private final CalificacionService service;

    public CalificacionController(CalificacionService service) {
        this.service = service;
    }

    public record CalificarRequest(
            @NotNull UUID trabajoId,
            @Min(1) @Max(5) int estrellas,
            String comentario) {}

    @PostMapping
    public Calificacion calificar(@Valid @RequestBody CalificarRequest req) {
        return service.calificar(req.trabajoId(), SecurityUtils.idActual(),
                req.estrellas(), req.comentario());
    }

    /** Reseñas recibidas por un usuario. */
    @GetMapping("/usuario/{id}")
    public List<Calificacion> recibidas(@PathVariable UUID id) {
        return service.recibidas(id);
    }
}
