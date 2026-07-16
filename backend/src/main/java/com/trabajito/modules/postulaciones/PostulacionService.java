package com.trabajito.modules.postulaciones;

import com.trabajito.common.enums.EstadoPostulacion;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.chats.ChatService;
import com.trabajito.modules.trabajos.Trabajo;
import com.trabajito.modules.trabajos.TrabajoService;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class PostulacionService {

    private final PostulacionRepository postulaciones;
    private final UsuarioRepository usuarios;
    private final TrabajoService trabajoService;
    private final ChatService chatService;

    public PostulacionService(PostulacionRepository postulaciones,
                              UsuarioRepository usuarios,
                              TrabajoService trabajoService,
                              ChatService chatService) {
        this.postulaciones = postulaciones;
        this.usuarios = usuarios;
        this.trabajoService = trabajoService;
        this.chatService = chatService;
    }

    /** Un trabajador se postula a un trabajo. */
    @Transactional
    public Postulacion postular(UUID trabajoId, UUID trabajadorId, String mensaje) {
        if (postulaciones.existsByTrabajoIdAndTrabajadorId(trabajoId, trabajadorId)) {
            throw ApiException.conflicto("Ya te postulaste a este trabajo");
        }
        Trabajo t = trabajoService.porId(trabajoId); // valida existencia
        if (t.getEmpleadorId().equals(trabajadorId)) {
            throw ApiException.solicitudInvalida("No puedes postularte a tu propio trabajo");
        }
        Usuario trabajador = usuarios.findById(trabajadorId)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        Postulacion p = Postulacion.builder()
                .trabajoId(trabajoId)
                .trabajadorId(trabajadorId)
                .trabajadorNombre(trabajador.getNombreCompleto())
                .mensaje(mensaje)
                .estado(EstadoPostulacion.PENDIENTE)
                .build();
        return postulaciones.save(p);
    }

    public List<Postulacion> porTrabajo(UUID trabajoId, UUID empleadorId) {
        Trabajo t = trabajoService.porId(trabajoId);
        if (!t.getEmpleadorId().equals(empleadorId)) {
            throw ApiException.prohibido("No eres el dueño de este trabajo");
        }
        return postulaciones.findByTrabajoId(trabajoId);
    }

    public List<Postulacion> misPostulaciones(UUID trabajadorId) {
        return postulaciones.findByTrabajadorIdOrderByCreadoEnDesc(trabajadorId);
    }

    /**
     * El empleador acepta una postulación: el trabajo pasa a ASIGNADO, esta
     * postulación queda ACEPTADA, las demás RECHAZADA, y se crea el chat.
     */
    @Transactional
    public Postulacion aceptar(UUID postulacionId, UUID empleadorId) {
        Postulacion p = postulaciones.findById(postulacionId)
                .orElseThrow(() -> ApiException.noEncontrado("La postulación no existe"));

        // Cambia el estado del trabajo (valida dueño + disponibilidad).
        Trabajo t = trabajoService.asignar(
                p.getTrabajoId(), empleadorId, p.getTrabajadorId(), p.getTrabajadorNombre());

        for (Postulacion otra : postulaciones.findByTrabajoId(p.getTrabajoId())) {
            otra.setEstado(otra.getId().equals(postulacionId)
                    ? EstadoPostulacion.ACEPTADA : EstadoPostulacion.RECHAZADA);
            postulaciones.save(otra);
        }

        // Crea el chat entre empleador y trabajador.
        chatService.crearParaTrabajo(t);
        return p;
    }

    /** El trabajador retira su postulación. */
    @Transactional
    public void retirar(UUID postulacionId, UUID trabajadorId) {
        Postulacion p = postulaciones.findById(postulacionId)
                .orElseThrow(() -> ApiException.noEncontrado("La postulación no existe"));
        if (!p.getTrabajadorId().equals(trabajadorId)) {
            throw ApiException.prohibido("No es tu postulación");
        }
        p.setEstado(EstadoPostulacion.RETIRADA);
        postulaciones.save(p);
    }
}
