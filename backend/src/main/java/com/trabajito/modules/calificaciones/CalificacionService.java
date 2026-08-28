package com.trabajito.modules.calificaciones;

import com.trabajito.common.enums.EstadoTrabajo;
import com.trabajito.common.enums.RolCalificado;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.trabajos.Trabajo;
import com.trabajito.modules.trabajos.TrabajoRepository;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.UUID;

@Service
public class CalificacionService {

    private final CalificacionRepository calificaciones;
    private final TrabajoRepository trabajos;
    private final UsuarioRepository usuarios;

    public CalificacionService(CalificacionRepository calificaciones,
                               TrabajoRepository trabajos,
                               UsuarioRepository usuarios) {
        this.calificaciones = calificaciones;
        this.trabajos = trabajos;
        this.usuarios = usuarios;
    }

    /**
     * Registra una calificación (bidireccional) y actualiza la reputación del
     * receptor. Si ambas partes ya calificaron, el trabajo pasa a FINALIZADO.
     *
     * <p><b>Reputación separada por rol (tarea 019).</b> La misma cuenta puede
     * ser trabajador en un trabajo y contratista en otro, así que cada
     * calificación suma en la reputación del papel que tenía el RECEPTOR en
     * <i>ese</i> trabajo, no en la de su rol de cuenta. Se mantiene además la
     * media global (todas las calificaciones juntas), que es la que ya existía.
     */
    @Transactional
    public Calificacion calificar(UUID trabajoId, UUID autorId, int estrellas, String comentario) {
        if (estrellas < 1 || estrellas > 5) {
            throw ApiException.solicitudInvalida("Las estrellas deben estar entre 1 y 5");
        }
        // Bloqueo pesimista de la fila del trabajo (ADR-0006): serializa dos
        // calificaciones simultaneas del mismo trabajo, que si no duplicaban la
        // fila (violando la restriccion unica -> 500) y pisaban el promedio del
        // receptor con un read-modify-write. Ademas mantiene el orden global de
        // bloqueo trabajos -> usuarios, para no cruzarse con TrabajoService.
        Trabajo t = trabajos.findByIdParaActualizar(trabajoId)
                .orElseThrow(() -> ApiException.noEncontrado("El trabajo no existe"));

        boolean esEmpleador = t.getEmpleadorId().equals(autorId);
        boolean esTrabajador = autorId.equals(t.getTrabajadorAsignadoId());
        if (!esEmpleador && !esTrabajador) {
            throw ApiException.prohibido("No participaste en este trabajo");
        }
        if (t.getEstado() != EstadoTrabajo.COMPLETADO && t.getEstado() != EstadoTrabajo.FINALIZADO) {
            throw ApiException.conflicto("El trabajo aún no está completado");
        }
        if (calificaciones.existsByTrabajoIdAndAutorId(trabajoId, autorId)) {
            throw ApiException.conflicto("Ya calificaste este trabajo");
        }

        UUID receptorId = esEmpleador ? t.getTrabajadorAsignadoId() : t.getEmpleadorId();
        // Si califica el empleador, quien recibe lo hace como TRABAJADOR; y al
        // reves. Se deduce del trabajo, nunca del rol de la cuenta.
        RolCalificado rolCalificado = esEmpleador
                ? RolCalificado.TRABAJADOR : RolCalificado.EMPLEADOR;

        Calificacion c = calificaciones.save(Calificacion.builder()
                .trabajoId(trabajoId).autorId(autorId).receptorId(receptorId)
                .rolCalificado(rolCalificado)
                .estrellas(estrellas).comentario(comentario).build());

        // Actualiza la reputacion del receptor (fila bloqueada: es otro
        // read-modify-write, y la fila de usuarios tambien lleva el saldo).
        Usuario receptor = usuarios.findByIdParaActualizar(receptorId)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        actualizarReputacion(receptor, rolCalificado, estrellas);
        usuarios.save(receptor);

        // Marca la bandera y archiva si ambas partes ya calificaron.
        if (esEmpleador) t.setCalificadoPorEmpleador(true);
        else t.setCalificadoPorTrabajador(true);
        if (t.isCalificadoPorEmpleador() && t.isCalificadoPorTrabajador()) {
            t.setEstado(EstadoTrabajo.FINALIZADO);
        }
        trabajos.save(t);
        return c;
    }

    /**
     * Suma una calificación a la media global del receptor y a la del rol que
     * corresponda. Las tres medias se llevan de forma incremental (no se
     * recalculan sobre toda la tabla) sobre la fila ya bloqueada.
     */
    private void actualizarReputacion(Usuario receptor, RolCalificado rol, int estrellas) {
        receptor.setCalificacionPromedio(nuevaMedia(
                receptor.getCalificacionPromedio(), receptor.getTotalCalificaciones(), estrellas));
        receptor.setTotalCalificaciones(receptor.getTotalCalificaciones() + 1);

        if (rol == RolCalificado.TRABAJADOR) {
            receptor.setCalificacionComoTrabajador(nuevaMedia(
                    receptor.getCalificacionComoTrabajador(),
                    receptor.getTotalCalificacionesComoTrabajador(), estrellas));
            receptor.setTotalCalificacionesComoTrabajador(
                    receptor.getTotalCalificacionesComoTrabajador() + 1);
        } else {
            receptor.setCalificacionComoEmpleador(nuevaMedia(
                    receptor.getCalificacionComoEmpleador(),
                    receptor.getTotalCalificacionesComoEmpleador(), estrellas));
            receptor.setTotalCalificacionesComoEmpleador(
                    receptor.getTotalCalificacionesComoEmpleador() + 1);
        }
    }

    /** Media con una calificación más, con dos decimales. */
    private BigDecimal nuevaMedia(BigDecimal mediaActual, int total, int estrellas) {
        BigDecimal media = mediaActual == null ? BigDecimal.ZERO : mediaActual;
        BigDecimal suma = media.multiply(BigDecimal.valueOf(total))
                .add(BigDecimal.valueOf(estrellas));
        return suma.divide(BigDecimal.valueOf(total + 1L), 2, RoundingMode.HALF_UP);
    }

    public List<Calificacion> recibidas(UUID receptorId) {
        return calificaciones.findByReceptorIdOrderByCreadoEnDesc(receptorId);
    }

    /** Reseñas recibidas en un papel concreto (trabajador o contratista). */
    public List<Calificacion> recibidasComo(UUID receptorId, RolCalificado rol) {
        return calificaciones.findByReceptorIdAndRolCalificadoOrderByCreadoEnDesc(receptorId, rol);
    }
}
