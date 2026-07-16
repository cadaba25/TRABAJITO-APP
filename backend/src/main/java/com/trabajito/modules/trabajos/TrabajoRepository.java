package com.trabajito.modules.trabajos;

import com.trabajito.common.enums.EstadoTrabajo;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface TrabajoRepository extends JpaRepository<Trabajo, UUID> {

    /** Feed: trabajos por estado (paginado, ordenado por fecha desc en el Pageable). */
    Page<Trabajo> findByEstado(EstadoTrabajo estado, Pageable pageable);

    List<Trabajo> findByEmpleadorIdOrderByCreadoEnDesc(UUID empleadorId);

    List<Trabajo> findByTrabajadorAsignadoIdOrderByCreadoEnDesc(UUID trabajadorId);
}
