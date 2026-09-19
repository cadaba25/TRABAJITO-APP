package com.trabajito.modules.calificaciones;

import com.trabajito.common.enums.RolCalificado;
import com.trabajito.modules.calificaciones.dto.CalificacionResponse;
import com.trabajito.modules.trabajos.TrabajoRepository;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

/** Tarea 057 (B): CalificacionResponse lleva autorNombre. */
@ExtendWith(MockitoExtension.class)
class CalificacionAutorNombreTest {

    @Mock CalificacionRepository calificaciones;
    @Mock TrabajoRepository trabajos;
    @Mock UsuarioRepository usuarios;

    @Test
    @DisplayName("autorNombre: el nombre completo del autor llega en la respuesta")
    void autorNombreEnLaRespuesta() {
        UUID autorId = UUID.randomUUID();
        Usuario autor = Usuario.builder().nombres("Elena").apellidos("QA").build();
        autor.setId(autorId);
        Calificacion c = Calificacion.builder().trabajoId(UUID.randomUUID()).autorId(autorId)
                .receptorId(UUID.randomUUID()).rolCalificado(RolCalificado.TRABAJADOR)
                .estrellas(5).comentario("Bien").build();
        when(usuarios.findAllById(List.of(autorId))).thenReturn(List.of(autor));

        var servicio = new CalificacionService(calificaciones, trabajos, usuarios);
        var nombres = servicio.nombresDeAutores(List.of(c));
        CalificacionResponse dto = CalificacionResponse.de(c, nombres.get(autorId));

        assertThat(dto.autorNombre()).isEqualTo("Elena QA");
        assertThat(dto.autorId()).isEqualTo(autorId);
        assertThat(CalificacionResponse.de(c).autorNombre()).isNull();
    }
}
