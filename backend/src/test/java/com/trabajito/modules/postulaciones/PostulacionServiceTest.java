package com.trabajito.modules.postulaciones;

import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.chats.ChatService;
import com.trabajito.modules.trabajos.Trabajo;
import com.trabajito.modules.trabajos.TrabajoService;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Tarea 019 — <b>nadie se postula a su propio trabajo</b> (decisión del dueño
 * del proyecto).
 *
 * <p>Con el doble perfil (tarea 012) la misma cuenta publica trabajos y se
 * postula a otros, así que esto deja de ser un caso raro. La comprobación tiene
 * que estar en el servicio: el cliente puede mandar cualquier {@code trabajoId}.
 */
@ExtendWith(MockitoExtension.class)
class PostulacionServiceTest {

    @Mock
    PostulacionRepository postulaciones;

    @Mock
    UsuarioRepository usuarios;

    @Mock
    TrabajoService trabajoService;

    @Mock
    ChatService chatService;

    PostulacionService servicio;

    UUID empleadorId;
    UUID trabajadorId;
    UUID trabajoId;
    Trabajo trabajo;

    @BeforeEach
    void preparar() {
        servicio = new PostulacionService(postulaciones, usuarios, trabajoService, chatService);
        empleadorId = UUID.randomUUID();
        trabajadorId = UUID.randomUUID();
        trabajoId = UUID.randomUUID();
        trabajo = Trabajo.builder().empleadorId(empleadorId).titulo("Pintar una casa").build();
        trabajo.setId(trabajoId);
    }

    @Test
    @DisplayName("el dueño del trabajo no puede postularse a su propio trabajo: 409")
    void duenoNoPuedePostularseASuTrabajo() {
        when(postulaciones.existsByTrabajoIdAndTrabajadorId(trabajoId, empleadorId)).thenReturn(false);
        when(trabajoService.porId(trabajoId)).thenReturn(trabajo);

        assertThatThrownBy(() -> servicio.postular(trabajoId, empleadorId, "Me interesa"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("No puedes postularte a tu propio trabajo")
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        // Y no se guarda nada: el bloqueo pasa antes de tocar el repositorio.
        verify(postulaciones, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("otra persona sí puede postularse al mismo trabajo")
    void otraPersonaSiPuedePostularse() {
        Usuario trabajador = Usuario.builder().nombres("Tomás").apellidos("Pérez").build();
        trabajador.setId(trabajadorId);
        when(postulaciones.existsByTrabajoIdAndTrabajadorId(trabajoId, trabajadorId)).thenReturn(false);
        when(trabajoService.porId(trabajoId)).thenReturn(trabajo);
        when(usuarios.findById(trabajadorId)).thenReturn(Optional.of(trabajador));
        when(postulaciones.saveAndFlush(any(Postulacion.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        Postulacion p = servicio.postular(trabajoId, trabajadorId, "Me interesa");

        assertThat(p.getTrabajadorId()).isEqualTo(trabajadorId);
        assertThat(p.getTrabajadorNombre()).isEqualTo("Tomás Pérez");
    }

    @Test
    @DisplayName("postularse dos veces al mismo trabajo: 409")
    void postularseDosVeces() {
        when(postulaciones.existsByTrabajoIdAndTrabajadorId(trabajoId, trabajadorId)).thenReturn(true);

        assertThatThrownBy(() -> servicio.postular(trabajoId, trabajadorId, "Otra vez"))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);
    }
}
