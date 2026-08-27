package com.trabajito.modules.calificaciones;

import com.trabajito.common.enums.EstadoTrabajo;
import com.trabajito.common.enums.RolCalificado;
import com.trabajito.modules.trabajos.Trabajo;
import com.trabajito.modules.trabajos.TrabajoRepository;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

/**
 * Tarea 019 — <b>dos reputaciones, una por rol</b> (decisión del dueño:
 * <i>"dos diferentes para cada rol"</i>).
 *
 * <p>Lo que se comprueba aquí es que cada calificación cae en el lado correcto:
 * la misma cuenta puede ser trabajador en un trabajo y contratista en otro, y
 * una reseña por hacer el trabajo no debe mejorar su fama de buen pagador.
 */
@ExtendWith(MockitoExtension.class)
class CalificacionServiceTest {

    @Mock
    CalificacionRepository calificaciones;

    @Mock
    TrabajoRepository trabajos;

    @Mock
    UsuarioRepository usuarios;

    CalificacionService servicio;

    UUID empleadorId;
    UUID trabajadorId;
    UUID trabajoId;
    Trabajo trabajo;
    Usuario empleador;
    Usuario trabajador;

    @BeforeEach
    void preparar() {
        servicio = new CalificacionService(calificaciones, trabajos, usuarios);
        empleadorId = UUID.randomUUID();
        trabajadorId = UUID.randomUUID();
        trabajoId = UUID.randomUUID();

        trabajo = Trabajo.builder()
                .empleadorId(empleadorId)
                .trabajadorAsignadoId(trabajadorId)
                .titulo("Instalar dos lámparas")
                .estado(EstadoTrabajo.COMPLETADO)
                .build();
        trabajo.setId(trabajoId);

        empleador = Usuario.builder().nombres("Elena").apellidos("QA").build();
        empleador.setId(empleadorId);
        trabajador = Usuario.builder().nombres("Tomás").apellidos("QA").build();
        trabajador.setId(trabajadorId);

        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(trabajo));
        when(calificaciones.save(any(Calificacion.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    @DisplayName("si califica el empleador, suma en la reputación del receptor COMO TRABAJADOR")
    void calificacionDelEmpleadorSumaComoTrabajador() {
        when(usuarios.findByIdParaActualizar(trabajadorId)).thenReturn(Optional.of(trabajador));

        Calificacion c = servicio.calificar(trabajoId, empleadorId, 5, "Excelente");

        assertThat(c.getRolCalificado()).isEqualTo(RolCalificado.TRABAJADOR);
        assertThat(c.getReceptorId()).isEqualTo(trabajadorId);
        assertThat(trabajador.getCalificacionComoTrabajador())
                .isEqualByComparingTo(new BigDecimal("5.00"));
        assertThat(trabajador.getTotalCalificacionesComoTrabajador()).isEqualTo(1);
        // Y NO toca la otra reputación: no es lo mismo trabajar bien que pagar bien.
        assertThat(trabajador.getCalificacionComoEmpleador()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(trabajador.getTotalCalificacionesComoEmpleador()).isZero();
        // La media global sigue existiendo y las suma todas.
        assertThat(trabajador.getCalificacionPromedio()).isEqualByComparingTo(new BigDecimal("5.00"));
        assertThat(trabajador.getTotalCalificaciones()).isEqualTo(1);
    }

    @Test
    @DisplayName("si califica el trabajador, suma en la reputación del receptor COMO EMPLEADOR")
    void calificacionDelTrabajadorSumaComoEmpleador() {
        when(usuarios.findByIdParaActualizar(empleadorId)).thenReturn(Optional.of(empleador));

        Calificacion c = servicio.calificar(trabajoId, trabajadorId, 4, "Pago puntual");

        assertThat(c.getRolCalificado()).isEqualTo(RolCalificado.EMPLEADOR);
        assertThat(c.getReceptorId()).isEqualTo(empleadorId);
        assertThat(empleador.getCalificacionComoEmpleador())
                .isEqualByComparingTo(new BigDecimal("4.00"));
        assertThat(empleador.getTotalCalificacionesComoEmpleador()).isEqualTo(1);
        assertThat(empleador.getCalificacionComoTrabajador()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(empleador.getTotalCalificacionesComoTrabajador()).isZero();
    }

    @Test
    @DisplayName("la misma cuenta lleva las dos reputaciones por separado")
    void unaCuentaConLasDosReputaciones() {
        // Alguien que ya tiene 5.00 como trabajador (2 reseñas) recibe ahora
        // una de 2 estrellas COMO CONTRATISTA: su fama de trabajador no cambia.
        empleador.setCalificacionComoTrabajador(new BigDecimal("5.00"));
        empleador.setTotalCalificacionesComoTrabajador(2);
        empleador.setCalificacionPromedio(new BigDecimal("5.00"));
        empleador.setTotalCalificaciones(2);
        when(usuarios.findByIdParaActualizar(empleadorId)).thenReturn(Optional.of(empleador));

        servicio.calificar(trabajoId, trabajadorId, 2, "Tardó en pagar");

        assertThat(empleador.getCalificacionComoTrabajador())
                .isEqualByComparingTo(new BigDecimal("5.00"));
        assertThat(empleador.getTotalCalificacionesComoTrabajador()).isEqualTo(2);
        assertThat(empleador.getCalificacionComoEmpleador())
                .isEqualByComparingTo(new BigDecimal("2.00"));
        assertThat(empleador.getTotalCalificacionesComoEmpleador()).isEqualTo(1);
        // Global: (5 + 5 + 2) / 3 = 4.00
        assertThat(empleador.getCalificacionPromedio()).isEqualByComparingTo(new BigDecimal("4.00"));
        assertThat(empleador.getTotalCalificaciones()).isEqualTo(3);
    }

    @Test
    @DisplayName("la media por rol se recalcula bien con varias reseñas")
    void mediaIncrementalPorRol() {
        trabajador.setCalificacionComoTrabajador(new BigDecimal("4.00"));
        trabajador.setTotalCalificacionesComoTrabajador(1);
        when(usuarios.findByIdParaActualizar(trabajadorId)).thenReturn(Optional.of(trabajador));

        servicio.calificar(trabajoId, empleadorId, 5, "Muy bien");

        // (4 + 5) / 2 = 4.50
        assertThat(trabajador.getCalificacionComoTrabajador())
                .isEqualByComparingTo(new BigDecimal("4.50"));
        assertThat(trabajador.getTotalCalificacionesComoTrabajador()).isEqualTo(2);
    }

    @Test
    @DisplayName("cuando ambas partes califican, el trabajo queda FINALIZADO")
    void ambasPartesFinalizanElTrabajo() {
        trabajo.setCalificadoPorTrabajador(true);
        when(usuarios.findByIdParaActualizar(trabajadorId)).thenReturn(Optional.of(trabajador));

        servicio.calificar(trabajoId, empleadorId, 5, "Excelente");

        assertThat(trabajo.getEstado()).isEqualTo(EstadoTrabajo.FINALIZADO);
    }
}
