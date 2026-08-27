package com.trabajito.modules.usuarios;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface HabilidadRepository extends JpaRepository<Habilidad, UUID> {

    List<Habilidad> findByUsuarioIdOrderByHabilidadAsc(UUID usuarioId);

    void deleteByUsuarioId(UUID usuarioId);
}
