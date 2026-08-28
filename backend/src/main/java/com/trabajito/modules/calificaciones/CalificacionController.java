package com.trabajito.modules.calificaciones;

import com.trabajito.common.enums.RolCalificado;
import com.trabajito.modules.calificaciones.dto.CalificacionResponse;
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
import org.springframework.web.bind.annotation.RequestParam;
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
    public CalificacionResponse calificar(@Valid @RequestBody CalificarRequest req) {
        return CalificacionResponse.de(service.calificar(req.trabajoId(),
                SecurityUtils.idActual(), req.estrellas(), req.comentario()));
    }

    /**
     * Reseñas recibidas por un usuario. Con {@code ?rol=TRABAJADOR} o
     * {@code ?rol=EMPLEADOR} se piden solo las de ese papel, que es lo que hay
     * que enseñar junto a cada una de sus dos reputaciones (tarea 019).
     */
    @GetMapping("/usuario/{id}")
    public List<CalificacionResponse> recibidas(@PathVariable UUID id,
                                                @RequestParam(required = false) RolCalificado rol) {
        List<Calificacion> lista = rol == null
                ? service.recibidas(id) : service.recibidasComo(id, rol);
        return lista.stream().map(CalificacionResponse::de).toList();
    }
}
