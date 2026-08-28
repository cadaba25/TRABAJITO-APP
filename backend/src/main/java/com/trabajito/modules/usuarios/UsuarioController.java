package com.trabajito.modules.usuarios;

import com.trabajito.modules.usuarios.dto.ActualizarPerfilRequest;
import com.trabajito.modules.usuarios.dto.EstudioRequest;
import com.trabajito.modules.usuarios.dto.EstudioResponse;
import com.trabajito.modules.usuarios.dto.ExperienciaRequest;
import com.trabajito.modules.usuarios.dto.ExperienciaResponse;
import com.trabajito.modules.usuarios.dto.HabilidadesRequest;
import com.trabajito.modules.usuarios.dto.UsuarioResponse;
import com.trabajito.security.SecurityUtils;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Perfil de usuario. Desde la tarea 019 el perfil incluye el CV del trabajador
 * (habilidades, experiencia y estudios), que hasta ahora solo existía en
 * Firestore y bloqueaba la fase 2 de la migración (ADR-0009).
 *
 * <p>Ojo con la diferencia entre las dos lecturas: {@code GET /{id}} devuelve
 * la vista pública (sin correo, DNI, teléfonos, fecha de nacimiento ni saldo) y
 * {@code GET /me} la del dueño, con todo. Ver {@link UsuarioResponse}.
 */
@RestController
@RequestMapping("/api/usuarios")
public class UsuarioController {

    private final UsuarioService service;
    private final PerfilService perfiles;

    public UsuarioController(UsuarioService service, PerfilService perfiles) {
        this.service = service;
        this.perfiles = perfiles;
    }

    /** Perfil público de un usuario, con su CV. */
    @GetMapping("/{id}")
    public UsuarioResponse porId(@PathVariable UUID id) {
        return service.perfilPublico(id);
    }

    /** Perfil propio completo. */
    @GetMapping("/me")
    public UsuarioResponse yo() {
        return service.perfilPropio(SecurityUtils.idActual());
    }

    /** Edita el perfil propio y devuelve el perfil completo ya guardado. */
    @PutMapping("/me")
    public UsuarioResponse actualizarPerfil(@Valid @RequestBody ActualizarPerfilRequest req) {
        return service.actualizarPerfil(SecurityUtils.idActual(), req);
    }

    /** Ranking de trabajadores por trabajos completados (sin CV, es un listado). */
    @GetMapping("/ranking")
    public List<UsuarioResponse> ranking() {
        return service.ranking().stream().map(UsuarioResponse::publico).toList();
    }

    /** Baja de la cuenta propia (desactivación lógica). */
    @DeleteMapping("/me")
    public void eliminarme() {
        service.desactivar(SecurityUtils.idActual());
    }

    // ── CV del trabajador ────────────────────────────────────────────

    /** Reemplaza la lista completa de habilidades propias. */
    @PutMapping("/me/habilidades")
    public List<String> habilidades(@Valid @RequestBody HabilidadesRequest req) {
        return perfiles.reemplazarHabilidades(SecurityUtils.idActual(), req.habilidades());
    }

    @PostMapping("/me/experiencia")
    @ResponseStatus(HttpStatus.CREATED)
    public ExperienciaResponse crearExperiencia(@Valid @RequestBody ExperienciaRequest req) {
        return perfiles.crearExperiencia(SecurityUtils.idActual(), req);
    }

    @PutMapping("/me/experiencia/{id}")
    public ExperienciaResponse editarExperiencia(@PathVariable UUID id,
                                                 @Valid @RequestBody ExperienciaRequest req) {
        return perfiles.editarExperiencia(SecurityUtils.idActual(), id, req);
    }

    @DeleteMapping("/me/experiencia/{id}")
    public void borrarExperiencia(@PathVariable UUID id) {
        perfiles.borrarExperiencia(SecurityUtils.idActual(), id);
    }

    @PostMapping("/me/estudios")
    @ResponseStatus(HttpStatus.CREATED)
    public EstudioResponse crearEstudio(@Valid @RequestBody EstudioRequest req) {
        return perfiles.crearEstudio(SecurityUtils.idActual(), req);
    }

    @PutMapping("/me/estudios/{id}")
    public EstudioResponse editarEstudio(@PathVariable UUID id,
                                         @Valid @RequestBody EstudioRequest req) {
        return perfiles.editarEstudio(SecurityUtils.idActual(), id, req);
    }

    @DeleteMapping("/me/estudios/{id}")
    public void borrarEstudio(@PathVariable UUID id) {
        perfiles.borrarEstudio(SecurityUtils.idActual(), id);
    }
}
