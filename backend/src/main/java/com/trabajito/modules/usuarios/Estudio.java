package com.trabajito.modules.usuarios;

import com.trabajito.common.BaseEntity;
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
 * Un estudio del trabajador (paso 5 del registro). Mismo modelado y mismas
 * razones que {@link Experiencia} (ADR-0011): tabla propia con FK a
 * {@code usuarios} y fechas en texto porque el formulario pide {@code MM/AAAA}.
 */
@Entity
@Table(name = "estudios", indexes = {
        @Index(name = "idx_estudios_usuario", columnList = "usuario_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Estudio extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false,
            foreignKey = @ForeignKey(name = "fk_estudios_usuario"))
    private Usuario usuario;

    /** Primaria, secundaria, universidad, técnico... (lista de la app). */
    @Column(nullable = false, length = 100)
    private String nivel;

    @Column(nullable = false, length = 150)
    private String centro;

    @Column(name = "fecha_inicio", length = 20)
    private String fechaInicio;

    /** Vacío si lo sigue cursando. */
    @Column(name = "fecha_fin", length = 20)
    private String fechaFin;

    @Column(name = "cursando_actualmente", nullable = false)
    @Builder.Default
    private boolean cursandoActualmente = false;
}
