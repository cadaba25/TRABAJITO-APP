package com.trabajito.modules.calificaciones;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CalificacionRepository extends JpaRepository<Calificacion, UUID> {

    List<Calificacion> findByReceptorIdOrderByCreadoEnDesc(UUID receptorId);

    boolean existsByTrabajoIdAndAutorId(UUID trabajoId, UUID autorId);
}
