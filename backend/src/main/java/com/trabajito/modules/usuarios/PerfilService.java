package com.trabajito.modules.usuarios;

import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.usuarios.dto.EstudioRequest;
import com.trabajito.modules.usuarios.dto.EstudioResponse;
import com.trabajito.modules.usuarios.dto.ExperienciaRequest;
import com.trabajito.modules.usuarios.dto.ExperienciaResponse;
import com.trabajito.modules.usuarios.dto.UsuarioResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * El CV del trabajador: habilidades, experiencia laboral y estudios.
 *
 * <p>Vive aparte de {@link UsuarioService} porque son tres tablas hijas con su
 * propio ciclo de vida (alta/edición/baja una a una), mientras que
 * {@code UsuarioService} maneja la fila del usuario. Quién puede tocar qué se
 * resuelve <b>aquí</b>, en el servicio, nunca en el cliente: un id de
 * experiencia ajeno responde 403 aunque exista.
 */
@Service
public class PerfilService {

    /** Topes para que el perfil no se use como almacén de texto. */
    static final int MAX_EXPERIENCIAS = 30;
    static final int MAX_ESTUDIOS = 30;
    static final int MAX_HABILIDADES = 30;

    private final UsuarioRepository usuarios;
    private final HabilidadRepository habilidades;
    private final ExperienciaRepository experiencias;
    private final EstudioRepository estudios;

    public PerfilService(UsuarioRepository usuarios,
                         HabilidadRepository habilidades,
                         ExperienciaRepository experiencias,
                         EstudioRepository estudios) {
        this.usuarios = usuarios;
        this.habilidades = habilidades;
        this.experiencias = experiencias;
        this.estudios = estudios;
    }

    // ── Lectura ──────────────────────────────────────────────────────

    public List<String> habilidadesDe(UUID usuarioId) {
        return habilidades.findByUsuarioIdOrderByHabilidadAsc(usuarioId).stream()
                .map(Habilidad::getHabilidad).toList();
    }

    public List<ExperienciaResponse> experienciaDe(UUID usuarioId) {
        return experiencias.findByUsuarioIdOrderByCreadoEnAsc(usuarioId).stream()
                .map(ExperienciaResponse::de).toList();
    }

    public List<EstudioResponse> estudiosDe(UUID usuarioId) {
        return estudios.findByUsuarioIdOrderByCreadoEnAsc(usuarioId).stream()
                .map(EstudioResponse::de).toList();
    }

    /**
     * Perfil completo: la fila del usuario más sus tres listas.
     *
     * @param esElDueno si es {@code false} se devuelve la vista pública, sin
     *                  datos personales ni saldo (ver {@link UsuarioResponse}).
     */
    public UsuarioResponse completo(Usuario u, boolean esElDueno) {
        UUID id = u.getId();
        return esElDueno
                ? UsuarioResponse.completo(u, habilidadesDe(id), experienciaDe(id), estudiosDe(id))
                : UsuarioResponse.publicoCompleto(u, habilidadesDe(id), experienciaDe(id), estudiosDe(id));
    }

    // ── Habilidades ──────────────────────────────────────────────────

    /**
     * Reemplaza la lista completa de habilidades. Normaliza: recorta espacios,
     * descarta las vacías y quita repetidas sin distinguir mayúsculas
     * ("Plomería" y "plomería" son la misma etiqueta, se guarda la primera).
     */
    @Transactional
    public List<String> reemplazarHabilidades(UUID usuarioId, List<String> nuevas) {
        Usuario u = usuarios.findById(usuarioId)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        List<String> limpias = normalizar(nuevas);
        if (limpias.size() > MAX_HABILIDADES) {
            throw ApiException.solicitudInvalida(
                    "Como máximo " + MAX_HABILIDADES + " habilidades");
        }
        habilidades.deleteByUsuarioId(usuarioId);
        // flush antes de insertar: si no, el DELETE puede quedar en la cola
        // detrás de los INSERT y chocar con uq_habilidad_usuario.
        habilidades.flush();
        for (String h : limpias) {
            habilidades.save(Habilidad.builder().usuario(u).habilidad(h).build());
        }
        return limpias;
    }

