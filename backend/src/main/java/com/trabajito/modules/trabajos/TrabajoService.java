package com.trabajito.modules.trabajos;

import com.trabajito.common.enums.EstadoTrabajo;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.pagos.MontoDinero;
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
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * Lógica de negocio del ciclo de vida de un trabajo (la "máquina de estados").
 * Toda autorización y validación vive aquí, NUNCA en el cliente.
 *
 * <p><b>Concurrencia (ADR-0006).</b> Cada transición bloquea la fila del
 * trabajo antes de mirar su estado o sus banderas de escrow: comprobar
 * {@code pagoRetenido}/{@code pagoLiberado} en memoria no protege de nada
 * frente a dos transacciones simultáneas en {@code READ COMMITTED}, que es el
 * aislamiento por defecto de PostgreSQL (cinco {@code aceptar} en paralelo
 * llegaron a escribir cuatro filas {@code LIBERACION}, tarea 007).
 *
 * <p>El <b>orden global de bloqueo</b> del backend es <b>trabajos → usuarios</b>,
 * y varios usuarios siempre en orden ascendente de UUID. Ninguna transacción
 * bloquea dos trabajos ni pide un trabajo después de un usuario, así que el
 * grafo de espera no puede tener ciclos (no hay deadlocks posibles entre estas
 * transacciones).
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
        // Bloquea al empleador: el contador trabajosPublicados también es un
        // read-modify-write y dos publicaciones a la vez perdían una cuenta.
        bloquearUsuarios(empleadorId);
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
        Trabajo t = bloquear(trabajoId);
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
    public Trabajo reservarPago(UUID trabajoId, UUID empleadorId, BigDecimal montoRecibido,
                                String tiempo) {
        Trabajo t = bloquear(trabajoId);
        exigirEmpleador(t, empleadorId);
        if (t.getEstado() != EstadoTrabajo.ASIGNADO) {
            throw ApiException.conflicto("El trabajo no está en negociación");
        }
        if (t.isPagoRetenido()) return t; // idempotente
        // Se valida y se fija la escala ANTES de tocar nada: el mismo valor
        // exacto se cobra del saldo y se guarda en monto_acordado.
        BigDecimal monto = MontoDinero.normalizar(montoRecibido);
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
        Trabajo t = bloquear(trabajoId);
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
        Trabajo t = bloquear(trabajoId);
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
        Trabajo t = bloquear(trabajoId);
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
        Trabajo t = bloquear(trabajoId);
        exigirEmpleador(t, empleadorId);
        if (t.isPagoLiberado()) return t; // idempotente
        if (!t.isPagoRetenido()) {
            throw ApiException.conflicto("No hay pago en garantía para liberar");
        }
        if (t.getEstado() != EstadoTrabajo.ESPERANDO_CONFIRMACION) {
            throw ApiException.conflicto("El trabajo no está esperando confirmación");
        }
        // Las dos partes se bloquean juntas y en orden de UUID (nunca en el
        // orden "empleador, trabajador", que sí podría cruzarse con otra
        // transacción y crear un ciclo de espera).
        bloquearUsuarios(empleadorId, t.getTrabajadorAsignadoId());

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
        Trabajo t = bloquear(trabajoId);
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
        Trabajo t = bloquear(trabajoId);
        exigirTrabajador(t, trabajadorId);
        if (t.isPagoRetenido()) {
            throw ApiException.conflicto("El pago ya está en garantía; coordina con el contratista");
        }
        reabrir(t);
        return trabajos.save(t);
    }

    // ── Utilidades ─────────────────────────────────────────────

    /**
     * Carga el trabajo bloqueando su fila. Primer bloqueo de toda transición
     * (orden global: trabajos → usuarios).
     */
    private Trabajo bloquear(UUID trabajoId) {
        return trabajos.findByIdParaActualizar(trabajoId)
                .orElseThrow(() -> ApiException.noEncontrado("El trabajo no existe"));
    }

    /**
     * Bloquea las filas de usuario indicadas SIEMPRE en orden ascendente de
     * UUID (ADR-0006): dos transacciones que bloqueen el mismo par de usuarios
     * lo hacen en el mismo orden, así que una espera a la otra en vez de
     * quedarse las dos esperándose.
     *
     * <p>Tras esto, {@code usuario(id)} devuelve la entidad ya bloqueada desde
     * la caché de primer nivel (sin ir otra vez a la BD).
     */
    private void bloquearUsuarios(UUID... ids) {
        Arrays.stream(ids).filter(Objects::nonNull).distinct().sorted()
                .forEach(id -> usuarios.findByIdParaActualizar(id)
                        .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado")));
    }

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
