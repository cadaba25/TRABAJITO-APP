package com.trabajito.modules.reportes;

import com.trabajito.common.BaseEntity;
import com.trabajito.common.enums.EstadoReporte;
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

import java.util.UUID;

/** Reporte/denuncia (problema en un trabajo, usuario, etc.). */
@Entity
@Table(name = "reportes", indexes = {
        @Index(name = "idx_reportes_estado", columnList = "estado, creado_en")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Reporte extends BaseEntity {

    /** Quién reporta. */
    @Column(name = "reportante_id", nullable = false)
    private UUID reportanteId;

    /** Trabajo o usuario reportado (opcional según el motivo). */
    @Column(name = "trabajo_id")
    private UUID trabajoId;
    @Column(name = "reportado_id")
    private UUID reportadoId;

    @Column(nullable = false)
    private String motivo;

    @Column(length = 2000)
    private String descripcion;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private EstadoReporte estado = EstadoReporte.ABIERTO;

    /** Resolución del administrador. */
    @Column(length = 2000)
    private String resolucion;
}
