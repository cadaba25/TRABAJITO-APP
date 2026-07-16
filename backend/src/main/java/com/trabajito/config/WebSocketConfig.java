package com.trabajito.config;

import org.springframework.context.annotation.Configuration;
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
 * <p>TODO (seguridad): validar el JWT en el CONNECT (ChannelInterceptor) para
 * que solo los participantes del chat puedan suscribirse/publicar.
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

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
}
