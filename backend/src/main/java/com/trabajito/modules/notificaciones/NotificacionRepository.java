package com.trabajito.modules.notificaciones;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface NotificacionRepository extends JpaRepository<Notificacion, UUID> {

    List<Notificacion> findByUsuarioIdOrderByCreadoEnDesc(UUID usuarioId);

    long countByUsuarioIdAndLeidaFalse(UUID usuarioId);
}
