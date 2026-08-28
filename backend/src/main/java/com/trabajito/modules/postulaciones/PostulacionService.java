package com.trabajito.modules.postulaciones;

import com.trabajito.common.enums.EstadoPostulacion;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.chats.ChatService;
import com.trabajito.modules.trabajos.Trabajo;
import com.trabajito.modules.trabajos.TrabajoService;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.springframework.dao.DataIntegrityViolationException;
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
        // Nadie se postula a su propio trabajo (decision del dueno, tarea 019).
        // Ya estaba bloqueado, pero respondia 400: es un conflicto con el estado
        // del recurso -quien pide ES el dueno-, no un cuerpo mal formado, asi que
        // va con el mismo 409 que "ya te postulaste". Con el doble perfil (tarea
        // 012) una misma cuenta publica y se postula, y este es el unico sitio
        // donde se puede impedir de verdad: el cliente no decide autorizacion.
        if (t.getEmpleadorId().equals(trabajadorId)) {
            throw ApiException.conflicto("No puedes postularte a tu propio trabajo");
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
        try {
            // saveAndFlush para que la restriccion unica salte AQUI y no al hacer
            // commit, donde ya no podriamos traducirla.
            return postulaciones.saveAndFlush(p);
        } catch (DataIntegrityViolationException e) {
            // Doble toque: el existsBy de arriba no protege de una peticion
            // simultanea (READ COMMITTED, la otra fila aun no esta commiteada).
            // Quien decide de verdad es uq_postulacion_trabajo_trabajador; aqui
            // solo lo traducimos al mismo 409 que el caso secuencial, en vez de
            // dejar que se convierta en un 500.
            throw ApiException.conflicto("Ya te postulaste a este trabajo");
        }
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
