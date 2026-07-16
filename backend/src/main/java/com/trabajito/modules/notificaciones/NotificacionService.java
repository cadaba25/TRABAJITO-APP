package com.trabajito.modules.notificaciones;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Notificaciones in-app y push.
 *
 * <p>TODO (push): integrar Firebase Cloud Messaging (FCM) para enviar la
 * notificación al dispositivo. FCM es gratis e independiente del resto de
 * Firebase. Aquí solo se persiste la notificación in-app y se deja el gancho
 * {@link #enviarPush} listo para conectar el SDK Admin de FCM.
 */
@Service
public class NotificacionService {

    private static final Logger log = LoggerFactory.getLogger(NotificacionService.class);

    private final NotificacionRepository repo;

    public NotificacionService(NotificacionRepository repo) {
        this.repo = repo;
    }

    @Transactional
    public Notificacion crear(UUID usuarioId, String titulo, String cuerpo,
                              String tipo, String referenciaId) {
        Notificacion n = repo.save(Notificacion.builder()
                .usuarioId(usuarioId).titulo(titulo).cuerpo(cuerpo)
                .tipo(tipo).referenciaId(referenciaId).build());
        enviarPush(n);
        return n;
    }

    public List<Notificacion> listar(UUID usuarioId) {
        return repo.findByUsuarioIdOrderByCreadoEnDesc(usuarioId);
    }

    public long noLeidas(UUID usuarioId) {
        return repo.countByUsuarioIdAndLeidaFalse(usuarioId);
    }

    @Transactional
    public void marcarLeida(UUID id) {
        repo.findById(id).ifPresent(n -> { n.setLeida(true); repo.save(n); });
    }

    /** Gancho para el envío push real (FCM). Pendiente de integrar. */
    private void enviarPush(Notificacion n) {
        // TODO: recuperar el token FCM del dispositivo del usuario y enviar vía
        // FirebaseMessaging.getInstance().send(...).
        log.debug("[push pendiente] {} -> {}", n.getUsuarioId(), n.getTitulo());
    }
}
