package com.trabajito.common;

import jakarta.persistence.Column;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * Clase base para todas las entidades: id (UUID) y marcas de tiempo de
 * creación/actualización gestionadas automáticamente.
 */
@Getter
@Setter
@MappedSuperclass
public abstract class BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(nullable = false, updatable = false)
    private Instant creadoEn;

    @Column(nullable = false)
    private Instant actualizadoEn;

    @PrePersist
    void onCreate() {
        creadoEn = Instant.now();
        actualizadoEn = creadoEn;
    }

    @PreUpdate
    void onUpdate() {
        actualizadoEn = Instant.now();
    }
}
