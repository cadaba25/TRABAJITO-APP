package com.trabajito.modules.trabajos;

import com.trabajito.common.enums.EstadoTrabajo;
import com.trabajito.common.exception.ApiException;
import com.trabajito.common.enums.EstadoPostulacion;
import com.trabajito.modules.evidencias.EvidenciaRepository;
import com.trabajito.modules.pagos.PagoService;
import com.trabajito.modules.postulaciones.Postulacion;
import com.trabajito.modules.postulaciones.PostulacionRepository;
import com.trabajito.modules.reportes.Reporte;
import com.trabajito.modules.reportes.ReporteRepository;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Tests unitarios de {@link TrabajoService}: la máquina de estados del
 * ciclo de vida de un trabajo, con foco en los flujos de dinero
 * (retención/liberación/reembolso de escrow vía {@link PagoService}, que se
 * mockea aquí) y en los "guard clauses" de autorización y de transición de
 * estado inválida, que son los casos de negocio más fáciles de romper con
 * un doble clic o una llamada fuera de orden desde el cliente.
 */
@ExtendWith(MockitoExtension.class)
class TrabajoServiceTest {

    @Mock
    TrabajoRepository trabajos;

    @Mock
    UsuarioRepository usuarios;

    @Mock
    PagoService pagoService;

    @Mock
    EvidenciaRepository evidencias;

    @Mock
    PostulacionRepository postulaciones;

    @Mock
    ReporteRepository reportes;

    TrabajoService trabajoService;

    UUID empleadorId;
    UUID trabajadorId;
    UUID trabajoId;

    @BeforeEach
    void setUp() {
        trabajoService = new TrabajoService(trabajos, usuarios, pagoService, evidencias,
                postulaciones, reportes);
        empleadorId = UUID.randomUUID();
        trabajadorId = UUID.randomUUID();
        trabajoId = UUID.randomUUID();

        lenient().when(trabajos.save(any(Trabajo.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private Trabajo trabajoEnEstado(EstadoTrabajo estado) {
        Trabajo t = Trabajo.builder()
                .empleadorId(empleadorId)
                .titulo("Reparar tubería")
                .estado(estado)
                .build();
        t.setId(trabajoId);
        if (estado.ordinal() >= EstadoTrabajo.ASIGNADO.ordinal()) {
            t.setTrabajadorAsignadoId(trabajadorId);
            t.setTrabajadorAsignadoNombre("Juan Trabajador");
        }
        return t;
    }

    // ── asignar ──────────────────────────────────────────────────

    @Test
    void asignar_trabajoActivo_loMueveAAsignado() {
        Trabajo activo = trabajoEnEstado(EstadoTrabajo.ACTIVO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(activo));

        Trabajo resultado = trabajoService.asignar(trabajoId, empleadorId, trabajadorId, "Juan");

        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.ASIGNADO);
        assertThat(resultado.getTrabajadorAsignadoId()).isEqualTo(trabajadorId);
    }

    @Test
    void asignar_siNoEsElEmpleadorDueno_lanzaProhibido() {
        Trabajo activo = trabajoEnEstado(EstadoTrabajo.ACTIVO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(activo));
        UUID otroUsuario = UUID.randomUUID();

        assertThatThrownBy(() ->
                trabajoService.asignar(trabajoId, otroUsuario, trabajadorId, "Juan"))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void asignar_trabajoYaAsignado_lanzaConflicto_noPermiteDobleAsignacion() {
        // Edge case tipo "doble submit": si dos postulantes se aceptan casi
        // al mismo tiempo, el segundo intento debe fallar, no sobreescribir
        // al trabajador ya asignado.
        Trabajo yaAsignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(yaAsignado));
        UUID otroTrabajador = UUID.randomUUID();

        assertThatThrownBy(() ->
                trabajoService.asignar(trabajoId, empleadorId, otroTrabajador, "Otro"))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        // El trabajador originalmente asignado no debe haber cambiado.
        assertThat(yaAsignado.getTrabajadorAsignadoId()).isEqualTo(trabajadorId);
    }

    // ── reservarPago (retener en escrow) ────────────────────────

    @Test
    void reservarPago_retieneEnEscrowYCambiaAAcordado() {
        Trabajo asignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(asignado));

        Trabajo resultado = trabajoService.reservarPago(
                trabajoId, empleadorId, new BigDecimal("500.00"), "3 días");

        verify(pagoService).retener(empleadorId, new BigDecimal("500.00"), trabajoId);
        assertThat(resultado.isPagoRetenido()).isTrue();
        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.ACORDADO);
        assertThat(resultado.getMontoAcordado()).isEqualByComparingTo("500.00");
    }

    @Test
    void reservarPago_montoCeroONegativo_noLlegaAPagoService() {
        Trabajo asignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(asignado));

        assertThatThrownBy(() ->
                trabajoService.reservarPago(trabajoId, empleadorId, BigDecimal.ZERO, "3 días"))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.BAD_REQUEST);

