package com.trabajito.modules.usuarios.dto;

import com.trabajito.common.enums.Rol;
import com.trabajito.modules.usuarios.Usuario;

import java.math.BigDecimal;
import java.util.UUID;

/** Vista pública/segura de un usuario (nunca expone el passwordHash). */
public record UsuarioResponse(
        UUID id,
        String correo,
        String nombres,
        String apellidos,
        String nombreCompleto,
        String dni,
        String telefono,
        Rol rol,
        String fotoUrl,
        String presentacion,
        String departamento,
        String ciudad,
        int trabajosCompletados,
        int trabajosPublicados,
        int pagosConfirmados,
        BigDecimal calificacionPromedio,
        int totalCalificaciones,
        BigDecimal saldo,
        String tipoEmpleador,
        String nombreEmpresa,
        String sectorEmpresa,
        String tamanoEmpresa,
        String sitioWeb
) {
    public static UsuarioResponse de(Usuario u) {
        return new UsuarioResponse(
                u.getId(), u.getCorreo(), u.getNombres(), u.getApellidos(),
                u.getNombreCompleto(), u.getDni(), u.getTelefono(), u.getRol(),
                u.getFotoUrl(), u.getPresentacion(), u.getDepartamento(), u.getCiudad(),
                u.getTrabajosCompletados(), u.getTrabajosPublicados(), u.getPagosConfirmados(),
                u.getCalificacionPromedio(), u.getTotalCalificaciones(), u.getSaldo(),
                u.getTipoEmpleador(), u.getNombreEmpresa(), u.getSectorEmpresa(),
                u.getTamanoEmpresa(), u.getSitioWeb());
    }
}
