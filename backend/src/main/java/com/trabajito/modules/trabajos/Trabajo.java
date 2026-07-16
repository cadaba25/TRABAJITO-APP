package com.trabajito.modules.trabajos;

import com.trabajito.common.BaseEntity;
import com.trabajito.common.enums.EstadoTrabajo;
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
import java.time.Instant;
import java.util.UUID;

/**
 * Publicación de trabajo/servicio y su contrato asociado.
 * Tabla: trabajos.
 *
 * <p>Se guardan referencias por UUID (empleadorId, trabajadorAsignadoId) y los
 * nombres desnormalizados para mostrar sin joins, igual que en el modelo actual.
 */
@Entity
@Table(name = "trabajos", indexes = {
        @Index(name = "idx_trabajos_estado_fecha", columnList = "estado, creado_en"),
        @Index(name = "idx_trabajos_empleador", columnList = "empleador_id"),
        @Index(name = "idx_trabajos_trabajador", columnList = "trabajador_asignado_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Trabajo extends BaseEntity {

    // ── Publicación ──
    @Column(name = "empleador_id", nullable = false)
    private UUID empleadorId;

    private String autorNombre;      // nombre visible del empleador/empresa

    @Column(nullable = false)
    private String titulo;

    @Column(length = 4000)
    private String descripcion;

    private String categoria;
    private String departamento;
    private String ciudad;
    private String zona;
    private String presupuesto;      // texto libre ("L. 800", "A convenir")
    private String plazo;            // 'Corto plazo' | 'Medio plazo' | 'Largo plazo'

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private EstadoTrabajo estado = EstadoTrabajo.ACTIVO;

    // ── Asignación ──
    @Column(name = "trabajador_asignado_id")
    private UUID trabajadorAsignadoId;
    private String trabajadorAsignadoNombre;

    // ── Contrato / escrow ──
    @Column(precision = 12, scale = 2)
    @Builder.Default
    private BigDecimal montoAcordado = BigDecimal.ZERO;

    private String tiempoAcordado;
    private Instant fechaAcuerdo;
    private Instant fechaInicio;

    @Builder.Default
    private boolean pagoRetenido = false;
    @Builder.Default
    private boolean entregado = false;
    @Builder.Default
    private boolean pagoLiberado = false;
    @Builder.Default
    private boolean correccionSolicitada = false;
    private String motivoCorreccion;

    // ── Calificaciones ──
    @Builder.Default
    private boolean calificadoPorEmpleador = false;
    @Builder.Default
    private boolean calificadoPorTrabajador = false;
}
