package com.trabajito.modules.calificaciones;

import com.trabajito.common.enums.RolCalificado;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CalificacionRepository extends JpaRepository<Calificacion, UUID> {

    List<Calificacion> findByReceptorIdOrderByCreadoEnDesc(UUID receptorId);

    /** Reseñas que recibió como trabajador, o como contratista (tarea 019). */
    List<Calificacion> findByReceptorIdAndRolCalificadoOrderByCreadoEnDesc(
            UUID receptorId, RolCalificado rolCalificado);

    boolean existsByTrabajoIdAndAutorId(UUID trabajoId, UUID autorId);
}
