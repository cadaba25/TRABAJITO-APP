package com.trabajito.modules.trabajos;

import com.trabajito.common.enums.EstadoTrabajo;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.pagos.PagoService;
import com.trabajito.modules.trabajos.dto.CrearTrabajoRequest;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Lógica de negocio del ciclo de vida de un trabajo (la "máquina de estados").
 * Toda autorización y validación vive aquí, NUNCA en el cliente.
 */
@Service
public class TrabajoService {

    private final TrabajoRepository trabajos;
    private final UsuarioRepository usuarios;
    private final PagoService pagoService;

    public TrabajoService(TrabajoRepository trabajos, UsuarioRepository usuarios,
                          PagoService pagoService) {
        this.trabajos = trabajos;
        this.usuarios = usuarios;
        this.pagoService = pagoService;
    }

    // ── Lectura ────────────────────────────────────────────────
    public Trabajo porId(UUID id) {
        return trabajos.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("El trabajo no existe"));
    }

    public Page<Trabajo> feed(int pagina, int tamano) {
        return trabajos.findByEstado(EstadoTrabajo.ACTIVO,
                PageRequest.of(pagina, tamano, Sort.by(Sort.Direction.DESC, "creadoEn")));
    }

    public List<Trabajo> misPublicaciones(UUID empleadorId) {
        return trabajos.findByEmpleadorIdOrderByCreadoEnDesc(empleadorId);
    }

    public List<Trabajo> misAsignados(UUID trabajadorId) {
        return trabajos.findByTrabajadorAsignadoIdOrderByCreadoEnDesc(trabajadorId);
    }

    // ── Publicar ───────────────────────────────────────────────
    @Transactional
    public Trabajo crear(UUID empleadorId, CrearTrabajoRequest req) {
        Usuario empleador = usuario(empleadorId);
        Trabajo t = Trabajo.builder()
                .empleadorId(empleadorId)
                .autorNombre(empleador.getNombreEmpresa() != null
                        && !empleador.getNombreEmpresa().isBlank()
                        ? empleador.getNombreEmpresa() : empleador.getNombreCompleto())
                .titulo(req.titulo().trim())
                .descripcion(req.descripcion())
                .categoria(req.categoria())
                .departamento(req.departamento())
                .ciudad(req.ciudad())
                .zona(req.zona())
                .presupuesto(req.presupuesto())
                .plazo(req.plazo())
                .estado(EstadoTrabajo.ACTIVO)
                .build();
        trabajos.save(t);
        empleador.setTrabajosPublicados(empleador.getTrabajosPublicados() + 1);
        usuarios.save(empleador);
        return t;
    }

    // ── Asignar trabajador (llamado al aceptar una postulación) ─
    @Transactional
    public Trabajo asignar(UUID trabajoId, UUID empleadorId, UUID trabajadorId,
                           String trabajadorNombre) {
        Trabajo t = porId(trabajoId);
        exigirEmpleador(t, empleadorId);
        if (t.getEstado() != EstadoTrabajo.ACTIVO) {
            throw ApiException.conflicto("Este trabajo ya no está disponible para asignar");
        }
        t.setEstado(EstadoTrabajo.ASIGNADO);
        t.setTrabajadorAsignadoId(trabajadorId);
        t.setTrabajadorAsignadoNombre(trabajadorNombre);
        return trabajos.save(t);
    }

    // ── Confirmar acuerdo + depositar pago en garantía ─────────
    @Transactional
    public Trabajo reservarPago(UUID trabajoId, UUID empleadorId, BigDecimal monto,
                                String tiempo) {
        Trabajo t = porId(trabajoId);
        exigirEmpleador(t, empleadorId);
        if (t.getEstado() != EstadoTrabajo.ASIGNADO) {
            throw ApiException.conflicto("El trabajo no está en negociación");
        }
        if (t.isPagoRetenido()) return t; // idempotente
        if (monto == null || monto.signum() <= 0) {
            throw ApiException.solicitudInvalida("Monto inválido");
        }
        pagoService.retener(empleadorId, monto, trabajoId);
        t.setMontoAcordado(monto);
        t.setTiempoAcordado(tiempo);
        t.setPagoRetenido(true);
        t.setFechaAcuerdo(Instant.now());
        t.setEstado(EstadoTrabajo.ACORDADO);
        return trabajos.save(t);
    }

    // ── Iniciar (trabajador) ───────────────────────────────────
    @Transactional
    public Trabajo iniciar(UUID trabajoId, UUID trabajadorId) {
        Trabajo t = porId(trabajoId);
        exigirTrabajador(t, trabajadorId);
        if (t.getEstado() != EstadoTrabajo.ACORDADO) {
            throw ApiException.conflicto("El trabajo no está listo para iniciar");
        }
        t.setEstado(EstadoTrabajo.EN_PROGRESO);
        t.setFechaInicio(Instant.now());
        t.setCorreccionSolicitada(false);
        return trabajos.save(t);
    }

    // ── Marcar terminado (trabajador) ──────────────────────────
    @Transactional
    public Trabajo marcarTerminado(UUID trabajoId, UUID trabajadorId) {
        Trabajo t = porId(trabajoId);
        exigirTrabajador(t, trabajadorId);
        if (t.getEstado() != EstadoTrabajo.EN_PROGRESO) {
            throw ApiException.conflicto("El trabajo no está en progreso");
        }
        t.setEntregado(true);
        t.setEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        return trabajos.save(t);
    }

    // ── Solicitar correcciones (empleador) ─────────────────────
    @Transactional
    public Trabajo solicitarCorreccion(UUID trabajoId, UUID empleadorId, String motivo) {
        Trabajo t = porId(trabajoId);
        exigirEmpleador(t, empleadorId);
        if (t.getEstado() != EstadoTrabajo.ESPERANDO_CONFIRMACION) {
            throw ApiException.conflicto("No hay entrega pendiente de revisión");
        }
        t.setEstado(EstadoTrabajo.EN_PROGRESO);
        t.setEntregado(false);
        t.setCorreccionSolicitada(true);
        t.setMotivoCorreccion(motivo);
        return trabajos.save(t);
    }

    // ── Aceptar y pagar (empleador) ────────────────────────────
    @Transactional
    public Trabajo aceptar(UUID trabajoId, UUID empleadorId) {
        Trabajo t = porId(trabajoId);
        exigirEmpleador(t, empleadorId);
        if (t.isPagoLiberado()) return t; // idempotente
        if (!t.isPagoRetenido()) {
            throw ApiException.conflicto("No hay pago en garantía para liberar");
        }
        if (t.getEstado() != EstadoTrabajo.ESPERANDO_CONFIRMACION) {
            throw ApiException.conflicto("El trabajo no está esperando confirmación");
        }
        // Libera el pago al trabajador y actualiza métricas de ambas partes.
        pagoService.liberar(t.getTrabajadorAsignadoId(), t.getMontoAcordado(), trabajoId);

        Usuario trabajador = usuario(t.getTrabajadorAsignadoId());
        trabajador.setTrabajosCompletados(trabajador.getTrabajosCompletados() + 1);
        usuarios.save(trabajador);

        Usuario empleador = usuario(empleadorId);
        empleador.setPagosConfirmados(empleador.getPagosConfirmados() + 1);
        usuarios.save(empleador);

        t.setPagoLiberado(true);
        t.setEstado(EstadoTrabajo.COMPLETADO);
        return trabajos.save(t);
    }

    // ── Cancelar contratación (empleador) ──────────────────────
    @Transactional
    public Trabajo cancelarContratacion(UUID trabajoId, UUID empleadorId) {
        Trabajo t = porId(trabajoId);
        exigirEmpleador(t, empleadorId);
        if (t.isPagoLiberado()) {
            throw ApiException.conflicto("El trabajo ya fue pagado; no se puede cancelar");
        }
        if (t.isPagoRetenido()) {
            pagoService.reembolsar(empleadorId, t.getMontoAcordado(), trabajoId);
        }
        reabrir(t);
        return trabajos.save(t);
    }

    // ── Rechazar asignación (trabajador, solo sin escrow) ──────
    @Transactional
    public Trabajo rechazarAsignacion(UUID trabajoId, UUID trabajadorId) {
        Trabajo t = porId(trabajoId);
        exigirTrabajador(t, trabajadorId);
        if (t.isPagoRetenido()) {
            throw ApiException.conflicto("El pago ya está en garantía; coordina con el contratista");
        }
        reabrir(t);
        return trabajos.save(t);
    }

    // ── Utilidades ─────────────────────────────────────────────
    private void reabrir(Trabajo t) {
        t.setEstado(EstadoTrabajo.ACTIVO);
        t.setTrabajadorAsignadoId(null);
        t.setTrabajadorAsignadoNombre(null);
        t.setPagoRetenido(false);
        t.setMontoAcordado(BigDecimal.ZERO);
        t.setTiempoAcordado(null);
        t.setEntregado(false);
        t.setCorreccionSolicitada(false);
    }

    private Usuario usuario(UUID id) {
        return usuarios.findById(id)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
    }

    private void exigirEmpleador(Trabajo t, UUID uid) {
        if (!t.getEmpleadorId().equals(uid)) {
            throw ApiException.prohibido("No eres el dueño de este trabajo");
        }
    }

    private void exigirTrabajador(Trabajo t, UUID uid) {
        if (t.getTrabajadorAsignadoId() == null || !t.getTrabajadorAsignadoId().equals(uid)) {
            throw ApiException.prohibido("No estás asignado a este trabajo");
        }
    }
}
