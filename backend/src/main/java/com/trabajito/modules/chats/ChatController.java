package com.trabajito.modules.chats;

import com.trabajito.common.enums.TipoMensaje;
import com.trabajito.security.SecurityUtils;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Endpoints REST del chat (envío también disponible por WebSocket). */
@RestController
@RequestMapping("/api/chats")
public class ChatController {

    private final ChatService service;

    public ChatController(ChatService service) {
        this.service = service;
    }

    @GetMapping
    public List<ChatRoom> misChats() {
        return service.misChats(SecurityUtils.idActual());
    }

    /** Sin leer del usuario actual: total y desglose por chat (para badge y lista). */
    public record NoLeidosResponse(long total, Map<UUID, Long> porChat) {}

    @GetMapping("/no-leidos")
    public NoLeidosResponse noLeidos() {
        return service.noLeidos(SecurityUtils.idActual());
    }

    /** Resuelve el chat de un trabajo (404 si aun no fue asignado). */
    @GetMapping("/trabajo/{trabajoId}")
    public ChatRoom porTrabajo(@PathVariable UUID trabajoId) {
        return service.porTrabajo(trabajoId, SecurityUtils.idActual());
    }

    @GetMapping("/{id}")
    public ChatRoom porId(@PathVariable UUID id) {
        return service.porId(id, SecurityUtils.idActual());
    }

    @GetMapping("/{id}/mensajes")
    public List<Mensaje> mensajes(@PathVariable UUID id,
                                  @RequestParam(required = false) Instant desde) {
        return service.mensajes(id, SecurityUtils.idActual(), desde);
    }

    // contenido es NOT NULL en la tabla: sin validacion, un cuerpo sin ese campo
    // acababa en un error de integridad de la BD -> 500 (tarea 009).
    public record MensajeRequest(@NotBlank(message = "El mensaje no puede estar vacio")
                                 @Size(max = 2000, message = "El mensaje excede 2000 caracteres")
                                 String contenido, TipoMensaje tipo) {}

    @PostMapping("/{id}/mensajes")
    public Mensaje enviar(@PathVariable UUID id, @Valid @RequestBody MensajeRequest req) {
        return service.enviar(id, SecurityUtils.idActual(), req.contenido(), req.tipo());
    }

    @PostMapping("/{id}/leido")
    public void marcarLeido(@PathVariable UUID id) {
        service.marcarLeido(id, SecurityUtils.idActual());
    }

    // ── Negociación ──
    public record PagoRequest(@NotNull @Positive BigDecimal monto) {}
    public record TiempoRequest(@NotBlank String tiempo) {}

    @PostMapping("/{id}/proponer-pago")
    public ChatRoom proponerPago(@PathVariable UUID id, @Valid @RequestBody PagoRequest req) {
        return service.proponerPago(id, SecurityUtils.idActual(), req.monto());
    }

    @PostMapping("/{id}/aceptar-pago")
    public ChatRoom aceptarPago(@PathVariable UUID id) {
        return service.aceptarPago(id, SecurityUtils.idActual());
    }

    @PostMapping("/{id}/proponer-tiempo")
    public ChatRoom proponerTiempo(@PathVariable UUID id, @Valid @RequestBody TiempoRequest req) {
        return service.proponerTiempo(id, SecurityUtils.idActual(), req.tiempo());
    }

    @PostMapping("/{id}/aceptar-tiempo")
    public ChatRoom aceptarTiempo(@PathVariable UUID id) {
        return service.aceptarTiempo(id, SecurityUtils.idActual());
    }
}
