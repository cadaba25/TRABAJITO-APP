package com.trabajito.modules.pagos;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface TarjetaRepository extends JpaRepository<Tarjeta, UUID> {

    List<Tarjeta> findByUsuarioIdOrderByCreadoEnDesc(UUID usuarioId);

    long countByUsuarioId(UUID usuarioId);
}
