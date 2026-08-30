package com.trabajito.modules.auth;

import com.trabajito.modules.auth.dto.AuthResponse;
import com.trabajito.modules.auth.dto.LoginRequest;
import com.trabajito.modules.auth.dto.RefreshRequest;
import com.trabajito.modules.auth.dto.RegistroRequest;
import com.trabajito.modules.usuarios.UsuarioService;
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
    private final UsuarioService usuarioService;

    public AuthController(AuthService authService, IpDelCliente ipDelCliente,
                          UsuarioService usuarioService) {
        this.authService = authService;
        this.ipDelCliente = ipDelCliente;
        this.usuarioService = usuarioService;
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
     * Cierra la sesion de ESTE dispositivo. Revoca la familia entera de refresh
     * tokens a la que pertenece el presentado, no solo esa fila (tarea 024,
     * ADR-0012): si no, un token recien rotado por una renovacion en vuelo
     * sobrevivia al logout y la sesion seguia utilizable.
     *
     * <p>Responde 204 siempre que el cuerpo sea valido (tambien si el token ya
     * no existia): un logout no debe servir para averiguar que tokens son
     * validos. No requiere token de acceso: el refresh token que se presenta ya
     * es la credencial, y quien cierra sesion suele tener el acceso caducado.
     */
    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest req) {
        authService.logout(req.refreshToken());
    }

    /**
     * Cierra la sesion en TODOS los dispositivos del usuario, incluido este
     * (tarea 024, ADR-0012). Es la accion que uno busca al sospechar que le
     * robaron la cuenta.
     *
     * <p>A diferencia de {@code /logout}, exige <b>token de acceso valido</b>
     * (ver {@code SecurityConfig}): es una accion destructiva sobre todas las
     * sesiones, asi que la pide quien demuestra tener la cuenta ahora mismo, no
     * quien tenga suelto un refresh token viejo. Tras esta llamada el cliente
     * debe borrar su sesion local: su propio refresh acaba de morir.
     */
    @PostMapping("/logout-todos")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logoutDeTodosLosDispositivos() {
        authService.logoutDeTodosLosDispositivos(SecurityUtils.idActual());
    }

    /**
     * Devuelve el usuario autenticado (para validar el token al abrir la app).
     *
     * <p>Desde la tarea 019 devuelve el perfil COMPLETO -con habilidades,
     * experiencia y estudios-: es la llamada con la que la app rehidrata la
     * sesion al arrancar, asi que es donde le sale mas barato traerse el CV.
     * El login y el registro siguen devolviendo la version sin listas.
     */
    @GetMapping("/yo")
    public UsuarioResponse yo() {
        return usuarioService.perfilPropio(SecurityUtils.idActual());
    }
}
