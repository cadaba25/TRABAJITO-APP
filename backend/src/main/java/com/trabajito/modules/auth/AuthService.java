package com.trabajito.modules.auth;

import com.trabajito.common.exception.ApiException;
import com.trabajito.modules.auth.dto.AuthResponse;
import com.trabajito.modules.auth.dto.LoginRequest;
import com.trabajito.modules.auth.dto.RegistroRequest;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import com.trabajito.modules.usuarios.dto.UsuarioResponse;
import com.trabajito.security.JwtService;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Registro y autenticación de usuarios. */
@Service
public class AuthService {

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
        // Lanza BadCredentialsException (401) si las credenciales no son válidas.
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        req.correo().toLowerCase().trim(), req.password()));

        Usuario u = usuarios.findByCorreo(req.correo().toLowerCase().trim())
                .orElseThrow(() -> ApiException.noEncontrado("Usuario no encontrado"));
        return construirRespuesta(u);
    }

    private AuthResponse construirRespuesta(Usuario u) {
        String token = jwtService.generarToken(
                u.getId().toString(), u.getCorreo(), u.getRol().name());
        return new AuthResponse(token, UsuarioResponse.de(u));
    }
}
