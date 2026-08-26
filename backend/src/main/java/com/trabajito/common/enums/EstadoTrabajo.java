package com.trabajito.common.enums;

/**
 * Máquina de estados de un trabajo (ver ADR-0007 para las reglas completas):
 *
 * <pre>
 * ACTIVO → ASIGNADO → ACORDADO → EN_PROGRESO → ESPERANDO_CONFIRMACION → COMPLETADO → FINALIZADO
 *                                     └──────────────┬──────────────┘
 *                                                    ↓
 *                                               EN_DISPUTA → COMPLETADO | CANCELADO   (solo ADMIN)
 * </pre>
 *
 * <p>La cancelación solo es posible ANTES de iniciar (ACTIVO/ASIGNADO/ACORDADO)
 * y deja el trabajo en ACTIVO (reabierto al feed) o en CANCELADO (cerrado), a
 * elección del empleador. Desde EN_PROGRESO en adelante ninguna de las dos
 * partes puede cancelar: la única salida es EN_DISPUTA, donde el dinero queda
 * congelado hasta que un ADMIN resuelve.
 */
public enum EstadoTrabajo {
    ACTIVO,                    // publicado, recibiendo postulaciones
    ASIGNADO,                  // trabajador elegido, en negociación (chat)
    ACORDADO,                  // contrato creado, pago en garantía, pendiente de iniciar
    EN_PROGRESO,               // el trabajador inició
    ESPERANDO_CONFIRMACION,    // el trabajador entregó (con evidencias), falta que el empleador acepte
    EN_DISPUTA,                // una de las partes reclamó a soporte; escrow congelado, resuelve un ADMIN
    COMPLETADO,                // aceptado y pago liberado
    FINALIZADO,                // ambas partes calificaron (archivado, solo lectura)
    CERRADO,                   // cerrado por el empleador
    CANCELADO                  // cancelado antes de iniciar, o disputa resuelta a favor del empleador (reembolso)
}
