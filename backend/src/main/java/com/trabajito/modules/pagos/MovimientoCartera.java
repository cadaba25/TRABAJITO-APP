package com.trabajito.modules.pagos;

import com.trabajito.common.BaseEntity;
import com.trabajito.common.enums.TipoMovimiento;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
 * Registro de un movimiento de saldo (historial/auditoría de la cartera).
 * Tabla: movimientos_cartera.
 */
@Entity
@Table(name = "movimientos_cartera", indexes = {
        @Index(name = "idx_mov_usuario", columnList = "usuario_id, creado_en")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MovimientoCartera extends BaseEntity {

    @Column(name = "usuario_id", nullable = false)
    private UUID usuarioId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TipoMovimiento tipo;

    /** Monto positivo (crédito) o negativo (débito) aplicado al saldo. */
    @Column(precision = 12, scale = 2, nullable = false)
    private BigDecimal monto;

    /** Saldo resultante tras aplicar el movimiento (para auditoría). */
    @Column(precision = 12, scale = 2, nullable = false)
    private BigDecimal saldoResultante;

    /** Trabajo asociado, si aplica (retención/liberación/reembolso). */
    @Column(name = "trabajo_id")
    private UUID trabajoId;

    private String descripcion;
}
