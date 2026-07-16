package com.trabajito.modules.notificaciones;

import com.trabajito.common.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

/** Notificación in-app para un usuario. */
@Entity
@Table(name = "notificaciones", indexes = {
        @Index(name = "idx_notif_usuario", columnList = "usuario_id, creado_en")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notificacion extends BaseEntity {

    @Column(name = "usuario_id", nullable = false)
    private UUID usuarioId;

    @Column(nullable = false)
    private String titulo;

    @Column(length = 500)
    private String cuerpo;

    /** Tipo/tema (p. ej. "postulacion", "mensaje", "pago") para enrutar en la app. */
    private String tipo;

    /** Id de la entidad relacionada (trabajo, chat, etc.). */
    private String referenciaId;

    @Builder.Default
    private boolean leida = false;
}
