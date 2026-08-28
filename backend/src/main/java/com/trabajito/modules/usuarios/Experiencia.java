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
 * Un puesto del historial laboral de un trabajador (paso 4 del registro).
 *
 * <p><b>Por qué es una tabla y no una columna JSON</b> (ADR-0011): en Firestore
 * la experiencia va embebida como una lista de mapas dentro del documento del
 * usuario; aquí es una fila por puesto, con clave ajena a {@code usuarios}. Así
 * la reputación/el perfil se pueden consultar sin traerse el CV entero, y
 * editar un puesto no reescribe la fila del usuario (que lleva el {@code saldo}
 * y depende de {@code @DynamicUpdate} para no pisarlo, ADR-0006).
 *
 * <p><b>Las fechas son texto a propósito.</b> El formulario de Flutter pide
 * {@code MM/AAAA}: son fechas <i>parciales</i> (sin día), y convertirlas a
 * {@code LocalDate} obligaría a inventar un día. Se guardan tal cual llegan
 * para que la migración desde Firestore no cambie ni un carácter de lo que el
 * usuario escribió. La única fecha real del perfil —
 * {@code Usuario.fechaNacimiento} — sí es {@code LocalDate}, porque de ella
 * depende una regla de negocio (ser mayor de 18).
 */
@Entity
@Table(name = "experiencias", indexes = {
        @Index(name = "idx_experiencias_usuario", columnList = "usuario_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Experiencia extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false,
            foreignKey = @ForeignKey(name = "fk_experiencias_usuario"))
    private Usuario usuario;

    @Column(nullable = false, length = 150)
    private String empresa;

    @Column(nullable = false, length = 150)
    private String puesto;

    /** Texto libre con lo que hacía en ese puesto (así lo manda el registro). */
    @Column(length = 300)
    private String habilidades;

    @Column(length = 1000)
    private String descripcion;

    /** Formato del cliente, normalmente {@code MM/AAAA}. Ver javadoc de la clase. */
    @Column(name = "fecha_inicio", length = 20)
    private String fechaInicio;

    /** Vacío si sigue trabajando ahí. */
    @Column(name = "fecha_fin", length = 20)
    private String fechaFin;

    @Column(name = "trabaja_actualmente", nullable = false)
    @Builder.Default
    private boolean trabajaActualmente = false;
}
