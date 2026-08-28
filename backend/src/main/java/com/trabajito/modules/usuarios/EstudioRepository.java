package com.trabajito.modules.usuarios;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface EstudioRepository extends JpaRepository<Estudio, UUID> {

    List<Estudio> findByUsuarioIdOrderByCreadoEnAsc(UUID usuarioId);

    long countByUsuarioId(UUID usuarioId);
}
