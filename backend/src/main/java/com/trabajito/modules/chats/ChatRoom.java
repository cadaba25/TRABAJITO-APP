package com.trabajito.modules.chats;

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

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Sala de chat de un trabajo (una por trabajo asignado). Guarda además el
 * estado de la negociación de pago y tiempo.
 */
@Entity
@Table(name = "chat_rooms", indexes = {
        @Index(name = "idx_chat_trabajo", columnList = "trabajo_id", unique = true),
        @Index(name = "idx_chat_empleador", columnList = "empleador_id"),
        @Index(name = "idx_chat_trabajador", columnList = "trabajador_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChatRoom extends BaseEntity {

    @Column(name = "trabajo_id", nullable = false)
    private UUID trabajoId;

    private String tituloTrabajo;

    @Column(name = "empleador_id", nullable = false)
    private UUID empleadorId;
    private String empleadorNombre;

    @Column(name = "trabajador_id", nullable = false)
    private UUID trabajadorId;
    private String trabajadorNombre;

    private String ultimoMensaje;
    private Instant fechaUltimoMensaje;

    // ── Negociación de pago ──
    @Column(precision = 12, scale = 2)
    @Builder.Default
    private BigDecimal pagoMonto = BigDecimal.ZERO;
    private UUID pagoPropuestoPor;
    @Builder.Default
    private boolean pagoAcordado = false;

    // ── Negociación de tiempo ──
    private String tiempoValor;
    private UUID tiempoPropuestoPor;
    @Builder.Default
    private boolean tiempoAcordado = false;

    public boolean esParticipante(UUID uid) {
        return empleadorId.equals(uid) || trabajadorId.equals(uid);
    }
}
