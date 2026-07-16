package com.trabajito.modules.pagos;

import com.trabajito.security.SecurityUtils;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/api/cartera")
public class PagoController {

    private final PagoService pagoService;

    public PagoController(PagoService pagoService) {
        this.pagoService = pagoService;
    }

    public record RecargaRequest(@NotNull @Positive BigDecimal monto) {}

    /** Recarga de saldo (prototipo). */
    @PostMapping("/recargar")
    public BigDecimal recargar(@RequestBody RecargaRequest req) {
        return pagoService.recargar(SecurityUtils.idActual(), req.monto());
    }

    /** Historial de movimientos de la cartera propia. */
    @GetMapping("/movimientos")
    public List<MovimientoCartera> movimientos() {
        return pagoService.historial(SecurityUtils.idActual());
    }
}
