package com.trabajito.modules.pagos.dto;

import com.trabajito.modules.pagos.Tarjeta;

import java.util.UUID;

/** Nunca lleva el número completo ni el CVV — no se guardan en ningún lado. */
public record TarjetaResponse(
        UUID id,
        String marca,
        String ultimos4,
        String titular,
        String vencimiento
) {
    public static TarjetaResponse de(Tarjeta t) {
        return new TarjetaResponse(t.getId(), t.getMarca(), t.getUltimos4(),
                t.getTitular(), t.getVencimiento());
    }
}
