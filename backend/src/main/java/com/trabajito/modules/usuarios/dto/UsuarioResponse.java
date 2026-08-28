package com.trabajito.modules.usuarios.dto;

import com.trabajito.common.enums.Rol;
import com.trabajito.modules.usuarios.Usuario;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Vista de un usuario (nunca expone el {@code passwordHash}).
 *
 * <p><b>Hay dos vistas, no una</b> (tarea 019):
 * <ul>
 *   <li>{@link #de(Usuario)} / {@link #completo} — vista del <b>dueño</b>: la
 *       usan {@code /api/auth/*} y {@code PUT /api/usuarios/me}.</li>
 *   <li>{@link #publico(Usuario)} / {@link #publicoCompleto} — vista de
 *       <b>terceros</b>: {@code GET /api/usuarios/&#123;id&#125;} y el ranking.
 *       Deja en {@code null} los datos personales que nadie más tiene por qué
 *       ver (correo, DNI, teléfonos, fecha de nacimiento, género, código
 *       postal, RTN) y el <b>saldo</b> de la cartera.</li>
 * </ul>
 * Sin esa separación, añadir el perfil completo habría convertido
 * {@code GET /api/usuarios/&#123;id&#125;} en un buscador de datos personales
 * para cualquiera con una cuenta.
 *
 * <p>Las tres listas ({@code habilidades}, {@code experiencia},
 * {@code estudios}) van a {@code null} cuando la respuesta no las incluye
 * —login y registro, que no deben pagar tres consultas más—. {@code null}
 * significa "no viene en esta respuesta"; lista vacía significa "no tiene".
 * El perfil completo llega en {@code GET /api/auth/yo},
 * {@code GET /api/usuarios/&#123;id&#125;} y {@code PUT /api/usuarios/me}.
 */
public record UsuarioResponse(
        UUID id,
        String correo,
        String nombres,
        String apellidos,
        String nombreCompleto,
        String dni,
        String telefono,
        String telefonoEmergencia,
        LocalDate fechaNacimiento,
        String genero,
        Rol rol,
        boolean activo,
        boolean registroCompleto,
        Instant creadoEn,
        String fotoUrl,
        String presentacion,
        String urlCV,
        String departamento,
        String ciudad,
        String codigoPostal,
        String pais,
        boolean viveEnHonduras,
        int trabajosCompletados,
        int trabajosPublicados,
        int pagosConfirmados,
        BigDecimal calificacionPromedio,
        int totalCalificaciones,
        BigDecimal calificacionComoTrabajador,
        int totalCalificacionesComoTrabajador,
        BigDecimal calificacionComoEmpleador,
        int totalCalificacionesComoEmpleador,
        BigDecimal saldo,
        String tipoEmpleador,
        String nombreEmpresa,
        String rtn,
        String cargoContacto,
        String sectorEmpresa,
        String tamanoEmpresa,
        String sitioWeb,
        String descripcionEmpresa,
        List<String> habilidades,
        List<ExperienciaResponse> experiencia,
        List<EstudioResponse> estudios
) {

    /** Vista del dueño, sin el CV (login/registro). */
    public static UsuarioResponse de(Usuario u) {
        return construir(u, true, null, null, null);
    }

    /** Vista del dueño con habilidades, experiencia y estudios. */
    public static UsuarioResponse completo(Usuario u,
                                           List<String> habilidades,
                                           List<ExperienciaResponse> experiencia,
                                           List<EstudioResponse> estudios) {
        return construir(u, true, habilidades, experiencia, estudios);
    }

    /** Vista de terceros, sin datos personales ni saldo. */
    public static UsuarioResponse publico(Usuario u) {
        return construir(u, false, null, null, null);
    }

    /** Vista de terceros con el CV público del trabajador. */
    public static UsuarioResponse publicoCompleto(Usuario u,
                                                  List<String> habilidades,
                                                  List<ExperienciaResponse> experiencia,
                                                  List<EstudioResponse> estudios) {
        return construir(u, false, habilidades, experiencia, estudios);
    }

    private static UsuarioResponse construir(Usuario u,
                                             boolean esElDueno,
                                             List<String> habilidades,
                                             List<ExperienciaResponse> experiencia,
                                             List<EstudioResponse> estudios) {
        return new UsuarioResponse(
                u.getId(),
                esElDueno ? u.getCorreo() : null,
                u.getNombres(),
                u.getApellidos(),
                u.getNombreCompleto(),
                esElDueno ? u.getDni() : null,
                esElDueno ? u.getTelefono() : null,
                esElDueno ? u.getTelefonoEmergencia() : null,
                esElDueno ? u.getFechaNacimiento() : null,
                esElDueno ? u.getGenero() : null,
                u.getRol(),
                u.isActivo(),
                u.isRegistroCompleto(),
                u.getCreadoEn(),
                u.getFotoUrl(),
                u.getPresentacion(),
                u.getUrlCV(),
                u.getDepartamento(),
                u.getCiudad(),
                esElDueno ? u.getCodigoPostal() : null,
                u.getPais(),
                u.isViveEnHonduras(),
                u.getTrabajosCompletados(),
                u.getTrabajosPublicados(),
                u.getPagosConfirmados(),
                u.getCalificacionPromedio(),
                u.getTotalCalificaciones(),
                u.getCalificacionComoTrabajador(),
                u.getTotalCalificacionesComoTrabajador(),
                u.getCalificacionComoEmpleador(),
                u.getTotalCalificacionesComoEmpleador(),
                esElDueno ? u.getSaldo() : null,
                u.getTipoEmpleador(),
                u.getNombreEmpresa(),
                esElDueno ? u.getRtn() : null,
                u.getCargoContacto(),
                u.getSectorEmpresa(),
                u.getTamanoEmpresa(),
                u.getSitioWeb(),
                u.getDescripcionEmpresa(),
                habilidades,
                experiencia,
                estudios);
    }
}
