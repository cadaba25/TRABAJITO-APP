package com.trabajito.modules.usuarios;

import com.trabajito.common.BaseEntity;
import com.trabajito.common.enums.Rol;
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
import org.hibernate.annotations.Check;
import org.hibernate.annotations.DynamicUpdate;

import java.math.BigDecimal;

/**
 * Usuario de la plataforma (trabajador o empleador).
 * Tabla: usuarios.
 */
@Entity
@Table(name = "usuarios", indexes = {
        @Index(name = "idx_usuarios_correo", columnList = "correo", unique = true)
})
// Ultima linea de defensa del dinero, independiente del codigo Java (ADR-0006).
// En BD ya existentes la anade RestriccionSaldoNoNegativo al arrancar: con
// ddl-auto=update Hibernate NO crea checks sobre tablas que ya existen.
@Check(name = "ck_usuarios_saldo_no_negativo", constraints = "saldo >= 0")
// Sin esto, editar el perfil o la reputacion genera un UPDATE de TODAS las
// columnas por dirty-checking, incluida saldo con el valor leido al principio
// de esa transaccion: perderia una recarga concurrente sin tocar la cartera.
@DynamicUpdate
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Usuario extends BaseEntity {

    @Column(nullable = false, unique = true)
    private String correo;

    /** Hash BCrypt. NUNCA se guarda la contraseña en texto plano. */
    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private String nombres;

    @Column(nullable = false)
    private String apellidos;

    private String dni;
    private String telefono;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Rol rol;

    private String fotoUrl;        // ruta a la foto (no el binario)
    private String presentacion;

    @Column(nullable = false)
    @Builder.Default
    private boolean activo = true;

    // ── Ubicación ──
    private String departamento;
    private String ciudad;

    // ── Métricas de reputación / actividad ──
    @Builder.Default
    private int trabajosCompletados = 0;

    @Builder.Default
    private int trabajosPublicados = 0;

    @Builder.Default
    private int pagosConfirmados = 0;

    @Column(precision = 3, scale = 2)
    @Builder.Default
    private BigDecimal calificacionPromedio = BigDecimal.ZERO;

    @Builder.Default
    private int totalCalificaciones = 0;

    // ── Cartera (saldo en Lempiras) ──
    // Los movimientos se registran en MovimientoCartera y se modifican de forma
    // transaccional en PagoService. Nunca desde el cliente.
    @Column(precision = 12, scale = 2, nullable = false)
    @Builder.Default
    private BigDecimal saldo = BigDecimal.ZERO;

    // ── Campos de empleador (opcionales) ──
    private String tipoEmpleador;     // 'persona' | 'empresa'
    private String nombreEmpresa;
    private String rtn;
    private String sectorEmpresa;
    private String tamanoEmpresa;
    private String sitioWeb;

    public String getNombreCompleto() {
        return (nombres + " " + apellidos).trim();
    }
}
