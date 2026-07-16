package com.trabajito.modules.calificaciones;

import com.trabajito.common.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
 * Calificación de una parte a la otra por un trabajo. Una persona solo puede
 * calificar una vez por trabajo (restricción única).
 */
@Entity
@Table(name = "calificaciones",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_calificacion_trabajo_autor",
                columnNames = {"trabajo_id", "autor_id"}),
        indexes = {
                @Index(name = "idx_calif_receptor", columnList = "receptor_id")
        })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Calificacion extends BaseEntity {

    @Column(name = "trabajo_id", nullable = false)
    private UUID trabajoId;

    @Column(name = "autor_id", nullable = false)
    private UUID autorId;

    @Column(name = "receptor_id", nullable = false)
    private UUID receptorId;

    @Column(nullable = false)
    private int estrellas;   // 1..5

    @Column(length = 1000)
    private String comentario;
}
