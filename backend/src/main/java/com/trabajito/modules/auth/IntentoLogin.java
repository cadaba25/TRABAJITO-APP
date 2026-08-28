package com.trabajito.modules.auth;

import com.trabajito.common.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Registro de un intento de login (tarea 015, ADR-0010). Se usa para frenar la
 * fuerza bruta: se cuentan los intentos FALLIDOS por IP y por cuenta dentro de
 * una ventana deslizante.
 *
 * <p>Se guarda en PostgreSQL (no en Redis, que no existe en el repo — ver
 * ADR-0010): el volumen de logins es bajo y una tabla indexada sobra. Nunca
 * guarda la contraseña ni el token; solo correo, IP y sello de tiempo.
 */
@Entity
@Table(name = "intentos_login", indexes = {
        @Index(name = "idx_intentos_correo_fecha", columnList = "correo, creadoEn"),
        @Index(name = "idx_intentos_ip_fecha", columnList = "ip, creadoEn")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IntentoLogin extends BaseEntity {

    /** Correo (normalizado) contra el que se intentó entrar. */
    @Column(nullable = false)
    private String correo;

    /** IP de origen del intento (según ADR-0010: getRemoteAddr o XFF si se confía). */
    @Column(nullable = false)
    private String ip;

    /** true si el intento terminó en login correcto; false si falló. */
    @Column(nullable = false)
    private boolean exito;
}
