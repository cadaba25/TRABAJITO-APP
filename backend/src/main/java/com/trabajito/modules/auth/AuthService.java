package com.trabajito.modules.auth;

import com.trabajito.common.exception.ApiException;
import com.trabajito.common.exception.IntentosExcedidosException;
import com.trabajito.modules.auth.dto.AuthResponse;
import com.trabajito.modules.auth.dto.LoginRequest;
import com.trabajito.modules.auth.dto.RegistroRequest;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import com.trabajito.modules.usuarios.dto.UsuarioResponse;
import com.trabajito.security.JwtService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/** Registro y autenticación de usuarios. */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final UsuarioRepository usuarios;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final ControlFuerzaBruta controlFuerzaBruta;
    private final RefreshTokenService refreshTokens;

    public AuthService(UsuarioRepository usuarios,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService,
                       AuthenticationManager authenticationManager,
                       ControlFuerzaBruta controlFuerzaBruta,
                       RefreshTokenService refreshTokens) {
        this.usuarios = usuarios;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.authenticationManager = authenticationManager;
        this.controlFuerzaBruta = controlFuerzaBruta;
        this.refreshTokens = refreshTokens;
    }

    @Transactional
    public AuthResponse registrar(RegistroRequest req) {
        if (usuarios.existsByCorreo(req.correo().toLowerCase().trim())) {
            throw ApiException.conflicto("Ya existe una cuenta con ese correo");
        }
        Usuario u = Usuario.builder()
                .correo(req.correo().toLowerCase().trim())
                .passwordHash(passwordEncoder.encode(req.password()))
                .nombres(req.nombres().trim())
                .apellidos(req.apellidos().trim())
                .dni(req.dni())
                .telefono(req.telefono())
                // req.rol() es RolPublico: ADMIN no es expresable aqui (ADR-0005).
                .rol(req.rol().aRol())
                .departamento(req.departamento())
                .ciudad(req.ciudad())
                .build();
        usuarios.save(u);
        return construirRespuesta(u);
    }

    /**
     * Login con freno de fuerza bruta (tarea 015, ADR-0010).
     *
     * <p>Orden deliberado de los pasos:
     * <ol>
     *   <li><b>Cupo por IP primero</b>, antes de tocar BCrypt: asi una IP que
     *       ya se paso no puede seguir gastando CPU del servidor.</li>
     *   <li><b>Se verifica siempre la contrasena</b>, incluso si la cuenta
     *       acumulo muchos fallos. Esta es la clave para no crear un vector de
     *       denegacion de servicio contra una persona: <b>no existe ningun
     *       estado en el que la contrasena correcta sea rechazada</b>. Quien
     *       sabe la contrasena entra y limpia el contador; quien no la sabe
     *       (el atacante) es el unico que se topa con el 429.</li>
     * </ol>
     */
    public AuthResponse login(LoginRequest req, String ip) {
        String correo = req.correo().toLowerCase().trim();

        // 1. Tope duro por origen. Corta ANTES de ejecutar BCrypt.
        controlFuerzaBruta.exigirCupoDeIp(ip);

        // 2. Se comprueba la contrasena pase lo que pase con los contadores.
        try {
            // Lanza AuthenticationException si las credenciales no son válidas.
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(correo, req.password()));
        } catch (DisabledException | LockedException e) {
            // La cuenta existe y la contraseña puede ser correcta, pero está
            // suspendida. Al cliente le responde 401 con el MISMO mensaje que
            // una contraseña mala (GlobalExceptionHandler): si respondiéramos
            // algo distinto, cualquiera podría averiguar desde un endpoint
            // público qué cuentas existen y cuáles están suspendidas.
            // El motivo real se queda aquí, en el log del servidor, que es
            // donde hace falta para dar soporte (decisión de security-agent al
            // cerrar la tarea 008; ver tarea 009).
            log.warn("Login rechazado: la cuenta {} está suspendida ({})", correo,
                    e.getClass().getSimpleName());
            registrarFalloYFrenar(correo, ip);
            throw e;
        } catch (AuthenticationException e) {
            log.info("Login fallido para {} desde {}: {}", correo, ip,
                    e.getClass().getSimpleName());
            registrarFalloYFrenar(correo, ip);
            throw e;
        }

        Usuario u = usuarios.findByCorreo(correo)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));

        // 3. Entro el dueno legitimo: la cuenta deja de estar "con friccion".
        controlFuerzaBruta.registrarExito(correo, ip);
        return construirRespuesta(u);
    }

    /**
     * Anota el fallo y decide si este intento fallido merece ademas un 429.
     *
     * <p>Solo afecta a intentos que YA fallaron: el 429 sustituye al 401, nunca
     * a un 200. Por eso frenar la cuenta no puede dejar fuera a su dueno.
     */
    private void registrarFalloYFrenar(String correo, String ip) {
        controlFuerzaBruta.registrarFallo(correo, ip);
        if (controlFuerzaBruta.cuentaConFriccion(correo)) {
            log.warn("Cuenta {} con demasiados intentos fallidos recientes "
                    + "(ultimo desde {}): se responde 429", correo, ip);
            throw new IntentosExcedidosException(
                    "Demasiados intentos fallidos para esta cuenta. "
                            + "Espera unos minutos e inténtalo de nuevo.",
                    controlFuerzaBruta.retryAfterSegundos());
        }
    }

    /** Cambia un refresh token válido por un par nuevo (rotación, ADR-0010). */
    public AuthResponse refrescar(String refreshTokenPresentado) {
        RefreshTokenService.Rotacion r = refreshTokens.rotar(refreshTokenPresentado);
        Usuario u = usuarios.findById(r.usuarioId()).orElseThrow(this::sesionInvalida);
        // Una cuenta suspendida no puede renovar sesión: sin esta comprobación
        // seguiría emitiendo tokens de acceso hasta que caducara el refresh.
        if (!u.isActivo()) {
            log.warn("Refresh rechazado: la cuenta {} está suspendida", u.getCorreo());
            throw sesionInvalida();
        }
        String acceso = jwtService.generarToken(
                u.getId().toString(), u.getCorreo(), u.getRol().name());
        return AuthResponse.de(acceso, r.nuevoRefresh(), jwtService.expiracionSegundos(),
                UsuarioResponse.de(u));
    }

    /**
     * Cierra la sesión del dispositivo que la pide: revoca la <b>familia
     * entera</b> de refresh tokens a la que pertenece el presentado (ADR-0010,
     * corregido por ADR-0012 en la tarea 024). Antes se revocaba solo la fila
     * presentada, así que cualquier otro token vivo de esa misma sesión
     * —por ejemplo el recién emitido por una renovación en vuelo— seguía
     * sirviendo.
     *
     * <p>Las sesiones de los DEMÁS dispositivos del usuario no se tocan: cerrar
     * sesión en el móvil no debe cerrarla en la tablet. Para eso está
     * {@link #logoutDeTodosLosDispositivos(UUID)}.
     */
    public void logout(String refreshTokenPresentado) {
        refreshTokens.cerrarSesion(refreshTokenPresentado);
    }

    /**
     * Cierra la sesion en TODOS los dispositivos del usuario (ADR-0012),
     * incluida aquella desde la que se pide. Es la accion explicita para
     * cuando se sospecha que la cuenta esta comprometida.
     */
    public void logoutDeTodosLosDispositivos(UUID usuarioId) {
        log.info("Cierre de sesion en todos los dispositivos del usuario {}", usuarioId);
        refreshTokens.cerrarTodasLasSesiones(usuarioId);
    }

    private ApiException sesionInvalida() {
        return new ApiException(HttpStatus.UNAUTHORIZED,
                "Sesión inválida o expirada. Inicia sesión de nuevo.");
    }

    private AuthResponse construirRespuesta(Usuario u) {
        String token = jwtService.generarToken(
                u.getId().toString(), u.getCorreo(), u.getRol().name());
        String refresh = refreshTokens.emitirNuevaFamilia(u.getId());
        return AuthResponse.de(token, refresh, jwtService.expiracionSegundos(),
                UsuarioResponse.de(u));
    }
}
