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
 * <p><b>Concurrencia (ADR-0006).</b> Cada método bloquea la fila del usuario
 * ({@code SELECT ... FOR UPDATE}) antes de leer el saldo. Sin ese bloqueo, dos
 * peticiones simultáneas leían el mismo saldo y la última escritura ganaba:
 * verificado contra PostgreSQL real, un empleador con L. 1000 conseguía
 * retener L. 1000 en dos trabajos a la vez y pagar L. 2000 (tarea 007).
 * El orden global de bloqueo del backend es <b>trabajos → usuarios</b>, y
 * varios usuarios siempre en orden ascendente de UUID; este servicio está
 * siempre en el lado "usuarios" de ese orden.
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
    public BigDecimal recargar(UUID usuarioId, BigDecimal montoRecibido) {
        BigDecimal monto = MontoDinero.normalizar(montoRecibido);
        Usuario u = bloquear(usuarioId);
        return aplicar(u, monto, TipoMovimiento.RECARGA, null, "Recarga de saldo");
    }

    /** Retiene un monto del saldo del empleador (escrow) al crear el contrato. */
    @Transactional
    public void retener(UUID empleadorId, BigDecimal montoRecibido, UUID trabajoId) {
        BigDecimal monto = MontoDinero.normalizar(montoRecibido);
        Usuario u = bloquear(empleadorId);
        if (u.getSaldo().compareTo(monto) < 0) {
            throw ApiException.solicitudInvalida("Saldo insuficiente. Recarga tu cartera.");
        }
        aplicar(u, monto.negate(), TipoMovimiento.RETENCION, trabajoId,
                "Pago retenido en garantía");
    }

    /** Libera el monto retenido al trabajador. */
    @Transactional
    public void liberar(UUID trabajadorId, BigDecimal montoRecibido, UUID trabajoId) {
        BigDecimal monto = MontoDinero.normalizar(montoRecibido);
        Usuario u = bloquear(trabajadorId);
        aplicar(u, monto, TipoMovimiento.LIBERACION, trabajoId, "Pago recibido por trabajo");
    }

    /** Reembolsa el monto retenido al empleador (cancelación/disputa). */
    @Transactional
    public void reembolsar(UUID empleadorId, BigDecimal montoRecibido, UUID trabajoId) {
        BigDecimal monto = MontoDinero.normalizar(montoRecibido);
        Usuario u = bloquear(empleadorId);
        aplicar(u, monto, TipoMovimiento.REEMBOLSO, trabajoId, "Reembolso de pago retenido");
    }

    public List<MovimientoCartera> historial(UUID usuarioId) {
        return movimientos.findByUsuarioIdOrderByCreadoEnDesc(usuarioId);
    }

    /**
     * Bloquea la fila del usuario para el resto de la transacción.
     *
     * <p>Debe ser la primera lectura de esa entidad en la transacción: si ya
     * estuviera en la caché de primer nivel, Hibernate bloquearía la fila pero
     * devolvería los valores viejos.
     */
    private Usuario bloquear(UUID id) {
        return usuarios.findByIdParaActualizar(id)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
    }

    /**
     * Aplica el delta al saldo (ya bloqueado) y deja el asiento en el libro.
     * Es el ÚNICO sitio del backend que escribe {@code usuarios.saldo}, para
     * que no pueda haber un movimiento de dinero sin su fila en
     * {@code movimientos_cartera} (invariante:
     * {@code saldo == SUM(movimientos_cartera.monto)}).
     */
    private BigDecimal aplicar(Usuario u, BigDecimal delta, TipoMovimiento tipo,
                               UUID trabajoId, String desc) {
        BigDecimal nuevo = u.getSaldo().add(delta);
        if (nuevo.signum() < 0) {
            // Defensa en profundidad: con el bloqueo puesto esto ya no debería
            // poder pasar, y la BD lo rechazaría igual (ck_usuarios_saldo_no_negativo).
            throw ApiException.solicitudInvalida("Saldo insuficiente. Recarga tu cartera.");
        }
        u.setSaldo(nuevo);
        usuarios.save(u);
        movimientos.save(MovimientoCartera.builder()
                .usuarioId(u.getId()).tipo(tipo).monto(delta)
                .saldoResultante(nuevo).trabajoId(trabajoId).descripcion(desc)
                .build());
        return nuevo;
    }
}
