package com.trabajito.modules.pagos;

import com.trabajito.common.enums.EstadoTrabajo;
import com.trabajito.common.enums.Rol;
import com.trabajito.common.enums.TipoMovimiento;
import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.evidencias.Evidencia;
import com.trabajito.modules.evidencias.EvidenciaRepository;
import com.trabajito.modules.trabajos.Trabajo;
import com.trabajito.modules.trabajos.TrabajoRepository;
import com.trabajito.modules.trabajos.TrabajoService;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Prueba de integridad del dinero con <b>concurrencia de verdad</b>: PostgreSQL
 * real (Testcontainers), transacciones reales y varios hilos golpeando a la vez.
 *
 * <p><b>Por qué no vale con los tests que ya había.</b> Los 34 tests previos son
 * Mockito puro (más uno de contexto con H2). Un <i>lost update</i> solo existe
 * si hay dos transacciones concurrentes sobre la misma fila: con mocks no hay
 * ni transacción ni fila, así que son estructuralmente incapaces de detectar
 * este bug — y de hecho pasaban al 100% mientras el backend dejaba que un
 * empleador con L. 1000 pagara L. 2000 (tarea 006).
 *
 * <p>Cada método comprueba, además del resultado del caso, el <b>invariante
 * contable</b>: {@code usuarios.saldo == SUM(movimientos_cartera.monto)}.
 *
 * <p>Si no hay Docker, la clase entera se salta
 * ({@code disabledWithoutDocker = true}) en vez de fallar. Es un compromiso
 * consciente: {@code mvn test} sigue pasando en máquinas sin Docker, pero ahí
 * esta protección NO se está verificando (ADR-0006).
 */
