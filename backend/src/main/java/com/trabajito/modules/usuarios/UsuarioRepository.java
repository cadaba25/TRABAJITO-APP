package com.trabajito.modules.usuarios;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UsuarioRepository extends JpaRepository<Usuario, UUID> {

    Optional<Usuario> findByCorreo(String correo);

    boolean existsByCorreo(String correo);

    /** Ranking: trabajadores activos ordenados por trabajos completados. */
    List<Usuario> findTop50ByRolAndActivoTrueOrderByTrabajosCompletadosDesc(
            com.trabajito.common.enums.Rol rol);
}
