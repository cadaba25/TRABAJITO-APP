package com.trabajito.modules.auth;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.UUID;

/**
 * Conteo de intentos de login para el freno de fuerza bruta (ADR-0010).
 *
 * <p>La lógica de bloqueo no depende de que el almacén sea PostgreSQL: si algún
 * día se mueve el contador a Redis, se cambia esta implementación sin tocar
 * {@code AuthService}.
 */
public interface IntentoLoginRepository extends JpaRepository<IntentoLogin, UUID> {

    /** Intentos FALLIDOS desde una IP a partir de un instante (ventana deslizante). */
    long countByIpAndExitoFalseAndCreadoEnAfter(String ip, Instant desde);

    /** Intentos FALLIDOS contra una cuenta a partir de un instante (ventana deslizante). */
    long countByCorreoAndExitoFalseAndCreadoEnAfter(String correo, Instant desde);

    /**
     * Borra los intentos fallidos de una cuenta. Se llama tras un login
     * correcto: el dueño legítimo entra y su cuenta deja de estar "con
     * fricción". El atacante no puede disparar esto porque no conoce la
     * contraseña (ADR-0010).
     */
    @Modifying
    @Query("delete from IntentoLogin i where i.correo = :correo and i.exito = false")
    void borrarFallosDeCuenta(@Param("correo") String correo);
}
