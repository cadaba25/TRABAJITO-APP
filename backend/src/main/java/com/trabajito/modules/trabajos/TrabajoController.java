package com.trabajito.modules.trabajos;

import com.trabajito.modules.trabajos.dto.CrearTrabajoRequest;
import com.trabajito.modules.trabajos.dto.TrabajoResponse;
import com.trabajito.security.SecurityUtils;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import org.springframework.data.domain.Page;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * Endpoints del ciclo de vida de un trabajo. El backend valida cada transición;
 * el cliente solo dispara la acción.
 */
@RestController
@RequestMapping("/api/trabajos")
public class TrabajoController {

    private final TrabajoService service;

    public TrabajoController(TrabajoService service) {
        this.service = service;
    }

    // ── Lectura ──
    @GetMapping
    public Page<TrabajoResponse> feed(@RequestParam(defaultValue = "0") int pagina,
                                      @RequestParam(defaultValue = "20") int tamano) {
        return service.feed(pagina, tamano).map(TrabajoResponse::de);
    }

    @GetMapping("/{id}")
    public TrabajoResponse porId(@PathVariable UUID id) {
        return TrabajoResponse.de(service.porId(id));
    }

    @GetMapping("/mios")
    public List<TrabajoResponse> misPublicaciones() {
        return service.misPublicaciones(SecurityUtils.idActual())
                .stream().map(TrabajoResponse::de).toList();
    }

    @GetMapping("/asignados")
    public List<TrabajoResponse> misAsignados() {
        return service.misAsignados(SecurityUtils.idActual())
                .stream().map(TrabajoResponse::de).toList();
    }

    // ── Publicar ──
    @PostMapping
    public TrabajoResponse crear(@Valid @RequestBody CrearTrabajoRequest req) {
        return TrabajoResponse.de(service.crear(SecurityUtils.idActual(), req));
    }

    // ── Transiciones ──
    public record AcuerdoRequest(@NotNull @Positive BigDecimal monto, String tiempo) {}
    public record MotivoRequest(String motivo) {}

    @PostMapping("/{id}/reservar-pago")
    public TrabajoResponse reservarPago(@PathVariable UUID id, @RequestBody AcuerdoRequest req) {
        return TrabajoResponse.de(
                service.reservarPago(id, SecurityUtils.idActual(), req.monto(), req.tiempo()));
    }

    @PostMapping("/{id}/iniciar")
    public TrabajoResponse iniciar(@PathVariable UUID id) {
        return TrabajoResponse.de(service.iniciar(id, SecurityUtils.idActual()));
    }

    @PostMapping("/{id}/terminar")
    public TrabajoResponse terminar(@PathVariable UUID id) {
        return TrabajoResponse.de(service.marcarTerminado(id, SecurityUtils.idActual()));
    }

    @PostMapping("/{id}/solicitar-correccion")
    public TrabajoResponse solicitarCorreccion(@PathVariable UUID id,
                                               @RequestBody MotivoRequest req) {
        return TrabajoResponse.de(
                service.solicitarCorreccion(id, SecurityUtils.idActual(), req.motivo()));
    }

    @PostMapping("/{id}/aceptar")
    public TrabajoResponse aceptar(@PathVariable UUID id) {
        return TrabajoResponse.de(service.aceptar(id, SecurityUtils.idActual()));
    }

    @PostMapping("/{id}/cancelar")
    public TrabajoResponse cancelar(@PathVariable UUID id) {
        return TrabajoResponse.de(service.cancelarContratacion(id, SecurityUtils.idActual()));
    }

    @PostMapping("/{id}/rechazar")
    public TrabajoResponse rechazar(@PathVariable UUID id) {
        return TrabajoResponse.de(service.rechazarAsignacion(id, SecurityUtils.idActual()));
    }
}
