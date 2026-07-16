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
import java.util.UUID;

/**
 * Registro histórico de una propuesta de pago/tiempo dentro de un chat
 * (la negociación con contrapropuestas). Tabla: propuestas.
 */
@Entity
@Table(name = "propuestas", indexes = {
        @Index(name = "idx_propuestas_chat", columnList = "chat_id, creado_en")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Propuesta extends BaseEntity {

    @Column(name = "chat_id", nullable = false)
    private UUID chatId;

    @Column(name = "creada_por", nullable = false)
    private UUID creadaPor;

    /** Monto por hora propuesto (nullable si la propuesta es solo de tiempo). */
    @Column(precision = 12, scale = 2)
    private BigDecimal precio;

    /** Tiempo propuesto (texto, nullable si la propuesta es solo de pago). */
    private String tiempo;

    @Builder.Default
    private boolean aceptada = false;
}
