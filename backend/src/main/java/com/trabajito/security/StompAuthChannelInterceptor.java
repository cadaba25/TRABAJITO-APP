package com.trabajito.security;

import com.trabajito.modules.chats.ChatRoomRepository;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.springframework.lang.NonNull;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Valida el JWT de acceso en el frame STOMP {@code CONNECT}, antes de dejar
 * pasar la conexión (tarea 030).
 *
 * <p>Hasta esta tarea, {@code WebSocketConfig} tenía un {@code TODO}: el
 * handshake HTTP a {@code /ws} es público a propósito (SockJS lo necesita
 * así, ver {@code SecurityConfig}), pero el {@code CONNECT} STOMP posterior
 * no exigía nada — cualquiera podía conectarse y (cuando exista un handler)
 * suscribirse o publicar. No explotaba porque el chat sigue en Firestore y
 * este WebSocket no tiene consumidor real todavía, pero es requisito para
 * migrarlo.
 *
 * <p><b>Reutiliza {@link JwtService}</b> — la misma validación que usa
 * {@link JwtAuthFilter} para HTTP (firma, expiración) — y el mismo criterio
 * de "usuario existente y activo" que ese filtro. No se reescribe la
 * validación de JWT desde cero.
 *
 * <p>El token va en un header STOMP <b>nativo</b> del frame {@code CONNECT}
 * (no en el handshake HTTP): {@code Authorization: Bearer <token>}, o
 * {@code token: <token>} como alternativa para clientes que no puedan mandar
 * el primero. Sin uno válido, se lanza {@link StompAuthException}, que Spring
 * propaga como error del canal: el cliente recibe un frame STOMP
 * {@code ERROR} y la conexión se cierra antes de llegar al broker.
 *
 * <p><b>Fuera de alcance a propósito (ver tarea 030):</b> un token válido que
 * caduca a mitad de sesión no se revalida — la conexión sigue abierta hasta
 * que el cliente la cierre. Se deja para la tarea que migre el chat.
 */
@Component
public class StompAuthChannelInterceptor implements ChannelInterceptor {

    private static final String PREFIJO_BEARER = "Bearer ";

    private final JwtService jwtService;
    private static final String PREFIJO_TOPIC_CHAT = "/topic/chats/";

    private final UsuarioRepository usuarios;
    private final ChatRoomRepository salas;

    public StompAuthChannelInterceptor(JwtService jwtService, UsuarioRepository usuarios,
                                       ChatRoomRepository salas) {
        this.jwtService = jwtService;
        this.usuarios = usuarios;
        this.salas = salas;
    }

    @Override
    public Message<?> preSend(@NonNull Message<?> message, @NonNull MessageChannel channel) {
        StompHeaderAccessor accessor =
                MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);

        if (accessor != null && StompCommand.CONNECT.equals(accessor.getCommand())) {
            Usuario usuario = validar(extraerToken(accessor));
            // Deja al usuario disponible como Principal de la sesión STOMP,
            // por si un futuro handler de mensajería lo necesita.
            UsuarioPrincipal principal = new UsuarioPrincipal(usuario);
            accessor.setUser(new UsernamePasswordAuthenticationToken(
                    principal, null, principal.getAuthorities()));
        } else if (accessor != null && StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {
            autorizarSuscripcion(accessor);
        }
        return message;
    }

    /**
     * Tarea 057: solo los participantes pueden suscribirse a /topic/chats/{id};
     * cualquier otro destino se rechaza (deny by default).
     */
    private void autorizarSuscripcion(StompHeaderAccessor accessor) {
        String destino = accessor.getDestination();
        if (destino == null || !destino.startsWith(PREFIJO_TOPIC_CHAT)) {
            throw new StompAuthException("Destino de suscripción no permitido");
        }
        if (!(accessor.getUser() instanceof Authentication auth)
                || !(auth.getPrincipal() instanceof UsuarioPrincipal principal)) {
            throw new StompAuthException("Sesión no autenticada");
        }
        UUID chatId;
        try {
            chatId = UUID.fromString(destino.substring(PREFIJO_TOPIC_CHAT.length()));
        } catch (IllegalArgumentException e) {
            throw new StompAuthException("Destino de suscripción no permitido");
        }
        // Misma respuesta para "no existe" y "no es tuyo": no revela chats ajenos.
        boolean participa = salas.findById(chatId)
                .map(sala -> sala.esParticipante(principal.getId()))
                .orElse(false);
        if (!participa) {
            throw new StompAuthException("No participas en este chat");
        }
    }

    private String extraerToken(StompHeaderAccessor accessor) {
        String header = primerHeader(accessor, "Authorization");
        if (header != null) {
            if (!header.startsWith(PREFIJO_BEARER)) {
                throw new StompAuthException("Token con formato inválido");
            }
            return header.substring(PREFIJO_BEARER.length());
        }
        // Alternativa para clientes STOMP que no puedan mandar el header
        // "Authorization" tal cual en el CONNECT.
        String token = primerHeader(accessor, "token");
        if (token == null) {
            throw new StompAuthException("Falta el token de acceso");
        }
        return token;
    }

    private String primerHeader(StompHeaderAccessor accessor, String nombre) {
        List<String> valores = accessor.getNativeHeader(nombre);
        return (valores == null || valores.isEmpty()) ? null : valores.get(0);
    }

    private Usuario validar(String token) {
        if (token.isBlank() || !jwtService.esValido(token)) {
            throw new StompAuthException("Token inválido o expirado");
        }
        UUID id;
        try {
            id = UUID.fromString(jwtService.extraerUsuarioId(token));
        } catch (IllegalArgumentException e) {
            throw new StompAuthException("Token con contenido inválido");
        }
        Optional<Usuario> u = usuarios.findById(id);
        if (u.isEmpty() || !u.get().isActivo()) {
            throw new StompAuthException("Usuario no encontrado o inactivo");
        }
        return u.get();
    }
}
