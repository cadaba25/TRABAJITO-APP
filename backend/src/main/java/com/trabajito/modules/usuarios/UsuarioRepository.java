package com.trabajito.modules.usuarios;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UsuarioRepository extends JpaRepository<Usuario, UUID> {

    Optional<Usuario> findByCorreo(String correo);

    boolean existsByCorreo(String correo);

    /**
     * Carga el usuario bloqueando su fila ({@code SELECT ... FOR UPDATE}).
     *
     * <p>Obligatorio en toda transacción que vaya a escribir {@code saldo}
     * (ADR-0006). Dos avisos:
     * <ul>
     *   <li>Hay que llamarlo <b>antes</b> de leer la entidad de cualquier otra
     *       forma en la misma transacción: si ya está en la caché de primer
     *       nivel, Hibernate bloquea la fila pero devuelve la copia vieja.</li>
     *   <li>Si hay que bloquear varios usuarios, siempre en orden ascendente
     *       de UUID, para que dos transacciones no se esperen en círculo.</li>
     * </ul>
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from Usuario u where u.id = :id")
    Optional<Usuario> findByIdParaActualizar(@Param("id") UUID id);

    /** Ranking: trabajadores activos ordenados por trabajos completados. */
    List<Usuario> findTop50ByRolAndActivoTrueOrderByTrabajosCompletadosDesc(
            com.trabajito.common.enums.Rol rol);
}
