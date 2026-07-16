package com.trabajito.modules.postulaciones;

import com.trabajito.common.BaseEntity;
import com.trabajito.common.enums.EstadoPostulacion;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

/**
 * Postulación de un trabajador a un trabajo.
 * Un trabajador solo puede postularse una vez por trabajo (restricción única).
 */
@Entity
@Table(name = "postulaciones",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_postulacion_trabajo_trabajador",
                columnNames = {"trabajo_id", "trabajador_id"}),
        indexes = {
                @Index(name = "idx_post_trabajo", columnList = "trabajo_id"),
                @Index(name = "idx_post_trabajador", columnList = "trabajador_id")
        })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Postulacion extends BaseEntity {

    @Column(name = "trabajo_id", nullable = false)
    private UUID trabajoId;

    @Column(name = "trabajador_id", nullable = false)
    private UUID trabajadorId;

    private String trabajadorNombre;

    @Column(length = 1000)
    private String mensaje;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private EstadoPostulacion estado = EstadoPostulacion.PENDIENTE;
}
