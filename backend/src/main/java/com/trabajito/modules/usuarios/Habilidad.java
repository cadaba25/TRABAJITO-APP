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
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Una etiqueta de lo que sabe hacer un trabajador ("Electricidad",
 * "Carpintería"...). En Firestore es un array de strings dentro del usuario;
 * aquí es una fila por etiqueta (ADR-0011).
 *
 * <p>Se modela como tabla —y no como columna de texto separada por comas—
 * porque el feed tiene que poder <b>filtrar por habilidad</b>: con una fila por
 * etiqueta e índice sobre {@code habilidad} eso es un {@code WHERE} normal; con
 * una cadena obligaría a un {@code LIKE '%...%'} que ningún índice ayuda.
 */
@Entity
@Table(name = "habilidades",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_habilidad_usuario",
                columnNames = {"usuario_id", "habilidad"}),
        indexes = {
                @Index(name = "idx_habilidades_usuario", columnList = "usuario_id"),
                @Index(name = "idx_habilidades_habilidad", columnList = "habilidad")
        })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Habilidad extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false,
            foreignKey = @ForeignKey(name = "fk_habilidades_usuario"))
    private Usuario usuario;

    @Column(nullable = false, length = 60)
    private String habilidad;
}
