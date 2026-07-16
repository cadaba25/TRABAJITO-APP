package com.trabajito.modules.postulaciones;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PostulacionRepository extends JpaRepository<Postulacion, UUID> {

    List<Postulacion> findByTrabajoId(UUID trabajoId);

    List<Postulacion> findByTrabajadorIdOrderByCreadoEnDesc(UUID trabajadorId);

    Optional<Postulacion> findByTrabajoIdAndTrabajadorId(UUID trabajoId, UUID trabajadorId);

    boolean existsByTrabajoIdAndTrabajadorId(UUID trabajoId, UUID trabajadorId);
}