    private List<String> normalizar(List<String> valores) {
        Map<String, String> sinRepetir = new LinkedHashMap<>();
        for (String v : valores == null ? List.<String>of() : valores) {
            if (v == null) continue;
            String limpia = v.trim();
            if (limpia.isEmpty()) continue;
            sinRepetir.putIfAbsent(limpia.toLowerCase(), limpia);
        }
        return new ArrayList<>(sinRepetir.values());
    }

    // ── Experiencia laboral ──────────────────────────────────────────

    @Transactional
    public ExperienciaResponse crearExperiencia(UUID usuarioId, ExperienciaRequest req) {
        Usuario u = usuarios.findById(usuarioId)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        if (experiencias.countByUsuarioId(usuarioId) >= MAX_EXPERIENCIAS) {
            throw ApiException.conflicto(
                    "No puedes tener más de " + MAX_EXPERIENCIAS + " puestos en tu experiencia");
        }
        Experiencia e = Experiencia.builder().usuario(u).build();
        copiar(req, e);
        return ExperienciaResponse.de(experiencias.save(e));
    }

    @Transactional
    public ExperienciaResponse editarExperiencia(UUID usuarioId, UUID id, ExperienciaRequest req) {
        Experiencia e = experiencias.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Esa experiencia no existe"));
        exigirPropiedad(e.getUsuario().getId(), usuarioId, "experiencia");
        copiar(req, e);
        return ExperienciaResponse.de(experiencias.save(e));
    }

    @Transactional
    public void borrarExperiencia(UUID usuarioId, UUID id) {
        Experiencia e = experiencias.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Esa experiencia no existe"));
        exigirPropiedad(e.getUsuario().getId(), usuarioId, "experiencia");
        experiencias.delete(e);
    }

    private void copiar(ExperienciaRequest req, Experiencia e) {
        e.setEmpresa(req.empresa().trim());
        e.setPuesto(req.puesto().trim());
        e.setHabilidades(req.habilidades());
        e.setDescripcion(req.descripcion());
        e.setFechaInicio(req.fechaInicio());
        // Si sigue trabajando ahí, la fecha de fin no significa nada.
        e.setTrabajaActualmente(req.trabajaActualmente());
        e.setFechaFin(req.trabajaActualmente() ? "" : req.fechaFin());
    }

    // ── Estudios ─────────────────────────────────────────────────────

    @Transactional
    public EstudioResponse crearEstudio(UUID usuarioId, EstudioRequest req) {
        Usuario u = usuarios.findById(usuarioId)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        if (estudios.countByUsuarioId(usuarioId) >= MAX_ESTUDIOS) {
            throw ApiException.conflicto(
                    "No puedes tener más de " + MAX_ESTUDIOS + " estudios");
        }
        Estudio e = Estudio.builder().usuario(u).build();
        copiar(req, e);
        return EstudioResponse.de(estudios.save(e));
    }

    @Transactional
    public EstudioResponse editarEstudio(UUID usuarioId, UUID id, EstudioRequest req) {
        Estudio e = estudios.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Ese estudio no existe"));
        exigirPropiedad(e.getUsuario().getId(), usuarioId, "estudio");
        copiar(req, e);
        return EstudioResponse.de(estudios.save(e));
    }

    @Transactional
    public void borrarEstudio(UUID usuarioId, UUID id) {
        Estudio e = estudios.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Ese estudio no existe"));
        exigirPropiedad(e.getUsuario().getId(), usuarioId, "estudio");
        estudios.delete(e);
    }

    private void copiar(EstudioRequest req, Estudio e) {
        e.setNivel(req.nivel().trim());
        e.setCentro(req.centro().trim());
        e.setFechaInicio(req.fechaInicio());
        e.setCursandoActualmente(req.cursandoActualmente());
        e.setFechaFin(req.cursandoActualmente() ? "" : req.fechaFin());
    }

    private void exigirPropiedad(UUID dueno, UUID quienPide, String que) {
        if (!dueno.equals(quienPide)) {
            throw ApiException.prohibido("Esa " + que + " no es tuya");
        }
    }
}
