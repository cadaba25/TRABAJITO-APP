package com.trabajito.modules.trabajos;

import com.trabajito.common.enums.EstadoPostulacion;
import com.trabajito.common.enums.EstadoReporte;
import com.trabajito.common.enums.EstadoTrabajo;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.evidencias.EvidenciaRepository;
import com.trabajito.modules.pagos.MontoDinero;
import com.trabajito.modules.pagos.PagoService;
import com.trabajito.modules.postulaciones.Postulacion;
import com.trabajito.modules.postulaciones.PostulacionRepository;
import com.trabajito.modules.reportes.Reporte;
import com.trabajito.modules.reportes.ReporteRepository;
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
 * <p><b>Reglas de cancelación y entrega (ADR-0007).</b> El principio que las
 * ordena es que <i>ninguna de las dos partes pueda irse ganando</i>:
 * <ul>
 *   <li>Cancelar solo se puede ANTES de iniciar (ACTIVO/ASIGNADO/ACORDADO).
 *       Desde EN_PROGRESO el dinero está comprometido para los dos y NADIE
 *       cancela: ni el empleador ni el trabajador (409).</li>
 *   <li>El trabajador entrega con al menos una evidencia suya; si el empleador
 *       pidió correcciones, hace falta una evidencia posterior a esa petición.</li>
 *   <li>La única salida de un trabajo ya iniciado que no termina bien es
 *       {@code reclamarProblema()}: deja el trabajo EN_DISPUTA con el escrow
 *       congelado (ni liberado ni reembolsado) y solo un ADMIN lo resuelve.</li>
 *   <li>Al cancelar legítimamente, el empleador elige: reabrir al feed
 *       (ACTIVO) o cerrar (CANCELADO). En ambos casos las postulaciones quedan
 *       coherentes: nunca una ACEPTADA sobre un trabajo sin asignado.</li>
 * </ul>
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

    /** A quién le da la razón el ADMIN al resolver una disputa. */
    public enum FavorDisputa { TRABAJADOR, EMPLEADOR }

    private final TrabajoRepository trabajos;
    private final UsuarioRepository usuarios;
    private final PagoService pagoService;
    private final EvidenciaRepository evidencias;
    private final PostulacionRepository postulaciones;
    private final ReporteRepository reportes;

    public TrabajoService(TrabajoRepository trabajos, UsuarioRepository usuarios,
                          PagoService pagoService, EvidenciaRepository evidencias,
                          PostulacionRepository postulaciones, ReporteRepository reportes) {
        this.trabajos = trabajos;
        this.usuarios = usuarios;
        this.pagoService = pagoService;
        this.evidencias = evidencias;
        this.postulaciones = postulaciones;
        this.reportes = reportes;
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

    /** Cola de soporte: trabajos con el dinero congelado esperando a un ADMIN. */
    public List<Trabajo> enDisputa() {
        return trabajos.findByEstadoOrderByCreadoEnAsc(EstadoTrabajo.EN_DISPUTA);
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
    /**
     * Entrega del trabajo. Exige evidencias (ADR-0007): sin nada que enseñar,
     * el empleador tendría que confirmar a ciegas o pelear una disputa sin
     * material, que es justo el desequilibrio que esta regla evita.
     */
    @Transactional
    public Trabajo marcarTerminado(UUID trabajoId, UUID trabajadorId) {
        Trabajo t = bloquear(trabajoId);
        exigirTrabajador(t, trabajadorId);
        if (t.getEstado() != EstadoTrabajo.EN_PROGRESO) {
            throw ApiException.conflicto("El trabajo no está en progreso");
        }
        exigirEvidenciaDeEntrega(t);
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
        // Marca el corte a partir del cual hace falta una evidencia NUEVA para
        // poder volver a entregar (si no, bastaría con re-enviar la anterior).
        t.setFechaSolicitudCorreccion(Instant.now());
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
        if (t.getEstado() == EstadoTrabajo.EN_DISPUTA) {
            throw ApiException.conflicto(
                    "El trabajo está en disputa: soporte tiene que resolverla antes de mover el pago");
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

    // ── Cancelar contratación (empleador, solo antes de iniciar) ─
    /**
     * Cancelación legítima: solo desde ACTIVO/ASIGNADO/ACORDADO. El empleador
     * elige el destino del trabajo — {@code reabrirAlFeed=true} lo devuelve al
     * feed como ACTIVO, {@code false} lo cierra como CANCELADO —. El escrow, si
     * lo había, se reembolsa íntegro: el trabajador todavía no había empezado.
     */
    @Transactional
    public Trabajo cancelarContratacion(UUID trabajoId, UUID empleadorId, boolean reabrirAlFeed) {
        Trabajo t = bloquear(trabajoId);
        exigirEmpleador(t, empleadorId);
        exigirCancelable(t);
        if (t.isPagoRetenido()) {
            pagoService.reembolsar(empleadorId, t.getMontoAcordado(), trabajoId);
        }
        UUID saliente = t.getTrabajadorAsignadoId();
        if (reabrirAlFeed) {
            reabrir(t);
            // El trabajador desasignado queda RECHAZADA (fue el empleador quien
            // deshizo el trato); el resto vuelve a la carrera como PENDIENTE.
            resincronizarPostulaciones(trabajoId, saliente, EstadoPostulacion.RECHAZADA);
        } else {
            cerrarComoCancelado(t);
        }
        return trabajos.save(t);
    }

    // ── Rechazar asignación (trabajador, solo sin escrow) ──────
    @Transactional
    public Trabajo rechazarAsignacion(UUID trabajoId, UUID trabajadorId) {
        Trabajo t = bloquear(trabajoId);
        exigirTrabajador(t, trabajadorId);
        exigirNoIniciado(t);
        if (t.isPagoRetenido()) {
            throw ApiException.conflicto("El pago ya está en garantía; coordina con el contratista");
        }
        if (t.getEstado() != EstadoTrabajo.ASIGNADO) {
            throw ApiException.conflicto("No tienes una asignación activa en este trabajo");
        }
        UUID saliente = t.getTrabajadorAsignadoId();
        reabrir(t);
        // Aquí el que se sale es él: su postulación queda RETIRADA.
        resincronizarPostulaciones(trabajoId, saliente, EstadoPostulacion.RETIRADA);
        return trabajos.save(t);
    }

    // ── Reclamar un problema a soporte (cualquiera de las dos partes) ─
    /**
     * Única salida de un trabajo ya iniciado que no termina de común acuerdo.
     * Deja el trabajo EN_DISPUTA con el escrow <b>congelado</b>: nadie —ni el
     * empleador reembolsándose, ni el trabajador cobrando— puede mover el
     * dinero hasta que un ADMIN resuelva. Abre además un {@link Reporte} para
     * que aparezca en la bandeja de soporte.
     *
     * <p>Pueden reclamar las dos partes, a propósito: si solo pudiera el
     * empleador, el trabajador quedaría atrapado en un trabajo que no puede
     * cancelar y cuyo pago depende de que la otra parte quiera confirmarlo.
     */
    @Transactional
    public Trabajo reclamarProblema(UUID trabajoId, UUID usuarioId, String motivo,
                                    String descripcion) {
        Trabajo t = bloquear(trabajoId);
        boolean esEmpleador = t.getEmpleadorId().equals(usuarioId);
        boolean esTrabajador = usuarioId.equals(t.getTrabajadorAsignadoId());
        if (!esEmpleador && !esTrabajador) {
            throw ApiException.prohibido("No participas en este trabajo");
        }
        if (t.getEstado() == EstadoTrabajo.EN_DISPUTA) {
            throw ApiException.conflicto("Este trabajo ya está en disputa; soporte lo está revisando");
        }
        if (t.getEstado() != EstadoTrabajo.EN_PROGRESO
                && t.getEstado() != EstadoTrabajo.ESPERANDO_CONFIRMACION) {
            throw ApiException.conflicto(
                    "Solo se puede reclamar un problema con el trabajo en curso o ya entregado");
        }
        if (motivo == null || motivo.isBlank()) {
            throw ApiException.solicitudInvalida("Explica el motivo del reclamo");
        }
        t.setEstado(EstadoTrabajo.EN_DISPUTA);
        t.setDisputaAbiertaPorId(usuarioId);
        t.setMotivoDisputa(motivo.trim());
        // El escrow NO se toca: pagoRetenido sigue true y montoAcordado intacto.
        reportes.save(Reporte.builder()
                .reportanteId(usuarioId)
                .trabajoId(trabajoId)
                .reportadoId(esEmpleador ? t.getTrabajadorAsignadoId() : t.getEmpleadorId())
                .motivo(motivo.trim())
                .descripcion(descripcion)
                .estado(EstadoReporte.ABIERTO)
                .build());
        return trabajos.save(t);
    }

    // ── Resolver la disputa (solo ADMIN, ver AdminController) ──
    /**
     * Descongela el dinero en una sola dirección: o se libera al trabajador
     * (COMPLETADO) o se reembolsa al empleador (CANCELADO). No hay repartos
     * parciales: eso ya sería un sistema de disputas completo, fuera del
     * alcance de la tarea 010.
     */
    @Transactional
    public Trabajo resolverDisputa(UUID trabajoId, FavorDisputa aFavorDe, String resolucion) {
        Trabajo t = bloquear(trabajoId);
        if (t.getEstado() != EstadoTrabajo.EN_DISPUTA) {
            throw ApiException.conflicto("El trabajo no está en disputa");
        }
        if (t.isPagoLiberado()) {
            throw ApiException.conflicto("El pago de este trabajo ya fue liberado");
        }
        if (!t.isPagoRetenido()) {
            throw ApiException.conflicto("Este trabajo no tiene pago en garantía");
        }
        if (aFavorDe == FavorDisputa.TRABAJADOR) {
            UUID trabajadorId = t.getTrabajadorAsignadoId();
            bloquearUsuarios(trabajadorId);
            pagoService.liberar(trabajadorId, t.getMontoAcordado(), trabajoId);
            Usuario trabajador = usuario(trabajadorId);
            trabajador.setTrabajosCompletados(trabajador.getTrabajosCompletados() + 1);
            usuarios.save(trabajador);
            // pagosConfirmados del empleador NO sube: no confirmó él, resolvió soporte.
            t.setPagoLiberado(true);
            t.setEstado(EstadoTrabajo.COMPLETADO);
        } else {
            pagoService.reembolsar(t.getEmpleadorId(), t.getMontoAcordado(), trabajoId);
            cerrarComoCancelado(t);
        }
        t.setResolucionDisputa(resolucion);
        cerrarReportesDelTrabajo(trabajoId, resolucion);
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

    /** Regla 1 del dueño: una vez iniciado, nadie cancela (ADR-0007). */
    private void exigirNoIniciado(Trabajo t) {
        switch (t.getEstado()) {
            case EN_PROGRESO, ESPERANDO_CONFIRMACION -> throw ApiException.conflicto(
                    "El trabajo ya inició: ninguna de las dos partes puede cancelarlo. "
                            + "Si hay un problema, repórtalo a soporte.");
            case EN_DISPUTA -> throw ApiException.conflicto(
                    "El trabajo está en disputa: soporte tiene que resolverla.");
            default -> { }
        }
    }

    /** Estados desde los que el empleador todavía puede cancelar. */
    private void exigirCancelable(Trabajo t) {
        exigirNoIniciado(t);
        switch (t.getEstado()) {
            case ACTIVO, ASIGNADO, ACORDADO -> { }
            case COMPLETADO, FINALIZADO -> throw ApiException.conflicto(
                    "El trabajo ya fue pagado; no se puede cancelar");
            default -> throw ApiException.conflicto("El trabajo ya está cerrado; no se puede cancelar");
        }
    }

    /**
     * Exige material de entrega. Si el empleador pidió correcciones, no vale la
     * evidencia vieja: tiene que haber una posterior a la petición.
     */
    private void exigirEvidenciaDeEntrega(Trabajo t) {
        UUID trabajadorId = t.getTrabajadorAsignadoId();
        Instant corte = t.getFechaSolicitudCorreccion();
        if (t.isCorreccionSolicitada() && corte != null) {
            if (!evidencias.existsByTrabajoIdAndAutorIdAndCreadoEnAfter(t.getId(), trabajadorId, corte)) {
                throw ApiException.conflicto(
                        "El contratista pidió correcciones: sube una evidencia nueva "
                                + "(POST /api/trabajos/{id}/evidencias) antes de volver a entregar");
            }
            return;
        }
        if (!evidencias.existsByTrabajoIdAndAutorId(t.getId(), trabajadorId)) {
            throw ApiException.conflicto(
                    "Adjunta al menos una evidencia del trabajo "
                            + "(POST /api/trabajos/{id}/evidencias) antes de marcarlo como terminado");
        }
    }

    /** Devuelve el trabajo al feed, sin asignado y sin rastro del contrato. */
    private void reabrir(Trabajo t) {
        t.setEstado(EstadoTrabajo.ACTIVO);
        t.setTrabajadorAsignadoId(null);
        t.setTrabajadorAsignadoNombre(null);
        t.setPagoRetenido(false);
        t.setMontoAcordado(BigDecimal.ZERO);
        t.setTiempoAcordado(null);
        t.setFechaAcuerdo(null);
        t.setFechaInicio(null);
        t.setEntregado(false);
        t.setCorreccionSolicitada(false);
        t.setMotivoCorreccion(null);
        t.setFechaSolicitudCorreccion(null);
    }

    /**
     * Cierra el trabajo como CANCELADO (terminal). A diferencia de
     * {@link #reabrir}, conserva el vínculo con el trabajador y las marcas de
     * entrega: son el historial de lo que pasó. Solo se apagan las banderas de
     * escrow, porque el dinero ya volvió al empleador.
     */
    private void cerrarComoCancelado(Trabajo t) {
        t.setEstado(EstadoTrabajo.CANCELADO);
        t.setPagoRetenido(false);
        t.setMontoAcordado(BigDecimal.ZERO);
        cerrarPostulaciones(t.getId());
    }

    /**
     * Deja las postulaciones coherentes con un trabajo que vuelve al feed: el
     * que sale queda con {@code estadoSaliente} y los demás candidatos vuelven
     * a PENDIENTE (fueron RECHAZADA de forma automática al aceptar a otro, no
     * porque el empleador los descartara). Las RETIRADA no se tocan.
     */
    private void resincronizarPostulaciones(UUID trabajoId, UUID salienteId,
                                            EstadoPostulacion estadoSaliente) {
        for (Postulacion p : postulaciones.findByTrabajoId(trabajoId)) {
            if (p.getEstado() == EstadoPostulacion.RETIRADA) continue;
            p.setEstado(salienteId != null && salienteId.equals(p.getTrabajadorId())
                    ? estadoSaliente : EstadoPostulacion.PENDIENTE);
            postulaciones.save(p);
        }
    }

    /** Trabajo cerrado: ninguna postulación puede quedar viva. */
    private void cerrarPostulaciones(UUID trabajoId) {
        for (Postulacion p : postulaciones.findByTrabajoId(trabajoId)) {
            if (p.getEstado() == EstadoPostulacion.PENDIENTE
                    || p.getEstado() == EstadoPostulacion.ACEPTADA) {
                p.setEstado(EstadoPostulacion.RECHAZADA);
                postulaciones.save(p);
            }
        }
    }

    private void cerrarReportesDelTrabajo(UUID trabajoId, String resolucion) {
        for (Reporte r : reportes.findByTrabajoIdAndEstado(trabajoId, EstadoReporte.ABIERTO)) {
            r.setEstado(EstadoReporte.RESUELTO);
            r.setResolucion(resolucion);
            reportes.save(r);
        }
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
