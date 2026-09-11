package com.trabajito.modules.pagos;

import com.trabajito.modules.pagos.dto.TarjetaRequest;
import com.trabajito.modules.pagos.dto.TarjetaResponse;
import com.trabajito.security.SecurityUtils;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Tarjetas guardadas de la cartera propia (tarea 030). Prototipo sin
 * pasarela de pago: ver {@link Tarjeta} y {@link TarjetaService}.
 */
@RestController
@RequestMapping("/api/cartera/tarjetas")
public class TarjetaController {

    private final TarjetaService service;

    public TarjetaController(TarjetaService service) {
        this.service = service;
    }

    /** Solo las tarjetas propias — el id sale del JWT, nunca de un parámetro. */
    @GetMapping
    public List<TarjetaResponse> listar() {
        return service.propias(SecurityUtils.idActual());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TarjetaResponse agregar(@Valid @RequestBody TarjetaRequest req) {
        return service.agregar(SecurityUtils.idActual(), req);
    }

    /** 404 si no existe, 403 si existe pero es ajena (ver {@link TarjetaService}). */
    @DeleteMapping("/{id}")
    public void borrar(@PathVariable UUID id) {
        service.borrar(SecurityUtils.idActual(), id);
    }
}
