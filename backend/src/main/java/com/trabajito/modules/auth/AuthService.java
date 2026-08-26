package com.trabajito.modules.auth;

import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.auth.dto.AuthResponse;
import com.trabajito.modules.auth.dto.LoginRequest;
import com.trabajito.modules.auth.dto.RegistroRequest;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import com.trabajito.modules.usuarios.dto.UsuarioResponse;
import com.trabajito.security.JwtService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Registro y autenticación de usuarios. */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final UsuarioRepository usuarios;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;

    public AuthService(UsuarioRepository usuarios,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService,
                       AuthenticationManager authenticationManager) {
        this.usuarios = usuarios;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.authenticationManager = authenticationManager;
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

    public AuthResponse login(LoginRequest req) {
        String correo = req.correo().toLowerCase().trim();
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
            throw e;
        } catch (AuthenticationException e) {
            log.info("Login fallido para {}: {}", correo, e.getClass().getSimpleName());
            throw e;
        }

        Usuario u = usuarios.findByCorreo(correo)
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        return construirRespuesta(u);
    }

    private AuthResponse construirRespuesta(Usuario u) {
        String token = jwtService.generarToken(
                u.getId().toString(), u.getCorreo(), u.getRol().name());
        return new AuthResponse(token, UsuarioResponse.de(u));
    }
}