        verifyNoInteractions(pagoService);
    }

    @Test
    void reservarPago_esIdempotente_siYaEstaRetenidoNoRetieneDeNuevo() {
        // Doble clic / reintento de red: si el pago ya está retenido, un
        // segundo llamado no debe volver a descontar saldo del empleador.
        Trabajo yaAcordado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        yaAcordado.setPagoRetenido(true);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(yaAcordado));

        Trabajo resultado = trabajoService.reservarPago(
                trabajoId, empleadorId, new BigDecimal("500.00"), "3 días");

        assertThat(resultado).isSameAs(yaAcordado);
        verifyNoInteractions(pagoService);
        verify(trabajos, never()).save(any());
    }

    @Test
    void reservarPago_saldoInsuficiente_propagaExcepcionDePagoServiceSinCambiarEstado() {
        Trabajo asignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(asignado));
        org.mockito.Mockito.doThrow(ApiException.solicitudInvalida("Saldo insuficiente"))
                .when(pagoService).retener(any(), any(), any());

        assertThatThrownBy(() -> trabajoService.reservarPago(
                trabajoId, empleadorId, new BigDecimal("500.00"), "3 días"))
                .isInstanceOf(ApiException.class);

        assertThat(asignado.isPagoRetenido()).isFalse();
        assertThat(asignado.getEstado()).isEqualTo(EstadoTrabajo.ASIGNADO);
        verify(trabajos, never()).save(any());
    }

    // ── aceptar (liberar pago) ───────────────────────────────────

    @Test
    void aceptar_liberaPagoYActualizaMetricasDeAmbasPartes() {
        Trabajo esperando = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        esperando.setPagoRetenido(true);
        esperando.setMontoAcordado(new BigDecimal("500.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(esperando));

        Usuario trabajador = Usuario.builder().correo("t@x.com").nombres("T").apellidos("T")
                .rol(com.trabajito.common.enums.Rol.TRABAJADOR).build();
        trabajador.setTrabajosCompletados(2);
        Usuario empleador = Usuario.builder().correo("e@x.com").nombres("E").apellidos("E")
                .rol(com.trabajito.common.enums.Rol.EMPLEADOR).build();
        empleador.setPagosConfirmados(1);
        when(usuarios.findByIdParaActualizar(trabajadorId)).thenReturn(Optional.of(trabajador));
        when(usuarios.findByIdParaActualizar(empleadorId)).thenReturn(Optional.of(empleador));
        when(usuarios.findById(trabajadorId)).thenReturn(Optional.of(trabajador));
        when(usuarios.findById(empleadorId)).thenReturn(Optional.of(empleador));

        Trabajo resultado = trabajoService.aceptar(trabajoId, empleadorId);

        verify(pagoService).liberar(trabajadorId, new BigDecimal("500.00"), trabajoId);
        assertThat(trabajador.getTrabajosCompletados()).isEqualTo(3);
        assertThat(empleador.getPagosConfirmados()).isEqualTo(2);
        assertThat(resultado.isPagoLiberado()).isTrue();
        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.COMPLETADO);
    }

    @Test
    void aceptar_esIdempotente_siYaEstaLiberadoNoLiberaDeNuevo() {
        Trabajo completado = trabajoEnEstado(EstadoTrabajo.COMPLETADO);
        completado.setPagoLiberado(true);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(completado));

        Trabajo resultado = trabajoService.aceptar(trabajoId, empleadorId);

        assertThat(resultado).isSameAs(completado);
        verifyNoInteractions(pagoService);
        verifyNoInteractions(usuarios);
    }

    @Test
    void aceptar_sinPagoRetenido_lanzaConflicto() {
        Trabajo esperando = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        // pagoRetenido queda false a propósito.
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(esperando));

        assertThatThrownBy(() -> trabajoService.aceptar(trabajoId, empleadorId))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verifyNoInteractions(pagoService);
    }

    // ── cancelarContratacion / rechazarAsignacion ───────────────

    @Test
    void cancelarContratacion_conPagoRetenido_reembolsaYReabreElTrabajo() {
        Trabajo acordado = trabajoEnEstado(EstadoTrabajo.ACORDADO);
        acordado.setPagoRetenido(true);
        acordado.setMontoAcordado(new BigDecimal("300.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(acordado));

        Trabajo resultado = trabajoService.cancelarContratacion(trabajoId, empleadorId, true);

        verify(pagoService).reembolsar(empleadorId, new BigDecimal("300.00"), trabajoId);
        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.ACTIVO);
        assertThat(resultado.getTrabajadorAsignadoId()).isNull();
        assertThat(resultado.isPagoRetenido()).isFalse();
        assertThat(resultado.getMontoAcordado()).isEqualByComparingTo(BigDecimal.ZERO);
    }

    @Test
    void cancelarContratacion_siYaFuePagado_lanzaConflictoYNoReembolsaDosVeces() {
        Trabajo completado = trabajoEnEstado(EstadoTrabajo.COMPLETADO);
        completado.setPagoLiberado(true);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(completado));

        assertThatThrownBy(() -> trabajoService.cancelarContratacion(trabajoId, empleadorId, true))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verifyNoInteractions(pagoService);
    }

    @Test
    void rechazarAsignacion_conEscrowYaRetenido_lanzaConflicto() {
        // El trabajador no puede simplemente "salirse" si ya hay dinero en
        // garantía; debe coordinarse (evita dejar el escrow huérfano).
        Trabajo acordado = trabajoEnEstado(EstadoTrabajo.ACORDADO);
        acordado.setPagoRetenido(true);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(acordado));

        assertThatThrownBy(() -> trabajoService.rechazarAsignacion(trabajoId, trabajadorId))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verify(trabajos, never()).save(any());
    }

    @Test
    void rechazarAsignacion_siNoEsElTrabajadorAsignado_lanzaProhibido() {
        Trabajo asignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(asignado));
        UUID otroTrabajador = UUID.randomUUID();

        assertThatThrownBy(() -> trabajoService.rechazarAsignacion(trabajoId, otroTrabajador))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void marcarTerminado_trabajoQueNoExiste_lanzaNoEncontrado() {
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> trabajoService.marcarTerminado(trabajoId, trabajadorId))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.NOT_FOUND);
    }

    // ── concurrencia: disciplina de bloqueo (tarea 007 / ADR-0006) ──
    //
    // Estos tests NO prueban concurrencia (con mocks es imposible): prueban
    // que el servicio pide los bloqueos que la protegen. La prueba real de
    // concurrencia, con PostgreSQL y varios hilos, está en
    // modules/pagos/IntegridadCarteraConcurrenteTest.

    @Test
    void aceptar_bloqueaLaFilaDelTrabajoYLasDeLasDosPartes() {
        Trabajo esperando = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        esperando.setPagoRetenido(true);
        esperando.setMontoAcordado(new BigDecimal("500.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(esperando));
        Usuario trabajador = Usuario.builder().correo("t@x.com").nombres("T").apellidos("T")
                .rol(com.trabajito.common.enums.Rol.TRABAJADOR).build();
        Usuario empleador = Usuario.builder().correo("e@x.com").nombres("E").apellidos("E")
                .rol(com.trabajito.common.enums.Rol.EMPLEADOR).build();
        when(usuarios.findByIdParaActualizar(trabajadorId)).thenReturn(Optional.of(trabajador));
        when(usuarios.findByIdParaActualizar(empleadorId)).thenReturn(Optional.of(empleador));
        when(usuarios.findById(trabajadorId)).thenReturn(Optional.of(trabajador));
        when(usuarios.findById(empleadorId)).thenReturn(Optional.of(empleador));

        trabajoService.aceptar(trabajoId, empleadorId);

        // El trabajo se lee SIEMPRE con FOR UPDATE, nunca con el findById normal:
        // si alguien lo cambia, cinco "aceptar" simultáneos vuelven a pagar 5 veces.
        verify(trabajos).findByIdParaActualizar(trabajoId);
        verify(trabajos, never()).findById(any());
        verify(usuarios).findByIdParaActualizar(empleadorId);
        verify(usuarios).findByIdParaActualizar(trabajadorId);
    }

    @Test
    void aceptar_bloqueaAlEmpleadorYAlTrabajadorEnOrdenAscendenteDeUuid() {
        // El orden fijo (por UUID, no "empleador y luego trabajador") es lo que
        // impide un deadlock cuando dos trabajos cruzados se aceptan a la vez.
        Trabajo esperando = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        esperando.setPagoRetenido(true);
        esperando.setMontoAcordado(new BigDecimal("500.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(esperando));
        Usuario cualquiera = Usuario.builder().correo("x@x.com").nombres("X").apellidos("X")
                .rol(com.trabajito.common.enums.Rol.TRABAJADOR).build();
        when(usuarios.findByIdParaActualizar(any())).thenReturn(Optional.of(cualquiera));
        when(usuarios.findById(any())).thenReturn(Optional.of(cualquiera));

        trabajoService.aceptar(trabajoId, empleadorId);

        UUID primero = empleadorId.compareTo(trabajadorId) <= 0 ? empleadorId : trabajadorId;
        UUID segundo = primero.equals(empleadorId) ? trabajadorId : empleadorId;
        org.mockito.InOrder orden = org.mockito.Mockito.inOrder(trabajos, usuarios);
        orden.verify(trabajos).findByIdParaActualizar(trabajoId);
        orden.verify(usuarios).findByIdParaActualizar(primero);
        orden.verify(usuarios).findByIdParaActualizar(segundo);
    }

    @Test
    void reservarPago_conMasDeDosDecimales_lanza400YNoTocaElDinero() {
        // 0.005 no le cobraba nada al empleador (100 - 0.005 -> 100.00) pero se
        // guardaba como 0.01 en monto_acordado: un centavo que nadie pagó.
        Trabajo asignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(asignado));

        assertThatThrownBy(() -> trabajoService.reservarPago(
                trabajoId, empleadorId, new BigDecimal("0.005"), "1 día"))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.BAD_REQUEST);

        verifyNoInteractions(pagoService);
        assertThat(asignado.isPagoRetenido()).isFalse();
        assertThat(asignado.getMontoAcordado()).isEqualByComparingTo(BigDecimal.ZERO);
        verify(trabajos, never()).save(any());
    }

    @Test
    void reservarPago_cobraYGuardaExactamenteElMismoMontoNormalizado() {
        Trabajo asignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(asignado));

        Trabajo resultado = trabajoService.reservarPago(
                trabajoId, empleadorId, new BigDecimal("1500"), "3 días");

        // Mismo valor y misma escala en el cobro y en monto_acordado.
        verify(pagoService).retener(empleadorId, new BigDecimal("1500.00"), trabajoId);
        assertThat(resultado.getMontoAcordado()).isEqualTo(new BigDecimal("1500.00"));
    }

    // ── Reglas de cancelación y entrega (tarea 010 / ADR-0007) ──
    //
    // Principio del dueño del proyecto: "nunca ninguna de las dos partes debe
    // tener la ventaja de irse ganando". De ahí salen los tres bloques de
    // abajo: nadie cancela con el trabajo ya iniciado, no se entrega sin
    // evidencia, y la única salida del dinero atascado la decide un ADMIN.

    @Test
    void cancelar_conElTrabajoEnProgreso_lanzaConflictoYNoTocaElEscrow() {
        Trabajo enProgreso = trabajoEnEstado(EstadoTrabajo.EN_PROGRESO);
        enProgreso.setPagoRetenido(true);
        enProgreso.setMontoAcordado(new BigDecimal("400.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enProgreso));

        assertThatThrownBy(() -> trabajoService.cancelarContratacion(trabajoId, empleadorId, true))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verifyNoInteractions(pagoService);
        assertThat(enProgreso.isPagoRetenido()).isTrue();
        assertThat(enProgreso.getEstado()).isEqualTo(EstadoTrabajo.EN_PROGRESO);
        verify(trabajos, never()).save(any());
    }

    @Test
    void cancelar_trasLaEntrega_lanzaConflictoYNoReembolsa() {
        // El bug de la tarea 010: aquí el empleador se llevaba los 400 enteros
        // y se quedaba con el trabajo hecho.
        Trabajo entregado = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        entregado.setPagoRetenido(true);
        entregado.setEntregado(true);
        entregado.setMontoAcordado(new BigDecimal("400.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(entregado));

        assertThatThrownBy(() -> trabajoService.cancelarContratacion(trabajoId, empleadorId, true))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verifyNoInteractions(pagoService);
        assertThat(entregado.getEstado()).isEqualTo(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        assertThat(entregado.getTrabajadorAsignadoId()).isEqualTo(trabajadorId);
        verify(trabajos, never()).save(any());
    }

    @Test
    void rechazar_conElTrabajoEnProgreso_tampocoPuedeElTrabajador() {
        // La regla es simétrica: el trabajador tampoco se sale a mitad de obra.
        Trabajo enProgreso = trabajoEnEstado(EstadoTrabajo.EN_PROGRESO);
        enProgreso.setPagoRetenido(true);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enProgreso));

        assertThatThrownBy(() -> trabajoService.rechazarAsignacion(trabajoId, trabajadorId))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verifyNoInteractions(pagoService);
        verify(trabajos, never()).save(any());
    }

    @Test
    void rechazar_trasLaEntrega_tampocoPuedeElTrabajador() {
        Trabajo entregado = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        entregado.setPagoRetenido(true);
        entregado.setEntregado(true);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(entregado));

        assertThatThrownBy(() -> trabajoService.rechazarAsignacion(trabajoId, trabajadorId))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verifyNoInteractions(pagoService);
        verify(trabajos, never()).save(any());
    }

    @Test
    void cancelar_eligiendoCerrar_dejaElTrabajoCanceladoYNoVuelveAlFeed() {
        Trabajo acordado = trabajoEnEstado(EstadoTrabajo.ACORDADO);
        acordado.setPagoRetenido(true);
        acordado.setMontoAcordado(new BigDecimal("300.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(acordado));

        Trabajo resultado = trabajoService.cancelarContratacion(trabajoId, empleadorId, false);

        verify(pagoService).reembolsar(empleadorId, new BigDecimal("300.00"), trabajoId);
        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.CANCELADO);
        assertThat(resultado.isPagoRetenido()).isFalse();
        assertThat(resultado.getMontoAcordado()).isEqualByComparingTo(BigDecimal.ZERO);
        // El vínculo se conserva como historial: el trabajo ya no vuelve al feed.
        assertThat(resultado.getTrabajadorAsignadoId()).isEqualTo(trabajadorId);
    }

    @Test
    void cancelar_reabriendo_dejaLasPostulacionesCoherentes() {
        // No puede quedar una postulación ACEPTADA sobre un trabajo sin asignado.
        Trabajo asignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(asignado));
        Postulacion delAsignado = Postulacion.builder().trabajoId(trabajoId)
                .trabajadorId(trabajadorId).estado(EstadoPostulacion.ACEPTADA).build();
        UUID otroId = UUID.randomUUID();
        Postulacion delOtro = Postulacion.builder().trabajoId(trabajoId)
                .trabajadorId(otroId).estado(EstadoPostulacion.RECHAZADA).build();
        Postulacion retirada = Postulacion.builder().trabajoId(trabajoId)
                .trabajadorId(UUID.randomUUID()).estado(EstadoPostulacion.RETIRADA).build();
        when(postulaciones.findByTrabajoId(trabajoId))
                .thenReturn(List.of(delAsignado, delOtro, retirada));

        Trabajo resultado = trabajoService.cancelarContratacion(trabajoId, empleadorId, true);

        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.ACTIVO);
        assertThat(resultado.getTrabajadorAsignadoId()).isNull();
        assertThat(delAsignado.getEstado()).isEqualTo(EstadoPostulacion.RECHAZADA);
        // Los demás candidatos vuelven a la carrera (los había rechazado el
        // sistema al aceptar a otro, no el empleador).
        assertThat(delOtro.getEstado()).isEqualTo(EstadoPostulacion.PENDIENTE);
        assertThat(retirada.getEstado()).isEqualTo(EstadoPostulacion.RETIRADA);
    }

    @Test
    void cancelar_cerrando_dejaLasPostulacionesRechazadas() {
        Trabajo asignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(asignado));
        Postulacion aceptada = Postulacion.builder().trabajoId(trabajoId)
                .trabajadorId(trabajadorId).estado(EstadoPostulacion.ACEPTADA).build();
        Postulacion pendiente = Postulacion.builder().trabajoId(trabajoId)
                .trabajadorId(UUID.randomUUID()).estado(EstadoPostulacion.PENDIENTE).build();
        when(postulaciones.findByTrabajoId(trabajoId)).thenReturn(List.of(aceptada, pendiente));

        trabajoService.cancelarContratacion(trabajoId, empleadorId, false);

        assertThat(aceptada.getEstado()).isEqualTo(EstadoPostulacion.RECHAZADA);
        assertThat(pendiente.getEstado()).isEqualTo(EstadoPostulacion.RECHAZADA);
    }

    @Test
    void rechazar_dejaSuPostulacionRetiradaYReabreALosDemas() {
        Trabajo asignado = trabajoEnEstado(EstadoTrabajo.ASIGNADO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(asignado));
        Postulacion suya = Postulacion.builder().trabajoId(trabajoId)
                .trabajadorId(trabajadorId).estado(EstadoPostulacion.ACEPTADA).build();
        Postulacion otra = Postulacion.builder().trabajoId(trabajoId)
                .trabajadorId(UUID.randomUUID()).estado(EstadoPostulacion.RECHAZADA).build();
        when(postulaciones.findByTrabajoId(trabajoId)).thenReturn(List.of(suya, otra));

        Trabajo resultado = trabajoService.rechazarAsignacion(trabajoId, trabajadorId);

        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.ACTIVO);
        assertThat(suya.getEstado()).isEqualTo(EstadoPostulacion.RETIRADA);
        assertThat(otra.getEstado()).isEqualTo(EstadoPostulacion.PENDIENTE);
    }

    // ── entrega con evidencias ──────────────────────────────────

    @Test
    void marcarTerminado_sinNingunaEvidencia_lanzaConflicto() {
        Trabajo enProgreso = trabajoEnEstado(EstadoTrabajo.EN_PROGRESO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enProgreso));
        when(evidencias.existsByTrabajoIdAndAutorId(trabajoId, trabajadorId)).thenReturn(false);

        assertThatThrownBy(() -> trabajoService.marcarTerminado(trabajoId, trabajadorId))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        assertThat(enProgreso.isEntregado()).isFalse();
        assertThat(enProgreso.getEstado()).isEqualTo(EstadoTrabajo.EN_PROGRESO);
        verify(trabajos, never()).save(any());
    }

    @Test
    void marcarTerminado_conAlMenosUnaEvidencia_pasaAEsperandoConfirmacion() {
        Trabajo enProgreso = trabajoEnEstado(EstadoTrabajo.EN_PROGRESO);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enProgreso));
        when(evidencias.existsByTrabajoIdAndAutorId(trabajoId, trabajadorId)).thenReturn(true);

        Trabajo resultado = trabajoService.marcarTerminado(trabajoId, trabajadorId);

        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        assertThat(resultado.isEntregado()).isTrue();
    }

    @Test
    void marcarTerminado_trasUnaCorreccion_exigeUnaEvidenciaNueva() {
        // Re-entregar sin tocar nada sería quedarse con la ventaja de agotar
        // al contratista a base de entregas idénticas.
        Trabajo enProgreso = trabajoEnEstado(EstadoTrabajo.EN_PROGRESO);
        Instant corte = Instant.now();
        enProgreso.setCorreccionSolicitada(true);
        enProgreso.setFechaSolicitudCorreccion(corte);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enProgreso));
        when(evidencias.existsByTrabajoIdAndAutorIdAndCreadoEnAfter(trabajoId, trabajadorId, corte))
                .thenReturn(false);

        assertThatThrownBy(() -> trabajoService.marcarTerminado(trabajoId, trabajadorId))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verify(trabajos, never()).save(any());
    }

    @Test
    void marcarTerminado_trasUnaCorreccion_conEvidenciaNueva_vuelveAEntregar() {
        Trabajo enProgreso = trabajoEnEstado(EstadoTrabajo.EN_PROGRESO);
        Instant corte = Instant.now();
        enProgreso.setCorreccionSolicitada(true);
        enProgreso.setFechaSolicitudCorreccion(corte);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enProgreso));
        when(evidencias.existsByTrabajoIdAndAutorIdAndCreadoEnAfter(trabajoId, trabajadorId, corte))
                .thenReturn(true);

        Trabajo resultado = trabajoService.marcarTerminado(trabajoId, trabajadorId);

        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.ESPERANDO_CONFIRMACION);
    }

    // ── reclamo a soporte y resolución por un ADMIN ─────────────

    @Test
    void reclamar_dejaElTrabajoEnDisputaConElDineroCongelado() {
        Trabajo entregado = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        entregado.setPagoRetenido(true);
        entregado.setMontoAcordado(new BigDecimal("400.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(entregado));

        Trabajo resultado = trabajoService.reclamarProblema(
                trabajoId, empleadorId, "No hizo lo acordado", "Faltan dos lámparas");

        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.EN_DISPUTA);
        assertThat(resultado.getDisputaAbiertaPorId()).isEqualTo(empleadorId);
        // Ni liberado ni reembolsado: el escrow se queda donde está.
        verifyNoInteractions(pagoService);
        assertThat(resultado.isPagoRetenido()).isTrue();
        assertThat(resultado.getMontoAcordado()).isEqualByComparingTo(new BigDecimal("400.00"));
        verify(reportes).save(any(Reporte.class));
    }

    @Test
    void reclamar_tambienPuedeElTrabajador() {
        Trabajo entregado = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        entregado.setPagoRetenido(true);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(entregado));

        Trabajo resultado = trabajoService.reclamarProblema(
                trabajoId, trabajadorId, "No confirma la entrega", null);

        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.EN_DISPUTA);
        assertThat(resultado.getDisputaAbiertaPorId()).isEqualTo(trabajadorId);
    }

    @Test
    void reclamar_siNoParticipasEnElTrabajo_lanzaProhibido() {
        Trabajo entregado = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(entregado));

        assertThatThrownBy(() -> trabajoService.reclamarProblema(
                trabajoId, UUID.randomUUID(), "Me aburro", null))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void reclamar_antesDeIniciarElTrabajo_lanzaConflicto() {
        // Antes de iniciar la salida es cancelar, no meter a soporte de por medio.
        Trabajo acordado = trabajoEnEstado(EstadoTrabajo.ACORDADO);
        acordado.setPagoRetenido(true);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(acordado));

        assertThatThrownBy(() -> trabajoService.reclamarProblema(
                trabajoId, empleadorId, "Cambié de idea", null))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void cancelar_conElTrabajoEnDisputa_lanzaConflicto() {
        Trabajo enDisputa = trabajoEnEstado(EstadoTrabajo.EN_DISPUTA);
        enDisputa.setPagoRetenido(true);
        enDisputa.setMontoAcordado(new BigDecimal("400.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enDisputa));

        assertThatThrownBy(() -> trabajoService.cancelarContratacion(trabajoId, empleadorId, true))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verifyNoInteractions(pagoService);
    }

    @Test
    void aceptar_conElTrabajoEnDisputa_noLiberaElPago() {
        Trabajo enDisputa = trabajoEnEstado(EstadoTrabajo.EN_DISPUTA);
        enDisputa.setPagoRetenido(true);
        enDisputa.setMontoAcordado(new BigDecimal("400.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enDisputa));

        assertThatThrownBy(() -> trabajoService.aceptar(trabajoId, empleadorId))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verifyNoInteractions(pagoService);
    }

    @Test
    void resolverDisputa_aFavorDelTrabajador_liberaElPagoYCompletaElTrabajo() {
        Trabajo enDisputa = trabajoEnEstado(EstadoTrabajo.EN_DISPUTA);
        enDisputa.setPagoRetenido(true);
        enDisputa.setMontoAcordado(new BigDecimal("400.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enDisputa));
        Usuario trabajador = Usuario.builder().correo("t@x.com").nombres("T").apellidos("T")
                .rol(com.trabajito.common.enums.Rol.TRABAJADOR).build();
        when(usuarios.findByIdParaActualizar(trabajadorId)).thenReturn(Optional.of(trabajador));
        when(usuarios.findById(trabajadorId)).thenReturn(Optional.of(trabajador));

        Trabajo resultado = trabajoService.resolverDisputa(
                trabajoId, TrabajoService.FavorDisputa.TRABAJADOR, "El trabajo estaba hecho");

        verify(pagoService).liberar(trabajadorId, new BigDecimal("400.00"), trabajoId);
        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.COMPLETADO);
        assertThat(resultado.isPagoLiberado()).isTrue();
        assertThat(resultado.getResolucionDisputa()).isEqualTo("El trabajo estaba hecho");
        assertThat(trabajador.getTrabajosCompletados()).isEqualTo(1);
    }

    @Test
    void resolverDisputa_aFavorDelEmpleador_reembolsaYCancelaElTrabajo() {
        Trabajo enDisputa = trabajoEnEstado(EstadoTrabajo.EN_DISPUTA);
        enDisputa.setPagoRetenido(true);
        enDisputa.setMontoAcordado(new BigDecimal("400.00"));
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(enDisputa));

        Trabajo resultado = trabajoService.resolverDisputa(
                trabajoId, TrabajoService.FavorDisputa.EMPLEADOR, "No entregó nada");

        verify(pagoService).reembolsar(empleadorId, new BigDecimal("400.00"), trabajoId);
        assertThat(resultado.getEstado()).isEqualTo(EstadoTrabajo.CANCELADO);
        assertThat(resultado.isPagoRetenido()).isFalse();
        assertThat(resultado.isPagoLiberado()).isFalse();
    }

    @Test
    void resolverDisputa_siElTrabajoNoEstaEnDisputa_lanzaConflicto() {
        Trabajo entregado = trabajoEnEstado(EstadoTrabajo.ESPERANDO_CONFIRMACION);
        entregado.setPagoRetenido(true);
        when(trabajos.findByIdParaActualizar(trabajoId)).thenReturn(Optional.of(entregado));

        assertThatThrownBy(() -> trabajoService.resolverDisputa(
                trabajoId, TrabajoService.FavorDisputa.TRABAJADOR, "x"))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        verifyNoInteractions(pagoService);
    }
}
