package com.trabajito.modules.evidencias;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface EvidenciaRepository extends JpaRepository<Evidencia, UUID> {

    List<Evidencia> findByTrabajoIdOrderByCreadoEnAsc(UUID trabajoId);
}
