package com.trabajito.modules.auth;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /** Revoca de golpe toda una familia (uso: reutilización de un token robado). */
    @Modifying
    @Query("update RefreshToken r set r.revocado = true where r.familia = :familia and r.revocado = false")
    int revocarFamilia(@Param("familia") UUID familia);

    /** Revoca todas las sesiones de un usuario (uso futuro: "cerrar todas las sesiones"). */
    @Modifying
    @Query("update RefreshToken r set r.revocado = true where r.usuarioId = :usuarioId and r.revocado = false")
    int revocarTodosDeUsuario(@Param("usuarioId") UUID usuarioId);
}
