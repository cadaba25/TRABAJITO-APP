package com.trabajito.modules.auth;

import com.trabajito.modules.auth.dto.AuthResponse;
import com.trabajito.modules.auth.dto.LoginRequest;
import com.trabajito.modules.auth.dto.RegistroRequest;
import com.trabajito.modules.usuarios.dto.UsuarioResponse;
import com.trabajito.security.SecurityUtils;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/registro")
    public AuthResponse registro(@Valid @RequestBody RegistroRequest req) {
        return authService.registrar(req);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }

    /** Devuelve el usuario autenticado (para validar el token al abrir la app). */
    @GetMapping("/yo")
    public UsuarioResponse yo() {
        return UsuarioResponse.de(SecurityUtils.usuarioActual());
    }
}
