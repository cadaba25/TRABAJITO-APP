package com.trabajito.config;

import com.trabajito.common.enums.Rol;
import com.trabajito.modules.chats.ChatRoom;
import com.trabajito.modules.chats.ChatRoomRepository;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import com.trabajito.security.JwtService;
import com.trabajito.security.StompAuthChannelInterceptor;
import com.trabajito.security.StompAuthException;
import com.trabajito.security.UsuarioPrincipal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Tarea 057: SUBSCRIBE a /topic/chats/{id} solo para participantes. */
@ExtendWith(MockitoExtension.class)
class StompSubscribeAutorizacionTest {

    @Mock JwtService jwt;
    @Mock UsuarioRepository usuarios;
    @Mock ChatRoomRepository salas;

    StompAuthChannelInterceptor interceptor;
    UUID empleadorId = UUID.randomUUID();
    UUID trabajadorId = UUID.randomUUID();
    UUID chatId = UUID.randomUUID();
    MessageChannel canal = mock(MessageChannel.class);

    @BeforeEach
    void preparar() {
        interceptor = new StompAuthChannelInterceptor(jwt, usuarios, salas);
    }

    private Message<byte[]> suscribir(String destino, UUID usuarioId) {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        acc.setDestination(destino);
        acc.setSubscriptionId("sub-0");
        if (usuarioId != null) {
            Usuario u = Usuario.builder().nombres("A").apellidos("B").rol(Rol.TRABAJADOR).build();
            u.setId(usuarioId);
            UsuarioPrincipal p = new UsuarioPrincipal(u);
            acc.setUser(new UsernamePasswordAuthenticationToken(p, null, p.getAuthorities()));
        }
        acc.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
    }

    private ChatRoom sala() {
        ChatRoom s = ChatRoom.builder().empleadorId(empleadorId).trabajadorId(trabajadorId).build();
        s.setId(chatId);
        return s;
    }

    @Test
    @DisplayName("participante (empleador y trabajador) puede suscribirse")
    void participanteOk() {
        when(salas.findById(chatId)).thenReturn(Optional.of(sala()));
        Message<byte[]> m1 = suscribir("/topic/chats/" + chatId, empleadorId);
        Message<byte[]> m2 = suscribir("/topic/chats/" + chatId, trabajadorId);
        assertThat(interceptor.preSend(m1, canal)).isSameAs(m1);
        assertThat(interceptor.preSend(m2, canal)).isSameAs(m2);
    }

    @Test
    @DisplayName("usuario ajeno al chat: rechazado")
    void ajenoRechazado() {
        when(salas.findById(chatId)).thenReturn(Optional.of(sala()));
        Message<byte[]> m = suscribir("/topic/chats/" + chatId, UUID.randomUUID());
        assertThatThrownBy(() -> interceptor.preSend(m, canal))
                .isInstanceOf(StompAuthException.class);
    }

    @Test
    @DisplayName("chat inexistente: rechazado")
    void chatInexistente() {
        when(salas.findById(chatId)).thenReturn(Optional.empty());
        Message<byte[]> m = suscribir("/topic/chats/" + chatId, empleadorId);
        assertThatThrownBy(() -> interceptor.preSend(m, canal))
                .isInstanceOf(StompAuthException.class);
    }

    @Test
    @DisplayName("id malformado, otro destino /topic o sesion sin usuario: rechazado")
    void otrosCasosRechazados() {
        Message<byte[]> malformado = suscribir("/topic/chats/no-es-uuid", empleadorId);
        Message<byte[]> otro = suscribir("/topic/otra-cosa", empleadorId);
        Message<byte[]> sinUsuario = suscribir("/topic/chats/" + chatId, null);
        assertThatThrownBy(() -> interceptor.preSend(malformado, canal))
                .isInstanceOf(StompAuthException.class);
        assertThatThrownBy(() -> interceptor.preSend(otro, canal))
                .isInstanceOf(StompAuthException.class);
        assertThatThrownBy(() -> interceptor.preSend(sinUsuario, canal))
                .isInstanceOf(StompAuthException.class);
    }
}