@SpringBootTest(properties = {
        // El contenedor arranca vacio: que Hibernate cree el esquema entero
        // (incluido el CHECK declarado con @Check en Usuario) y lo tire al final.
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "spring.jpa.properties.hibernate.format_sql=false",
        "trabajito.uploads.dir=./build-test-uploads"
})
@Testcontainers(disabledWithoutDocker = true)
class IntegridadCarteraConcurrenteTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired TrabajoService trabajoService;
    @Autowired PagoService pagoService;
    @Autowired UsuarioRepository usuarios;
    @Autowired TrabajoRepository trabajos;
    @Autowired MovimientoCarteraRepository movimientos;
    @Autowired EvidenciaRepository evidencias;
    @Autowired JdbcTemplate jdbc;

    // ── Caso 1: doble gasto entre dos trabajos ─────────────────

    @Test
    void dosReservasSimultaneasNoPuedenGastarElMismoSaldoDosVeces() {
        Usuario empleador = crearUsuario(Rol.EMPLEADOR);
        Usuario trabajador = crearUsuario(Rol.TRABAJADOR);
        pagoService.recargar(empleador.getId(), new BigDecimal("1000"));

        UUID t1 = crearTrabajoAsignado(empleador, trabajador);
        UUID t2 = crearTrabajoAsignado(empleador, trabajador);

        List<String> resultados = enParalelo(List.of(
                () -> reservar(t1, empleador.getId(), "1000"),
                () -> reservar(t2, empleador.getId(), "1000")));

        // Exactamente uno pasa; el otro se queda sin saldo.
        assertThat(resultados).containsExactlyInAnyOrder("OK", "400:Saldo insuficiente. Recarga tu cartera.");
        assertThat(saldo(empleador)).isEqualByComparingTo("0.00");
        assertThat(trabajos.findAllById(List.of(t1, t2)).stream().filter(Trabajo::isPagoRetenido))
                .hasSize(1);
        assertThat(movimientosDe(empleador, TipoMovimiento.RETENCION)).hasSize(1);
        cuadra(empleador);
    }

    // ── Caso 2: doble toque sobre el mismo trabajo (retener) ───

    @Test
    void cincoReservasSimultaneasDelMismoTrabajoRetienenUnaSolaVez() {
        Usuario empleador = crearUsuario(Rol.EMPLEADOR);
        Usuario trabajador = crearUsuario(Rol.TRABAJADOR);
        pagoService.recargar(empleador.getId(), new BigDecimal("1000"));
        UUID t = crearTrabajoAsignado(empleador, trabajador);

        List<Callable<String>> tareas = new ArrayList<>();
        for (int i = 0; i < 5; i++) tareas.add(() -> reservar(t, empleador.getId(), "1000"));
        List<String> resultados = enParalelo(tareas);

        // Los que llegan tarde ven pagoRetenido=true y devuelven el trabajo tal
        // cual (idempotente), pero SIN volver a cobrar.
        assertThat(resultados).allMatch(r -> r.equals("OK") || r.startsWith("409"));
        assertThat(movimientosDe(empleador, TipoMovimiento.RETENCION)).hasSize(1);
        assertThat(saldo(empleador)).isEqualByComparingTo("0.00");
        assertThat(trabajos.findById(t).orElseThrow().getMontoAcordado())
                .isEqualByComparingTo("1000.00");
        cuadra(empleador);
    }

    // ── Caso 3: doble toque al liberar el pago ─────────────────

    @Test
    void cincoAceptarSimultaneosLiberanElPagoUnaSolaVez() {
        Usuario empleador = crearUsuario(Rol.EMPLEADOR);
        Usuario trabajador = crearUsuario(Rol.TRABAJADOR);
        pagoService.recargar(empleador.getId(), new BigDecimal("1000"));
        UUID t = crearTrabajoAsignado(empleador, trabajador);
        trabajoService.reservarPago(t, empleador.getId(), new BigDecimal("1000"), "1 día");
        trabajoService.iniciar(t, trabajador.getId());
        entregar(t, trabajador);

        List<Callable<String>> tareas = new ArrayList<>();
        for (int i = 0; i < 5; i++) tareas.add(() -> {
            trabajoService.aceptar(t, empleador.getId());
            return "OK";
        });
        List<String> resultados = enParalelo(tareas);

        assertThat(resultados).containsOnly("OK");   // idempotente, no 500
        assertThat(movimientosDe(trabajador, TipoMovimiento.LIBERACION)).hasSize(1);
        assertThat(saldo(trabajador)).isEqualByComparingTo("1000.00");
        assertThat(usuarios.findById(trabajador.getId()).orElseThrow().getTrabajosCompletados())
                .isEqualTo(1);
        assertThat(usuarios.findById(empleador.getId()).orElseThrow().getPagosConfirmados())
                .isEqualTo(1);
        cuadra(empleador);
        cuadra(trabajador);
    }

    // ── Caso 4: cancelar tras la entrega ya no devuelve nada ────────────────────

    @Test
    void cancelarTrasLaEntregaNoDevuelveElDineroAunqueSeIntenteEnParalelo() {
        // Desde ADR-0007 el empleador ya no puede cancelar una entrega hecha:
        // ese era el bug de la tarea 010 (se llevaba el escrow entero Y el
        // trabajo hecho). Aqui se comprueba que el 409 no depende de ganar una
        // carrera: pase lo que pase, el reembolso no ocurre.
        Usuario empleador = crearUsuario(Rol.EMPLEADOR);
        Usuario trabajador = crearUsuario(Rol.TRABAJADOR);
        pagoService.recargar(empleador.getId(), new BigDecimal("1000"));
        UUID t = crearTrabajoAsignado(empleador, trabajador);
        trabajoService.reservarPago(t, empleador.getId(), new BigDecimal("1000"), "1 dia");
        trabajoService.iniciar(t, trabajador.getId());
        entregar(t, trabajador);

        List<String> resultados = enParalelo(List.of(
                () -> intentar(() -> trabajoService.aceptar(t, empleador.getId())),
                () -> intentar(() -> trabajoService.cancelarContratacion(
                        t, empleador.getId(), true))));
        assertThat(resultados).containsExactlyInAnyOrder("OK", "409");

        // El pago se libero al trabajador y NO hubo reembolso al empleador.
        assertThat(movimientosDe(empleador, TipoMovimiento.REEMBOLSO)).isEmpty();
        assertThat(saldo(trabajador)).isEqualByComparingTo("1000.00");
        assertThat(saldo(empleador)).isEqualByComparingTo("0.00");
        cuadra(empleador);
        cuadra(trabajador);
    }

    // ── Caso 5: resolver la disputa en dos sentidos a la vez ─

    @Test
    void resolverLaDisputaEnLosDosSentidosALaVezSoloMueveElDineroUnaVez() {
        // La unica transicion que todavia puede pagar O reembolsar el mismo
        // escrow es la resolucion de soporte (ADR-0007). Si dos administradores
        // resuelven a la vez en sentidos opuestos, solo una puede ganar.
        Usuario empleador = crearUsuario(Rol.EMPLEADOR);
        Usuario trabajador = crearUsuario(Rol.TRABAJADOR);
        pagoService.recargar(empleador.getId(), new BigDecimal("1000"));
        UUID t = crearTrabajoAsignado(empleador, trabajador);
        trabajoService.reservarPago(t, empleador.getId(), new BigDecimal("1000"), "1 dia");
        trabajoService.iniciar(t, trabajador.getId());
        entregar(t, trabajador);
        trabajoService.reclamarProblema(t, empleador.getId(), "No quedo como acordamos", null);

        List<String> resultados = enParalelo(List.of(
                () -> intentar(() -> trabajoService.resolverDisputa(
                        t, TrabajoService.FavorDisputa.TRABAJADOR, "a favor del trabajador")),
                () -> intentar(() -> trabajoService.resolverDisputa(
                        t, TrabajoService.FavorDisputa.EMPLEADOR, "a favor del empleador"))));
        assertThat(resultados).containsExactlyInAnyOrder("OK", "409");

        // Los 1000 acabaron en UNA de las dos carteras, nunca en las dos.
        BigDecimal total = saldo(empleador).add(saldo(trabajador));
        assertThat(total).isEqualByComparingTo("1000.00");
        assertThat(movimientosDe(trabajador, TipoMovimiento.LIBERACION).size()
                + movimientosDe(empleador, TipoMovimiento.REEMBOLSO).size()).isEqualTo(1);
        cuadra(empleador);
        cuadra(trabajador);
    }

    // ── Caso 6: el escrow congelado no se lo lleva nadie ──

    @Test
    void conElTrabajoEnDisputaNadiePuedeMoverElDineroPorSuCuenta() {
        Usuario empleador = crearUsuario(Rol.EMPLEADOR);
        Usuario trabajador = crearUsuario(Rol.TRABAJADOR);
        pagoService.recargar(empleador.getId(), new BigDecimal("1000"));
        UUID t = crearTrabajoAsignado(empleador, trabajador);
        trabajoService.reservarPago(t, empleador.getId(), new BigDecimal("1000"), "1 dia");
        trabajoService.iniciar(t, trabajador.getId());
        entregar(t, trabajador);
        trabajoService.reclamarProblema(t, trabajador.getId(), "No confirma la entrega", null);

        assertThat(intentar(() -> trabajoService.aceptar(t, empleador.getId()))).isEqualTo("409");
        assertThat(intentar(() -> trabajoService.cancelarContratacion(t, empleador.getId(), true)))
                .isEqualTo("409");
        assertThat(intentar(() -> trabajoService.rechazarAsignacion(t, trabajador.getId())))
                .isEqualTo("409");

        // El dinero sigue congelado: ni en la cartera de uno ni en la del otro.
        assertThat(saldo(empleador)).isEqualByComparingTo("0.00");
        assertThat(saldo(trabajador)).isEqualByComparingTo("0.00");
        assertThat(trabajos.findById(t).orElseThrow().isPagoRetenido()).isTrue();
        cuadra(empleador);
        cuadra(trabajador);
    }

    // ── Defecto B: escala del monto ────────────────────────────

    @Test
    void unMontoConMasDeDosDecimalesSeRechazaSinTocarNada() {
        Usuario empleador = crearUsuario(Rol.EMPLEADOR);
        Usuario trabajador = crearUsuario(Rol.TRABAJADOR);
        pagoService.recargar(empleador.getId(), new BigDecimal("100"));
        UUID t = crearTrabajoAsignado(empleador, trabajador);

        assertThatThrownBy(() -> trabajoService.reservarPago(
                t, empleador.getId(), new BigDecimal("0.005"), "1 día"))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> pagoService.recargar(empleador.getId(), new BigDecimal("10.005")))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> pagoService.recargar(
                empleador.getId(), new BigDecimal("99999999999999999999")))
                .isInstanceOf(ApiException.class);

        assertThat(saldo(empleador)).isEqualByComparingTo("100.00");
        Trabajo trabajo = trabajos.findById(t).orElseThrow();
        assertThat(trabajo.isPagoRetenido()).isFalse();
        assertThat(trabajo.getMontoAcordado()).isEqualByComparingTo("0.00");
        cuadra(empleador);

        // Y lo que sí es dinero válido sigue funcionando, con escala exacta.
        pagoService.recargar(empleador.getId(), new BigDecimal("10.25"));
        assertThat(saldo(empleador)).isEqualByComparingTo("110.25");
        cuadra(empleador);
    }

    // ── Última línea de defensa: el CHECK de la BD ─────────────

    @Test
    void laBaseDeDatosRechazaUnSaldoNegativoAunqueElCodigoJavaFalle() {
        Usuario u = crearUsuario(Rol.EMPLEADOR);
        Integer restricciones = jdbc.queryForObject(
                "SELECT count(*) FROM pg_constraint WHERE conname = 'ck_usuarios_saldo_no_negativo'",
                Integer.class);
        assertThat(restricciones).isEqualTo(1);

        assertThatThrownBy(() -> jdbc.update(
                "UPDATE usuarios SET saldo = -1 WHERE id = ?", u.getId()))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    // ── Utilidades ─────────────────────────────────────────────

    /** Lanza todas las tareas a la vez (barrera) y devuelve sus resultados. */
    private List<String> enParalelo(List<Callable<String>> tareas) {
        int n = tareas.size();
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CyclicBarrier salida = new CyclicBarrier(n);
        try {
            List<Future<String>> futuros = new ArrayList<>();
            for (Callable<String> tarea : tareas) {
                futuros.add(pool.submit(() -> {
                    salida.await(20, TimeUnit.SECONDS);   // todos arrancan juntos
                    return tarea.call();
                }));
            }
            List<String> resultados = new ArrayList<>();
            for (Future<String> f : futuros) resultados.add(f.get(60, TimeUnit.SECONDS));
            return resultados;
        } catch (Exception e) {
            throw new IllegalStateException("Fallo ejecutando las tareas en paralelo", e);
        } finally {
            pool.shutdownNow();
        }
    }

    /** Ejecuta la accion y traduce el fallo de negocio a su codigo HTTP. */
    private String intentar(Runnable accion) {
        try {
            accion.run();
            return "OK";
        } catch (ApiException e) {
            return String.valueOf(e.getStatus().value());
        }
    }

    private String reservar(UUID trabajoId, UUID empleadorId, String monto) {
        try {
            trabajoService.reservarPago(trabajoId, empleadorId, new BigDecimal(monto), "1 día");
            return "OK";
        } catch (ApiException e) {
            return e.getStatus().value() + ":" + e.getMessage();
        }
    }

    /**
     * Entrega el trabajo como lo exige ADR-0007: primero una evidencia del
     * trabajador, despues marcarTerminado (sin evidencia devolveria 409).
     */
    private void entregar(UUID trabajoId, Usuario trabajador) {
        evidencias.save(Evidencia.builder()
                .trabajoId(trabajoId)
                .autorId(trabajador.getId())
                .autorNombre(trabajador.getNombreCompleto())
                .texto("Trabajo terminado, foto adjunta.")
                .build());
        trabajoService.marcarTerminado(trabajoId, trabajador.getId());
    }

    private Usuario crearUsuario(Rol rol) {
        return usuarios.save(Usuario.builder()
                .correo("conc." + UUID.randomUUID() + "@trabajito.local")
                .passwordHash("$2a$10$noimporta")
                .nombres("Prueba").apellidos("Concurrente")
                .rol(rol)
                .build());
    }

    private UUID crearTrabajoAsignado(Usuario empleador, Usuario trabajador) {
        Trabajo t = Trabajo.builder()
                .empleadorId(empleador.getId())
                .autorNombre(empleador.getNombreCompleto())
                .titulo("Trabajo de prueba concurrente")
                .estado(EstadoTrabajo.ASIGNADO)
                .trabajadorAsignadoId(trabajador.getId())
                .trabajadorAsignadoNombre(trabajador.getNombreCompleto())
                .build();
        return trabajos.save(t).getId();
    }

    private BigDecimal saldo(Usuario u) {
        return usuarios.findById(u.getId()).orElseThrow().getSaldo();
    }

    private List<MovimientoCartera> movimientosDe(Usuario u, TipoMovimiento tipo) {
        return movimientos.findByUsuarioIdOrderByCreadoEnDesc(u.getId())
                .stream().filter(m -> m.getTipo() == tipo).toList();
    }

    /** El invariante contable: el saldo es exactamente la suma del libro. */
    private void cuadra(Usuario u) {
        BigDecimal suma = movimientos.findByUsuarioIdOrderByCreadoEnDesc(u.getId())
                .stream().map(MovimientoCartera::getMonto)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        assertThat(saldo(u))
                .as("usuarios.saldo debe cuadrar con SUM(movimientos_cartera.monto)")
                .isEqualByComparingTo(suma);
    }
}
