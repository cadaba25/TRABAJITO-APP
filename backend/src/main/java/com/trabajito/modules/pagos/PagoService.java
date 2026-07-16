package com.trabajito.modules.pagos;

import com.trabajito.common.enums.TipoMovimiento;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * Movimientos de dinero de la cartera. TODA modificación de saldo pasa por aquí,
 * de forma transaccional, y queda registrada en {@link MovimientoCartera}.
 *
 * <p>NOTA: prototipo. En producción, las recargas/retiros reales deben
 * integrarse con una pasarela de pago (Tigo Money, tarjeta) y validarse contra
 * el proveedor antes de acreditar saldo.
 */
@Service
public class PagoService {

    private final UsuarioRepository usuarios;
    private final MovimientoCarteraRepository movimientos;

    public PagoService(UsuarioRepository usuarios, MovimientoCarteraRepository movimientos) {
        this.usuarios = usuarios;
        this.movimientos = movimientos;
    }

    /** Recarga de saldo (prototipo: sin pasarela real todavía). */
    @Transactional
    public BigDecimal recargar(UUID usuarioId, BigDecimal monto) {
        if (monto.signum() <= 0) throw ApiException.solicitudInvalida("Monto inválido");
        Usuario u = cargar(usuarioId);
        u.setSaldo(u.getSaldo().add(monto));
        usuarios.save(u);
        registrar(usuarioId, TipoMovimiento.RECARGA, monto, u.getSaldo(), null, "Recarga de saldo");
        return u.getSaldo();
    }

    /** Retiene un monto del saldo del empleador (escrow) al crear el contrato. */
    @Transactional
    public void retener(UUID empleadorId, BigDecimal monto, UUID trabajoId) {
        Usuario u = cargar(empleadorId);
        if (u.getSaldo().compareTo(monto) < 0) {
            throw ApiException.solicitudInvalida("Saldo insuficiente. Recarga tu cartera.");
        }
        u.setSaldo(u.getSaldo().subtract(monto));
        usuarios.save(u);
        registrar(empleadorId, TipoMovimiento.RETENCION, monto.negate(), u.getSaldo(),
                trabajoId, "Pago retenido en garantía");
    }

    /** Libera el monto retenido al trabajador. */
    @Transactional
    public void liberar(UUID trabajadorId, BigDecimal monto, UUID trabajoId) {
        Usuario u = cargar(trabajadorId);
        u.setSaldo(u.getSaldo().add(monto));
        usuarios.save(u);
        registrar(trabajadorId, TipoMovimiento.LIBERACION, monto, u.getSaldo(),
                trabajoId, "Pago recibido por trabajo");
    }

    /** Reembolsa el monto retenido al empleador (cancelación/disputa). */
    @Transactional
    public void reembolsar(UUID empleadorId, BigDecimal monto, UUID trabajoId) {
        Usuario u = cargar(empleadorId);
        u.setSaldo(u.getSaldo().add(monto));
        usuarios.save(u);
        registrar(empleadorId, TipoMovimiento.REEMBOLSO, monto, u.getSaldo(),
                trabajoId, "Reembolso de pago retenido");
    }

    public List<MovimientoCartera> historial(UUID usuarioId) {
        return movimientos.findByUsuarioIdOrderByCreadoEnDesc(usuarioId);
    }

    private Usuario cargar(UUID id) {
        return usuarios.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
    }

    private void registrar(UUID usuarioId, TipoMovimiento tipo, BigDecimal monto,
                           BigDecimal saldo, UUID trabajoId, String desc) {
        movimientos.save(MovimientoCartera.builder()
                .usuarioId(usuarioId).tipo(tipo).monto(monto)
                .saldoResultante(saldo).trabajoId(trabajoId).descripcion(desc)
                .build());
    }
}
