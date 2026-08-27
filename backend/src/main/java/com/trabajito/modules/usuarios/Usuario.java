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
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.DynamicUpdate;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Usuario de la plataforma (trabajador o empleador).
 * Tabla: usuarios.
 *
 * <p><b>Columnas nuevas y {@code ddl-auto=update} (tarea 019).</b> Hibernate
 * puede <i>añadir</i> columnas a una tabla que ya existe, pero no puede añadir
 * una columna {@code NOT NULL} sin valor por defecto a una tabla con filas
 * (PostgreSQL lo rechaza y el arranque se quedaría sin la columna). Por eso
 * todo lo que se añadió en la tarea 019 lleva {@link ColumnDefault} y
 * <b>no</b> lleva {@code nullable = false}: el DEFAULT rellena las filas
 * viejas. La red de seguridad está en
 * {@code config.RellenoPerfilYReputacion}, que además pone a 0 cualquier
 * hueco que quedara. Lo correcto sería Flyway; ver ADR-0011.
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

    /** Contacto de emergencia (paso 2 del registro de trabajador). */
    @Column(name = "telefono_emergencia")
    private String telefonoEmergencia;

    /**
     * Fecha de nacimiento. Es la ÚNICA fecha del perfil que se guarda como
     * fecha real: de ella depende la regla de ser mayor de 18 años, que hasta
     * ahora solo comprobaba el cliente (y un cliente no valida nada de verdad).
     * Se acepta {@code dd/MM/yyyy} —lo que manda el formulario— o ISO
     * {@code yyyy-MM-dd}; se devuelve siempre en ISO.
     */
    @Column(name = "fecha_nacimiento")
    private LocalDate fechaNacimiento;

    private String genero;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Rol rol;

    private String fotoUrl;        // ruta a la foto (no el binario)
    private String presentacion;

    /** Ruta del CV subido (paso 3 del registro). El binario va a /uploads. */
    @Column(name = "url_cv", length = 500)
    private String urlCV;

    @Column(nullable = false)
    @Builder.Default
    private boolean activo = true;

    /**
     * El registro de 5 pasos terminó. Equivale al {@code registroCompleto} de
     * Firestore: una cuenta creada por la API queda a medias hasta que el
     * cliente completa los pasos.
     */
    @Column(name = "registro_completo")
    @ColumnDefault("false")
    @Builder.Default
    private boolean registroCompleto = false;

    // ── Ubicación ──
    private String departamento;
    private String ciudad;

    @Column(name = "codigo_postal")
    private String codigoPostal;

    @ColumnDefault("'Honduras'")
    @Builder.Default
    private String pais = "Honduras";

    @Column(name = "vive_en_honduras")
    @ColumnDefault("true")
    @Builder.Default
    private boolean viveEnHonduras = true;

    // ── Métricas de reputación / actividad ──
    @Builder.Default
    private int trabajosCompletados = 0;

    @Builder.Default
    private int trabajosPublicados = 0;

    @Builder.Default
    private int pagosConfirmados = 0;

    /**
     * Reputación GLOBAL (todas las calificaciones recibidas, del rol que sean).
     * Se conserva por compatibilidad con lo que ya existía y con el modelo de
     * Firestore; la que hay que enseñar en el perfil es la del rol
     * correspondiente (ver los cuatro campos de abajo).
     */
    @Column(precision = 3, scale = 2)
    @Builder.Default
    private BigDecimal calificacionPromedio = BigDecimal.ZERO;

    @Builder.Default
    private int totalCalificaciones = 0;

    // ── Reputación separada por rol (tarea 019) ──
    // Decisión del dueño: "dos diferentes para cada rol". Ser buen trabajador
    // y ser buen contratista son cosas distintas y se califican aparte. Quién
    // suma dónde lo decide CalificacionService a partir del papel que tenía el
    // RECEPTOR en ese trabajo, nunca de su rol de cuenta.
    @Column(name = "calificacion_como_trabajador", precision = 3, scale = 2)
    @ColumnDefault("0")
    @Builder.Default
    private BigDecimal calificacionComoTrabajador = BigDecimal.ZERO;

    @Column(name = "total_calificaciones_como_trabajador")
    @ColumnDefault("0")
    @Builder.Default
    private int totalCalificacionesComoTrabajador = 0;

    @Column(name = "calificacion_como_empleador", precision = 3, scale = 2)
    @ColumnDefault("0")
    @Builder.Default
    private BigDecimal calificacionComoEmpleador = BigDecimal.ZERO;

    @Column(name = "total_calificaciones_como_empleador")
    @ColumnDefault("0")
    @Builder.Default
    private int totalCalificacionesComoEmpleador = 0;

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

    /** Puesto de la persona de contacto dentro de la empresa. */
    @Column(name = "cargo_contacto")
    private String cargoContacto;

    private String sectorEmpresa;
    private String tamanoEmpresa;
    private String sitioWeb;

    @Column(name = "descripcion_empresa", length = 1000)
    private String descripcionEmpresa;

    public String getNombreCompleto() {
        return (nombres + " " + apellidos).trim();
    }
}
