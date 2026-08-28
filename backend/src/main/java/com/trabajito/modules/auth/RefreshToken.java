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

import java.time.Instant;
import java.util.UUID;

/**
 * Token de refresco de sesión (tarea 015, ADR-0010).
 *
 * <p>El valor real es una cadena opaca aleatoria que el cliente guarda; aquí
 * solo se persiste su <b>hash SHA-256</b> ({@code tokenHash}), para que una
 * fuga de esta tabla no entregue sesiones utilizables. La sesión es revocable
 * porque su validez depende de esta fila, no de una firma.
 *
 * <p>Los tokens de una misma sesión comparten {@code familia}: al rotar (cada
 * uso de {@code /api/auth/refresh}) se revoca el anterior y se emite otro de la
 * misma familia. Si se reutiliza uno ya revocado, se revoca toda la familia
 * (detección de robo).
 */
@Entity
@Table(name = "refresh_tokens", indexes = {
        @Index(name = "idx_refresh_hash", columnList = "tokenHash", unique = true),
        @Index(name = "idx_refresh_usuario", columnList = "usuarioId"),
        @Index(name = "idx_refresh_familia", columnList = "familia")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RefreshToken extends BaseEntity {

    @Column(nullable = false, unique = true)
    private String tokenHash;

    @Column(nullable = false)
    private UUID usuarioId;

    /** Agrupa los tokens rotados de una misma sesión. */
    @Column(nullable = false)
    private UUID familia;

    @Column(nullable = false)
    private Instant expiraEn;

    @Column(nullable = false)
    @Builder.Default
    private boolean revocado = false;

    public boolean estaVigente() {
        return !revocado && expiraEn.isAfter(Instant.now());
    }
}
