package com.trabajito.modules.auth.dto;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.trabajito.common.enums.Rol;

/**
 * Roles que el registro PÚBLICO ({@code POST /api/auth/registro}, que es
 * {@code permitAll}) puede llegar a crear.
 *
 * <p>Deliberadamente NO incluye {@link Rol#ADMIN}: el rol de dominio nunca se
 * acepta tal cual desde el cliente. Antes, {@code RegistroRequest} declaraba
 * el enum de dominio completo y cualquiera podía auto-registrarse como
 * administrador (ver {@code docs/agent-tasks/008-*.md} y ADR-0005). Con este
 * tipo, {@code ADMIN} deja de ser expresable en la petición: no es un {@code
 * if} que alguien pueda borrar en un refactor, es el tipo el que no lo
 * admite. Los administradores se aprovisionan fuera de la API — ver
 * {@code com.trabajito.config.AdminInicialSeeder} y {@code backend/README.md}.
 */
public enum RolPublico {

    TRABAJADOR(Rol.TRABAJADOR),
    EMPLEADOR(Rol.EMPLEADOR);

    private final Rol rol;

    RolPublico(Rol rol) {
        this.rol = rol;
    }

    /** Traduce al enum de dominio que se persiste en {@code usuarios.rol}. */
    public Rol aRol() {
        return rol;
    }

    /**
     * Deserialización tolerante a propósito: cualquier valor que no sea
     * {@code TRABAJADOR} o {@code EMPLEADOR} (incluidos {@code "ADMIN"} y
     * {@code "SUPERJEFE"}) se convierte en {@code null} en vez de lanzar.
     *
     * <p>El {@code @NotNull} de {@code RegistroRequest} lo transforma
     * entonces en un 400 de validación uniforme. Si dejáramos que Jackson
     * lanzara {@code HttpMessageNotReadableException}, hoy caería en el
     * handler genérico de {@code GlobalExceptionHandler} y devolvería un 500
     * (ese mapeo global es alcance de la tarea 009, no de esta).
     */
    @JsonCreator
    public static RolPublico desde(String valor) {
        if (valor == null) return null;
        String limpio = valor.trim();
        for (RolPublico candidato : values()) {
            if (candidato.name().equalsIgnoreCase(limpio)) return candidato;
        }
        return null;
    }
}
