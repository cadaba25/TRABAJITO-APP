package com.trabajito.modules.pagos;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface MovimientoCarteraRepository extends JpaRepository<MovimientoCartera, UUID> {

    List<MovimientoCartera> findByUsuarioIdOrderByCreadoEnDesc(UUID usuarioId);
}
