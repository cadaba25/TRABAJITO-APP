package com.trabajito.modules.auth;

import com.trabajito.common.exception.ApiException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

/**
 * Emite, rota y revoca refresh tokens (tarea 015, ADR-0010; revocacion por
 * familia al cerrar sesion desde la tarea 024, ADR-0012).
 *
 * <p>El refresh token es una cadena opaca aleatoria; en la BD solo se guarda su
 * hash SHA-256. La sesión es revocable de verdad porque su validez depende de
 * una fila (no de una firma como el JWT de acceso): cerrar sesión revoca esas
 * filas y los tokens dejan de valer al instante.
 */
@Service
public class RefreshTokenService {

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenService.class);

    private static final SecureRandom RNG = new SecureRandom();
    private static final Base64.Encoder B64 = Base64.getUrlEncoder().withoutPadding();

    private final RefreshTokenRepository repo;
    private final RevocadorDeFamilias revocador;
    private final long expiracionMs;

    public RefreshTokenService(RefreshTokenRepository repo,
                               RevocadorDeFamilias revocador,
                               @Value("${trabajito.jwt.refresh-expiration-ms:2592000000}") long expiracionMs) {
        this.repo = repo;
        this.revocador = revocador;
        this.expiracionMs = expiracionMs;
    }

    /** Par (valor en claro para el cliente, fila persistida). */
    public record NuevoRefresh(String valor, RefreshToken fila) {}

    /** Emite un refresh token nuevo, inaugurando una familia (login/registro). */
    @Transactional
    public String emitirNuevaFamilia(UUID usuarioId) {
        return emitir(usuarioId, UUID.randomUUID()).valor();
    }

    private NuevoRefresh emitir(UUID usuarioId, UUID familia) {
        String valor = generarValor();
        RefreshToken fila = repo.save(RefreshToken.builder()
                .tokenHash(hash(valor))
                .usuarioId(usuarioId)
                .familia(familia)
                .expiraEn(Instant.now().plusMillis(expiracionMs))
                .revocado(false)
                .build());
        return new NuevoRefresh(valor, fila);
    }

    /** Resultado de una rotación: a quién pertenece y el nuevo refresh en claro. */
    public record Rotacion(UUID usuarioId, String nuevoRefresh) {}

    /**
     * Rota un refresh token: revoca el presentado y emite otro de la misma
     * familia. Reglas:
     * <ul>
     *   <li>No existe → 401 (token inventado o ya borrado).</li>
     *   <li>Ya revocado → <b>reutilización</b>: se revoca toda la familia
     *       (posible robo) y se responde 401.</li>
     *   <li>Caducado → 401.</li>
     * </ul>
     */
    @Transactional
    public Rotacion rotar(String valorPresentado) {
        RefreshToken fila = repo.findByTokenHash(hash(valorPresentado))
                // No encontrado = token inventado o ya borrado: 401 neutro, no
                // 404 (no revelamos si existe o no).
                .orElseThrow(this::sesionInvalida);
        if (fila.isRevocado()) {
            // Un refresh ya usado se esta reutilizando: tratalo como robo y
            // tira abajo toda la familia (todas las rotaciones de esa sesion).
            // OJO: la revocacion va en su propia transaccion, porque el 401 de
            // la linea siguiente haria rollback de todo lo hecho aqui.
            revocador.revocarFamilia(fila.getFamilia());
            throw sesionInvalida();
        }
        if (!fila.estaVigente()) {
            throw sesionInvalida();
        }
        fila.setRevocado(true);
        repo.save(fila);
        NuevoRefresh nuevo = emitir(fila.getUsuarioId(), fila.getFamilia());
        return new Rotacion(fila.getUsuarioId(), nuevo.valor());
    }

    /**
     * Cierra la sesión a la que pertenece el token presentado: revoca
     * <b>toda su familia</b>, no solo la fila presentada (tarea 024, ADR-0012).
     *
     * <p>Antes se marcaba únicamente el token recibido, y eso dejaba vivo
     * cualquier otro token de la misma sesión. El caso real que lo destapó (QA,
     * tarea 022): cerrar sesión mientras había una renovación en vuelo. El
     * cliente mandaba al {@code logout} el token viejo y se quedaba en el
     * dispositivo el par recién rotado, que el servidor seguía aceptando.
     *
     * <p>Se revoca la familia <b>aunque la fila presentada ya esté revocada o
     * caducada</b>: ese es justo el caso de la renovación en vuelo. Presentar un
     * token conocido basta para probar que se tuvo esa sesión, y el peor efecto
     * posible de equivocarse aquí es cerrar una sesión de más, nunca dejar una
     * abierta. Es además coherente con la detección de reutilización, que ante
     * un token revocado tumba la familia entera.
     *
     * <p>Idempotente: si el token no existe, no hace nada (el controller
     * responde 204 igual, para que un logout no sirva de oráculo de tokens).
     *
     * @return cuántos tokens vivos se revocaron
     */
    @Transactional
    public int cerrarSesion(String valorPresentado) {
        return repo.findByTokenHash(hash(valorPresentado))
                .map(fila -> {
                    int revocados = repo.revocarFamilia(fila.getFamilia());
                    log.info("Cierre de sesión: revocados {} refresh tokens de la familia {}",
                            revocados, fila.getFamilia());
                    return revocados;
                })
                .orElse(0);
    }

    /**
     * Cierra <b>todas</b> las sesiones del usuario, en todos sus dispositivos
     * (tarea 024, ADR-0012). Incluye la sesión desde la que se pide: es lo que
     * se busca al sospechar que la cuenta está comprometida.
     *
     * @return cuántos tokens vivos se revocaron
     */
    @Transactional
    public int cerrarTodasLasSesiones(UUID usuarioId) {
        int revocados = repo.revocarTodosDeUsuario(usuarioId);
        log.info("Cierre de sesión en TODOS los dispositivos del usuario {}: "
                + "revocados {} refresh tokens", usuarioId, revocados);
        return revocados;
    }

    /** Un refresh inválido, revocado o caducado responde 401 con mensaje neutro. */
    private ApiException sesionInvalida() {
        return new ApiException(org.springframework.http.HttpStatus.UNAUTHORIZED,
                "Sesión inválida o expirada. Inicia sesión de nuevo.");
    }

    private static String generarValor() {
        byte[] bytes = new byte[32];
        RNG.nextBytes(bytes);
        return B64.encodeToString(bytes);
    }

    private static String hash(String valor) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(valor.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 no disponible", e);
        }
    }
}
