package com.trabajito.modules.calificaciones;

import com.trabajito.common.enums.EstadoTrabajo;
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
     * Registra una calificación (bidireccional) y actualiza el promedio del
     * receptor. Si ambas partes ya calificaron, el trabajo pasa a FINALIZADO.
     */
    @Transactional
    public Calificacion calificar(UUID trabajoId, UUID autorId, int estrellas, String comentario) {
        if (estrellas < 1 || estrellas > 5) {
            throw ApiException.solicitudInvalida("Las estrellas deben estar entre 1 y 5");
        }
        Trabajo t = trabajos.findById(trabajoId)
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

        Calificacion c = calificaciones.save(Calificacion.builder()
                .trabajoId(trabajoId).autorId(autorId).receptorId(receptorId)
                .estrellas(estrellas).comentario(comentario).build());

        // Actualiza el promedio del receptor.
        Usuario receptor = usuarios.findById(receptorId)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        int total = receptor.getTotalCalificaciones();
        BigDecimal suma = receptor.getCalificacionPromedio()
                .multiply(BigDecimal.valueOf(total))
                .add(BigDecimal.valueOf(estrellas));
        int nuevoTotal = total + 1;
        receptor.setTotalCalificaciones(nuevoTotal);
        receptor.setCalificacionPromedio(
                suma.divide(BigDecimal.valueOf(nuevoTotal), 2, RoundingMode.HALF_UP));
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

    public List<Calificacion> recibidas(UUID receptorId) {
        return calificaciones.findByReceptorIdOrderByCreadoEnDesc(receptorId);
    }
}
