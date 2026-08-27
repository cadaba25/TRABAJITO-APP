package com.trabajito.modules.usuarios.dto;

import com.trabajito.modules.usuarios.Estudio;

import java.util.UUID;

/** Un estudio del trabajador. Mismos nombres que el modelo `Estudio` de Flutter. */
public record EstudioResponse(
        UUID id,
        String nivel,
        String centro,
        String fechaInicio,
        String fechaFin,
        boolean cursandoActualmente
) {
    public static EstudioResponse de(Estudio e) {
        return new EstudioResponse(e.getId(), e.getNivel(), e.getCentro(),
                e.getFechaInicio(), e.getFechaFin(), e.isCursandoActualmente());
    }
}
