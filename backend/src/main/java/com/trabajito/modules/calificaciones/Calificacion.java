package com.trabajito.modules.calificaciones;

import com.trabajito.common.BaseEntity;
import com.trabajito.common.enums.RolCalificado;
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
 * Calificación de una parte a la otra por un trabajo. Una persona solo puede
 * calificar una vez por trabajo (restricción única).
 */
@Entity
@Table(name = "calificaciones",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_calificacion_trabajo_autor",
                columnNames = {"trabajo_id", "autor_id"}),
        indexes = {
                @Index(name = "idx_calif_receptor", columnList = "receptor_id"),
                @Index(name = "idx_calif_receptor_rol", columnList = "receptor_id, rol_calificado")
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

    /**
     * Papel del RECEPTOR en ese trabajo, que es lo que decide en cuál de sus
     * dos reputaciones suma la calificación (tarea 019).
     *
     * <p>La columna se declara <b>sin</b> {@code nullable = false} a propósito:
     * con {@code ddl-auto=update} PostgreSQL no deja añadir una columna NOT NULL
     * a una tabla que ya tiene filas, y el arranque se quedaría sin la columna.
     * Las filas anteriores a esta tarea las rellena
     * {@code config.RellenoPerfilYReputacion} deduciendo el papel del trabajo.
     * En código, {@code CalificacionService} siempre la escribe.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "rol_calificado", length = 20)
    private RolCalificado rolCalificado;

    @Column(nullable = false)
    private int estrellas;   // 1..5

    @Column(length = 1000)
    private String comentario;
}
