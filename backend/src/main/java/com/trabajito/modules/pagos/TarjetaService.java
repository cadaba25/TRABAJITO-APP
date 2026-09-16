package com.trabajito.modules.pagos;

import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.pagos.dto.TarjetaRequest;
import com.trabajito.modules.pagos.dto.TarjetaResponse;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Tarjetas guardadas en la cartera (tarea 030). Prototipo: nunca se guarda ni
 * se ve el número completo ni el CVV, solo los últimos 4 dígitos — igual que
 * {@code CarteraService.agregarTarjeta} en Flutter/Firestore.
 *
 * <p>Quién puede tocar qué se resuelve aquí, no en el cliente: borrar una
 * tarjeta ajena responde 403 (no 404) — el mismo criterio que ya usa el
 * resto de la API para recursos con dueño ({@code PerfilService} con
 * experiencia/estudios, {@code PostulacionService}, {@code ChatService}):
 * 404 solo si el id no existe, 403 si existe pero no es tuyo. Revisado en la
 * tarea 030 (security-agent); el 404-unificado original no era consistente
 * con ese patrón.
 */
@Service
public class TarjetaService {

    /** Tope para que esto no se use como almacén de texto arbitrario. */
    static final int MAX_TARJETAS = 20;
    private static final int MIN_DIGITOS_NUMERO = 13;

    private final UsuarioRepository usuarios;
    private final TarjetaRepository tarjetas;

    public TarjetaService(UsuarioRepository usuarios, TarjetaRepository tarjetas) {
        this.usuarios = usuarios;
        this.tarjetas = tarjetas;
    }

    public List<TarjetaResponse> propias(UUID usuarioId) {
        return tarjetas.findByUsuarioIdOrderByCreadoEnDesc(usuarioId).stream()
                .map(TarjetaResponse::de).toList();
    }

    @Transactional
    public TarjetaResponse agregar(UUID usuarioId, TarjetaRequest req) {
        Usuario u = usuarios.findById(usuarioId)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        if (tarjetas.countByUsuarioId(usuarioId) >= MAX_TARJETAS) {
            throw ApiException.conflicto("No puedes guardar más de " + MAX_TARJETAS + " tarjetas");
        }

        String limpio = req.numero() == null ? "" : req.numero().replaceAll("\\s", "");
        if (!limpio.matches("\\d+") || limpio.length() < MIN_DIGITOS_NUMERO) {
            throw ApiException.solicitudInvalida("Número de tarjeta inválido");
        }
        String ultimos4 = limpio.substring(limpio.length() - 4);
        String marca = (req.marca() == null || req.marca().isBlank())
                ? marcaDesdeNumero(limpio) : req.marca().trim();

        Tarjeta t = Tarjeta.builder()
                .usuario(u)
                .marca(marca)
                .ultimos4(ultimos4)
                .titular(req.titular().trim())
                .vencimiento(req.vencimiento().trim())
                .build();
        return TarjetaResponse.de(tarjetas.save(t));
    }

    @Transactional
    public void borrar(UUID usuarioId, UUID id) {
        Tarjeta t = tarjetas.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Esa tarjeta no existe"));
        if (!t.getUsuario().getId().equals(usuarioId)) {
            throw ApiException.prohibido("Esa tarjeta no es tuya");
        }
        tarjetas.delete(t);
    }

    /** Misma deducción que {@code Tarjeta.marcaDesdeNumero} en Flutter. */
    private String marcaDesdeNumero(String numero) {
        if (numero.startsWith("4")) return "Visa";
        if (numero.startsWith("5") || numero.startsWith("2")) return "Mastercard";
        if (numero.startsWith("3")) return "Amex";
        return "Tarjeta";
    }
}
