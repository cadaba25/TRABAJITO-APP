package com.trabajito.modules.chats;

import com.trabajito.common.BaseEntity;
import com.trabajito.common.enums.TipoMensaje;
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

/** Mensaje dentro de una sala de chat. Tabla: mensajes. */
@Entity
@Table(name = "mensajes", indexes = {
        @Index(name = "idx_mensajes_chat", columnList = "chat_id, creado_en")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Mensaje extends BaseEntity {

    @Column(name = "chat_id", nullable = false)
    private UUID chatId;

    @Column(name = "de_uid", nullable = false)
    private UUID deUid;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private TipoMensaje tipo = TipoMensaje.TEXTO;

    @Column(length = 2000, nullable = false)
    private String contenido;

    @Builder.Default
    private boolean leido = false;
}
