package com.trabajito.config;

import com.trabajito.security.StompAuthChannelInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * Chat en tiempo real con STOMP sobre WebSocket.
 *
 * <p>Cliente (Flutter) se conecta a  {@code ws://host:8080/ws}, se suscribe a
 * {@code /topic/chats/{chatId}} y envía a {@code /app/chats/{chatId}/enviar}.
 *
 * <p>El handshake HTTP sigue siendo público (ver {@code SecurityConfig}),
 * pero desde la tarea 030 el {@code CONNECT} STOMP exige un JWT válido: ver
 * {@link StompAuthChannelInterceptor}.
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final StompAuthChannelInterceptor stompAuthChannelInterceptor;

    public WebSocketConfig(StompAuthChannelInterceptor stompAuthChannelInterceptor) {
        this.stompAuthChannelInterceptor = stompAuthChannelInterceptor;
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        // Broker en memoria (suficiente para un servidor único).
        // Para escalar a varias instancias, usar un broker externo (RabbitMQ).
        registry.enableSimpleBroker("/topic");
        registry.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(stompAuthChannelInterceptor);
    }
}
