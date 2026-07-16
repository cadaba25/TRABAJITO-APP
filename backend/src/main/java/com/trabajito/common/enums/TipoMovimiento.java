package com.trabajito.common.enums;

/** Tipo de movimiento en la cartera (historial de transacciones). */
public enum TipoMovimiento {
    RECARGA,       // el usuario agrega saldo
    RETIRO,        // el usuario retira saldo
    RETENCION,     // se retiene pago en garantía (escrow) al crear el contrato
    LIBERACION,    // se libera el pago al trabajador
    REEMBOLSO      // se devuelve el pago retenido al empleador
}
