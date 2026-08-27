package com.trabajito.modules.auth;

import com.trabajito.common.exception.IntentosExcedidosException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

/**
 * Freno a la fuerza bruta contra {@code /api/auth/login} (tarea 015, ADR-0010).
 *
 * <p>Cuenta intentos FALLIDOS en una ventana deslizante, en dos ejes
 * independientes:
 * <ul>
 *   <li><b>Por IP</b> ({@code max-por-ip}): defensa dura. Al superarlo, la IP
 *       recibe 429 <b>antes</b> de ejecutar BCrypt — frena a un atacante de una
 *       sola fuente y acota el coste de CPU. Se indexa por la IP del atacante,
 *       así que no sirve para dejar fuera a una víctima concreta.</li>
 *   <li><b>Por cuenta</b> ({@code max-por-cuenta}): fricción + detección, SIN
 *       lockout. Cuando se supera, los intentos con contraseña <b>incorrecta</b>
 *       reciben 429, pero la contraseña <b>correcta sigue entrando</b> (eso lo
 *       decide {@code AuthService}, que solo consulta {@link #cuentaConFriccion}
 *       para elegir 429 vs 401 en un fallo). Así se frena el ataque sin poder
 *       bloquear a un usuario legítimo: no existe estado donde la contraseña
 *       correcta sea rechazada.</li>
 * </ul>
 */
@Service
public class ControlFuerzaBruta {

    private static final Logger log = LoggerFactory.getLogger(ControlFuerzaBruta.class);

    private final IntentoLoginRepository repo;
    private final Duration ventana;
    private final long maxPorIp;
    private final long maxPorCuenta;

    public ControlFuerzaBruta(
            IntentoLoginRepository repo,
            @Value("${trabajito.login.ventana-minutos:15}") long ventanaMinutos,
            @Value("${trabajito.login.max-por-ip:20}") long maxPorIp,
            @Value("${trabajito.login.max-por-cuenta:5}") long maxPorCuenta) {
        this.repo = repo;
        this.ventana = Duration.ofMinutes(ventanaMinutos);
        this.maxPorIp = maxPorIp;
        this.maxPorCuenta = maxPorCuenta;
    }

    /**
     * Corta ANTES de tocar BCrypt si la IP superó su cupo de fallos. Lanza
     * 429 con {@code Retry-After}. No mira la cuenta: es un tope por origen.
     */
    public void exigirCupoDeIp(String ip) {
        long fallos = repo.countByIpAndExitoFalseAndCreadoEnAfter(ip, desde());
        if (fallos >= maxPorIp) {
            log.warn("Fuerza bruta por IP: {} fallos desde {} en {} min", fallos, ip,
                    ventana.toMinutes());
            throw new IntentosExcedidosException(
                    "Demasiados intentos desde tu red. Espera un momento e inténtalo de nuevo.",
                    ventana.getSeconds());
        }
    }

    /**
     * true si la cuenta acumulo demasiados fallos recientes (entra "con
     * friccion").
     *
     * <p>Se consulta DESPUES de anotar el intento fallido, asi que la
     * comparacion es estricta: con {@code max-por-cuenta=5}, los cinco
     * primeros fallos responden 401 normal y el <b>sexto</b> es el primero que
     * recibe 429. Un usuario que se equivoca tres veces no nota nada.
     */
    public boolean cuentaConFriccion(String correo) {
        return repo.countByCorreoAndExitoFalseAndCreadoEnAfter(correo, desde()) > maxPorCuenta;
    }

    /** Segundos que el cliente debería esperar (para el {@code Retry-After} del 429 por cuenta). */
    public long retryAfterSegundos() {
        return ventana.getSeconds();
    }

    /**
     * Registra un fallo. En transacción propia (REQUIRES_NEW) para que quede
     * grabado aunque el login termine lanzando una excepción.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void registrarFallo(String correo, String ip) {
        repo.save(IntentoLogin.builder().correo(correo).ip(ip).exito(false).build());
    }

    /**
     * Registra un login correcto y limpia los fallos previos de esa cuenta: el
     * dueño legítimo entró, así que la cuenta deja de estar "con fricción". El
     * atacante no puede disparar esto porque no conoce la contraseña.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void registrarExito(String correo, String ip) {
        repo.save(IntentoLogin.builder().correo(correo).ip(ip).exito(true).build());
        repo.borrarFallosDeCuenta(correo);
    }

    private Instant desde() {
        return Instant.now().minus(ventana);
    }
}
