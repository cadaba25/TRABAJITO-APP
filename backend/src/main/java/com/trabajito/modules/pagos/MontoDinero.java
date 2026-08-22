package com.trabajito.modules.pagos;

import com.trabajito.common.exception.ApiException;

import java.math.BigDecimal;

/**
 * Validación y normalización de cualquier cantidad de dinero que entre al
 * sistema (recargas, escrow, liberaciones, reembolsos).
 *
 * <p>Las columnas de dinero son {@code numeric(12,2)}: Lempiras con dos
 * decimales. Antes de la tarea 007 nadie comprobaba la escala del monto
 * recibido, y el driver JDBC lo redondeaba al escribirlo — con lo que
 * {@code {"monto":0.005}} no le cobraba nada al empleador (100 - 0.005 -&gt;
 * 100.00) pero se guardaba como {@code 0.01} en {@code monto_acordado} y el
 * trabajador acababa cobrando un centavo que nadie pagó.
 *
 * <p>La decisión (ADR-0006) es <b>rechazar</b> con 400, no redondear en
 * silencio: redondear es exactamente lo que creó el defecto.
 */
public final class MontoDinero {

    /** Decimales de las columnas de dinero (numeric(12,2)). */
    public static final int ESCALA = 2;

    /** Máximo representable en numeric(12,2). Por encima, el INSERT reventaría. */
    public static final BigDecimal MAXIMO = new BigDecimal("9999999999.99");

    private MontoDinero() {
    }

    /**
     * Comprueba que el monto es utilizable como dinero y lo devuelve con la
     * escala exacta de la columna.
     *
     * @throws ApiException 400 si es nulo, no positivo, tiene más de dos
     *                      decimales significativos o excede el máximo.
     */
    public static BigDecimal normalizar(BigDecimal monto) {
        if (monto == null) {
            throw ApiException.solicitudInvalida("El monto es obligatorio");
        }
        if (monto.signum() <= 0) {
            throw ApiException.solicitudInvalida("Monto inválido");
        }
        // stripTrailingZeros para aceptar 1000, 1000.0 y 1000.00 por igual y
        // rechazar solo lo que de verdad tiene fracciones de centavo.
        if (monto.stripTrailingZeros().scale() > ESCALA) {
            throw ApiException.solicitudInvalida(
                    "El monto no puede tener más de 2 decimales (Lempiras y centavos)");
        }
        if (monto.compareTo(MAXIMO) > 0) {
            throw ApiException.solicitudInvalida(
                    "El monto excede el máximo permitido (L. " + MAXIMO.toPlainString() + ")");
        }
        // setScale sin RoundingMode: es exacto por la comprobación de arriba,
        // así que nunca puede redondear a espaldas de nadie.
        return monto.setScale(ESCALA);
    }
}
