package com.trabajito.common.enums;

/**
 * Máquina de estados de un trabajo (espeja el flujo de la app):
 * ACTIVO → ASIGNADO → ACORDADO → EN_PROGRESO → ESPERANDO_CONFIRMACION →
 * COMPLETADO → FINALIZADO. CERRADO/CANCELADO son estados terminales alternos.
 */
public enum EstadoTrabajo {
    ACTIVO,                    // publicado, recibiendo postulaciones
    ASIGNADO,                  // trabajador elegido, en negociación (chat)
    ACORDADO,                  // contrato creado, pago en garantía, pendiente de iniciar
    EN_PROGRESO,               // el trabajador inició
    ESPERANDO_CONFIRMACION,    // el trabajador marcó terminado, falta que el empleador acepte
    COMPLETADO,                // aceptado y pago liberado
    FINALIZADO,                // ambas partes calificaron (archivado, solo lectura)
    CERRADO,                   // cerrado por el empleador
    CANCELADO                  // cancelado / reembolsado
}
