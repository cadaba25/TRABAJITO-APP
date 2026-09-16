package com.trabajito.security;

/**
 * Se lanza cuando el frame STOMP {@code CONNECT} no trae un token de acceso
 * válido. {@link StompAuthChannelInterceptor} la lanza dentro de
 * {@code preSend}; Spring la propaga como error del canal, lo que hace que el
 * cliente reciba un frame STOMP {@code ERROR} y la conexión se cierre — el
 * {@code CONNECT} nunca llega al broker.
 */
public class StompAuthException extends RuntimeException {

    public StompAuthException(String mensaje) {
        super(mensaje);
    }
}
