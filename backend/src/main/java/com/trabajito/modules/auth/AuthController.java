package com.trabajito.modules.auth;

import com.trabajito.modules.auth.dto.AuthResponse;
import com.trabajito.modules.auth.dto.LoginRequest;
import com.trabajito.modules.auth.dto.RefreshRequest;
import com.trabajito.modules.auth.dto.RegistroRequest;
import com.trabajito.modules.usuarios.dto.UsuarioResponse;
import com.trabajito.security.SecurityUtils;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final IpDelCliente ipDelCliente;

    public AuthController(AuthService authService, IpDelCliente ipDelCliente) {
        this.authService = authService;
        this.ipDelCliente = ipDelCliente;
    }

    @PostMapping("/registro")
    public AuthResponse registro(@Valid @RequestBody RegistroRequest req) {
        return authService.registrar(req);
    }

    /**
     * Login. La IP se resuelve aqui (capa HTTP) y se pasa al servicio, en vez
     * de que el servicio vaya a buscarla a un ThreadLocal: asi AuthService
     * sigue siendo testeable sin servlet.
     */
    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest req, HttpServletRequest http) {
        return authService.login(req, ipDelCliente.de(http));
    }

    /**
     * Renueva el token de acceso a partir del refresh token (ADR-0010).
     * Rota el refresh: el presentado queda revocado y se devuelve otro nuevo.
     */
    @PostMapping("/refresh")
    public AuthResponse refresh(@Valid @RequestBody RefreshRequest req) {
        return authService.refrescar(req.refreshToken());
    }

    /**
     * Cierra la sesion revocando el refresh token. Responde 204 siempre que el
     * cuerpo sea valido (tambien si el token ya no existia): un logout no debe
     * servir para averiguar que tokens son validos.
     */
    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest req) {
        authService.logout(req.refreshToken());
    }

    /** Devuelve el usuario autenticado (para validar el token al abrir la app). */
    @GetMapping("/yo")
    public UsuarioResponse yo() {
        return UsuarioResponse.de(SecurityUtils.usuarioActual());
    }
}
