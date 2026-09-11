package com.trabajito.modules.pagos;

import com.trabajito.common.BaseEntity;
import com.trabajito.modules.usuarios.Usuario;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.ForeignKey;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Tarjeta guardada en la cartera del usuario (tarea 030).
 *
 * <p>Prototipo sin pasarela de pago real, igual que el resto de {@code pagos}
 * (ver {@link PagoService}) y que su equivalente en Firestore
 * ({@code usuarios/{uid}/tarjetas}, {@code lib/models/tarjeta.dart}). Por eso
 * <b>nunca</b> hay un campo para el número completo ni el CVV: el cliente ya
 * los descarta antes de llamar a esta API, y el servidor tampoco los acepta
 * como algo que se persista (ver {@link TarjetaService}).
 *
 * <p>FK real a {@code usuarios}, siguiendo el patrón que introdujo la tarea
 * 019 (ADR-0011) para {@code Habilidad}/{@code Experiencia}/{@code Estudio},
 * no el resto del esquema (que referencia por UUID suelto).
 */
@Entity
@Table(name = "tarjetas", indexes = {
        @Index(name = "idx_tarjetas_usuario", columnList = "usuario_id, creado_en")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Tarjeta extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false,
            foreignKey = @ForeignKey(name = "fk_tarjetas_usuario"))
    private Usuario usuario;

    /** visa | mastercard | amex | otra (deducida del número, ver {@link TarjetaService}). */
    @Column(length = 20)
    private String marca;

    @Column(name = "ultimos4", length = 4)
    private String ultimos4;

    @Column(length = 150)
    private String titular;

    /** Texto libre "MM/AA". No se valida como fecha real: es prototipo. */
    @Column(length = 10)
    private String vencimiento;
}
