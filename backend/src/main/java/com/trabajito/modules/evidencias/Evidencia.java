package com.trabajito.modules.evidencias;

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

/**
 * Avance/evidencia de un trabajo. El texto es obligatorio; la URL de archivo
 * (foto/video) es opcional y apunta a un archivo servido por el backend.
 */
@Entity
@Table(name = "evidencias", indexes = {
        @Index(name = "idx_evidencias_trabajo", columnList = "trabajo_id, creado_en")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Evidencia extends BaseEntity {

    @Column(name = "trabajo_id", nullable = false)
    private UUID trabajoId;

    @Column(name = "autor_id", nullable = false)
    private UUID autorId;

    private String autorNombre;

    @Column(length = 2000, nullable = false)
    private String texto;

    /** Ruta al archivo adjunto (opcional). Solo la ruta, no el binario. */
    private String archivoUrl;
}
