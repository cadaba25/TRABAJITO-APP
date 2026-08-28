package com.trabajito.modules.usuarios.dto;

import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Campos editables del perfil por su dueño (todos opcionales: {@code null}
 * significa "no lo toques").
 *
 * <p>Lo que NO se puede tocar aquí sigue igual que antes y a propósito:
 * {@code rol} (ADR-0005), {@code correo}, {@code saldo} y cualquier contador
 * de reputación. Se ignoran en silencio si llegan en el cuerpo.
 *
 * <p><b>Los {@code @Size} valen 255 porque las columnas ya existentes son
 * {@code varchar(255)}</b> y {@code ddl-auto=update} no ensancha columnas de
 * una tabla que ya existe: declarar aquí un máximo mayor haría pasar los tests
 * (H2 se recrea en cada arranque) y fallar el servidor real con un 500 del
 * driver. Ver ADR-0011.
 *
 * <p>{@code habilidades}, si viene, REEMPLAZA la lista completa (el formulario
 * las maneja como un conjunto y manda siempre el conjunto entero). Si es
 * {@code null}, no se tocan.
 */
public record ActualizarPerfilRequest(
        @Size(max = 255) String nombres,
        @Size(max = 255) String apellidos,
        @Size(max = 255) String telefono,
        @Size(max = 255) String telefonoEmergencia,
        // dd/MM/yyyy (lo que manda el formulario) o ISO yyyy-MM-dd.
        @Size(max = 20) String fechaNacimiento,
        @Size(max = 255) String genero,
        @Size(max = 255) String presentacion,
        @Size(max = 500) String urlCV,
        @Size(max = 255) String departamento,
        @Size(max = 255) String ciudad,
        @Size(max = 255) String codigoPostal,
        @Size(max = 255) String pais,
        Boolean viveEnHonduras,
        @Size(max = 255) String fotoUrl,
        Boolean registroCompleto,
        @Size(max = 255) String tipoEmpleador,
        @Size(max = 255) String nombreEmpresa,
        @Size(max = 255) String rtn,
        @Size(max = 255) String cargoContacto,
        @Size(max = 255) String sectorEmpresa,
        @Size(max = 255) String tamanoEmpresa,
        @Size(max = 255) String sitioWeb,
        @Size(max = 1000) String descripcionEmpresa,
        @Size(max = 30, message = "Como máximo 30 habilidades")
        List<@Size(max = 60, message = "Cada habilidad admite 60 caracteres") String> habilidades
) {}
