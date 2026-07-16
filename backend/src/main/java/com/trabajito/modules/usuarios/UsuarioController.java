package com.trabajito.modules.usuarios;

import com.trabajito.modules.usuarios.dto.ActualizarPerfilRequest;
import com.trabajito.modules.usuarios.dto.UsuarioResponse;
import com.trabajito.security.SecurityUtils;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/usuarios")
public class UsuarioController {

    private final UsuarioService service;

    public UsuarioController(UsuarioService service) {
        this.service = service;
    }

    /** Perfil público de un usuario. */
    @GetMapping("/{id}")
    public UsuarioResponse porId(@PathVariable UUID id) {
        return UsuarioResponse.de(service.porId(id));
    }

    /** Edita el perfil propio. */
    @PutMapping("/me")
    public UsuarioResponse actualizarPerfil(@Valid @RequestBody ActualizarPerfilRequest req) {
        UUID yo = SecurityUtils.idActual();
        return UsuarioResponse.de(service.actualizarPerfil(yo, req));
    }

    /** Ranking de trabajadores por trabajos completados. */
    @GetMapping("/ranking")
    public List<UsuarioResponse> ranking() {
        return service.ranking().stream().map(UsuarioResponse::de).toList();
    }

    /** Baja de la cuenta propia (desactivación lógica). */
    @DeleteMapping("/me")
    public void eliminarme() {
        service.desactivar(SecurityUtils.idActual());
    }
}
