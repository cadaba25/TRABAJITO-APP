package com.trabajito.modules.usuarios;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ExperienciaRepository extends JpaRepository<Experiencia, UUID> {

    /** Historial de un trabajador, lo más reciente primero. */
    List<Experiencia> findByUsuarioIdOrderByCreadoEnAsc(UUID usuarioId);

    long countByUsuarioId(UUID usuarioId);
}
