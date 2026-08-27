package com.trabajito.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Demasiados intentos: se ha superado el límite de logins fallidos por IP o por
 * cuenta (ADR-0010). Responde <b>429 Too Many Requests</b> y lleva los segundos
 * que el cliente debería esperar antes de reintentar ({@code Retry-After}).
 */
public class IntentosExcedidosException extends ApiException {

    private final long retryAfterSegundos;

    public IntentosExcedidosException(String mensaje, long retryAfterSegundos) {
        super(HttpStatus.TOO_MANY_REQUESTS, mensaje);
        this.retryAfterSegundos = retryAfterSegundos;
    }

    public long getRetryAfterSegundos() {
        return retryAfterSegundos;
    }
}
