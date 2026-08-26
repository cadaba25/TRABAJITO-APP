package com.trabajito.modules.evidencias;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface EvidenciaRepository extends JpaRepository<Evidencia, UUID> {

    List<Evidencia> findByTrabajoIdOrderByCreadoEnAsc(UUID trabajoId);

    /** ¿El trabajador subió alguna evidencia de este trabajo? (entrega, ADR-0007) */
    boolean existsByTrabajoIdAndAutorId(UUID trabajoId, UUID autorId);

    /** ¿Subió alguna DESPUÉS de que el empleador pidiera correcciones? */
    boolean existsByTrabajoIdAndAutorIdAndCreadoEnAfter(UUID trabajoId, UUID autorId, Instant creadoEn);
}
