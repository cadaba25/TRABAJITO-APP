package com.trabajito.modules.notificaciones;

import com.trabajito.security.SecurityUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/notificaciones")
public class NotificacionController {

    private final NotificacionService service;

    public NotificacionController(NotificacionService service) {
        this.service = service;
    }

    @GetMapping
    public List<Notificacion> listar() {
        return service.listar(SecurityUtils.idActual());
    }

    @GetMapping("/no-leidas")
    public long noLeidas() {
        return service.noLeidas(SecurityUtils.idActual());
    }

    @PostMapping("/{id}/leida")
    public void marcarLeida(@PathVariable UUID id) {
        service.marcarLeida(id);
    }
}
