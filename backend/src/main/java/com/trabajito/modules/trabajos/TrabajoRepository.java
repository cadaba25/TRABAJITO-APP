package com.trabajito.modules.trabajos;

import com.trabajito.common.enums.EstadoTrabajo;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TrabajoRepository extends JpaRepository<Trabajo, UUID> {

    /**
     * Carga el trabajo bloqueando su fila ({@code SELECT ... FOR UPDATE}).
     *
     * <p>Lo usa toda transición del ciclo de vida del contrato: sin esto, dos
     * peticiones simultáneas leen las mismas banderas {@code pagoRetenido} /
     * {@code pagoLiberado} y las dos se creen la primera (ADR-0006). Es el
     * <b>primer</b> bloqueo que toma cada transacción: trabajos antes que
     * usuarios.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from Trabajo t where t.id = :id")
    Optional<Trabajo> findByIdParaActualizar(@Param("id") UUID id);

    /** Feed: trabajos por estado (paginado, ordenado por fecha desc en el Pageable). */
    Page<Trabajo> findByEstado(EstadoTrabajo estado, Pageable pageable);

    /** Cola de soporte: trabajos EN_DISPUTA, del más antiguo al más nuevo. */
    List<Trabajo> findByEstadoOrderByCreadoEnAsc(EstadoTrabajo estado);

    List<Trabajo> findByEmpleadorIdOrderByCreadoEnDesc(UUID empleadorId);

    List<Trabajo> findByTrabajadorAsignadoIdOrderByCreadoEnDesc(UUID trabajadorId);
}
