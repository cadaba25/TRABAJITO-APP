package com.trabajito.modules.auth;

import com.trabajito.common.enums.Rol;
import com.trabajito.common.exception.ApiException;
import com.trabajito.common.exception.IntentosExcedidosException;
import com.trabajito.modules.auth.dto.AuthResponse;
import com.trabajito.modules.auth.dto.LoginRequest;
import com.trabajito.modules.auth.dto.RegistroRequest;
import com.trabajito.modules.auth.dto.RolPublico;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import com.trabajito.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Tests unitarios de {@link AuthService} (registro/login), con mocks para no
 * depender de una base de datos real. Se usa un {@link PasswordEncoder} y un
 * {@link JwtService} reales (no mockeados) porque son objetos simples de
 * construir sin dependencias externas y probar el flujo con hashing/firma
 * real da más confianza que mockear su comportamiento.
 */
@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    private static final String IP = "203.0.113.7";

    @Mock
    UsuarioRepository usuarios;

    @Mock
    AuthenticationManager authenticationManager;

    @Mock
    ControlFuerzaBruta controlFuerzaBruta;

    @Mock
    RefreshTokenService refreshTokens;

    PasswordEncoder passwordEncoder;
    JwtService jwtService;
    AuthService authService;

    @BeforeEach
    void setUp() {
        passwordEncoder = new BCryptPasswordEncoder();
        jwtService = new JwtService(
                "secreto-de-pruebas-no-usar-en-produccion-1234567890", 3_600_000L);
        authService = new AuthService(usuarios, passwordEncoder, jwtService,
                authenticationManager, controlFuerzaBruta, refreshTokens);

        // Simula el comportamiento real de JPA: al guardar, la entidad recibe
        // un id generado. Sin esto, AuthService.construirRespuesta() explota
        // con NullPointerException al llamar u.getId().toString(), porque un
        // mock de JpaRepository#save() no muta ni asigna id por defecto.
        lenient().when(usuarios.save(any(Usuario.class))).thenAnswer(inv -> {
            Usuario u = inv.getArgument(0);
            if (u.getId() == null) {
                u.setId(UUID.randomUUID());
            }
            return u;
        });
    }

    private RegistroRequest registroValido() {
        return new RegistroRequest(
                "Nuevo.Usuario@Correo.com ".trim(), "contrasena123",
                "Nuevo", "Usuario", "0801199912345", "99998888",
                RolPublico.TRABAJADOR, "Francisco Morazán", "Tegucigalpa");
    }

    @Test
    void registrar_creaUsuarioYDevuelveTokenValido() {
        when(usuarios.existsByCorreo(any())).thenReturn(false);

        AuthResponse resp = authService.registrar(registroValido());

        assertThat(resp.token()).isNotBlank();
        assertThat(resp.usuario().correo()).isEqualTo("nuevo.usuario@correo.com");
        assertThat(resp.usuario().rol()).isEqualTo(Rol.TRABAJADOR);
        // El token debe traer el id del usuario recién creado como subject.
        assertThat(jwtService.extraerUsuarioId(resp.token()))
                .isEqualTo(resp.usuario().id().toString());

        ArgumentCaptor<Usuario> captor = ArgumentCaptor.forClass(Usuario.class);
        verify(usuarios).save(captor.capture());
        // La contraseña nunca se guarda en texto plano; se guarda su hash.
        assertThat(captor.getValue().getPasswordHash()).isNotEqualTo("contrasena123");
        assertThat(passwordEncoder.matches("contrasena123", captor.getValue().getPasswordHash()))
                .isTrue();
    }

    @Test
    void registrar_correoDuplicado_lanzaConflicto() {
        when(usuarios.existsByCorreo("nuevo.usuario@correo.com")).thenReturn(true);

        assertThatThrownBy(() -> authService.registrar(registroValido()))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.CONFLICT);

        // Edge case importante (evita doble-registro / doble-submit): si el
        // correo ya existe, NUNCA debe llegar a guardar nada.
        verify(usuarios, never()).save(any());
    }

    @Test
    void login_credencialesValidas_devuelveTokenDelUsuarioEncontrado() {
        Usuario existente = Usuario.builder()
                .correo("trabajador@trabajito.test")
                .passwordHash(passwordEncoder.encode("claveSegura1"))
                .nombres("Ana")
                .apellidos("Pérez")
                .rol(Rol.TRABAJADOR)
                .build();
        // `id` vive en BaseEntity: al usar @Builder (no @SuperBuilder) en
        // Usuario, el builder no expone campos heredados, así que se asigna
        // aparte con el setter (igual que lo haría Hibernate al persistir).
        existente.setId(UUID.randomUUID());
        when(usuarios.findByCorreo("trabajador@trabajito.test"))
                .thenReturn(Optional.of(existente));

        AuthResponse resp = authService.login(
                new LoginRequest("trabajador@trabajito.test", "claveSegura1"), IP);

        assertThat(resp.usuario().id()).isEqualTo(existente.getId());
        verify(authenticationManager).authenticate(
                new UsernamePasswordAuthenticationToken(
                        "trabajador@trabajito.test", "claveSegura1"));
    }

    @Test
    void login_credencialesInvalidas_propagaExcepcionDeSpringSecurity() {
        doThrow(new BadCredentialsException("Credenciales inválidas"))
                .when(authenticationManager)
                .authenticate(any());

        assertThatThrownBy(() -> authService.login(
                new LoginRequest("trabajador@trabajito.test", "claveIncorrecta"), IP))
                .isInstanceOf(BadCredentialsException.class);

        // No debería siquiera consultar el repositorio si la autenticación falló.
        verify(usuarios, never()).findByCorreo(any());
    }

    @Test
    void login_autenticacionOkPeroUsuarioYaNoExisteEnBD_lanzaNoEncontrado() {
        // Edge case: la autenticación pasa (Spring Security ya validó
        // contraseña vía UserDetailsService), pero justo después el usuario
        // fue borrado/no está en el repo. No debe explotar con NPE.
        when(usuarios.findByCorreo(eq("fantasma@trabajito.test")))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(
                new LoginRequest("fantasma@trabajito.test", "cualquierClave"), IP))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void registrar_soloPersisteRolesNoAdministrativos() {
        // Tarea 008 / ADR-0005: el rol que se persiste sale de RolPublico, que
        // no incluye ADMIN. Se recorren TODOS los valores posibles para que
        // este test siga cubriendo el caso si mañana se añade uno nuevo.
        when(usuarios.existsByCorreo(any())).thenReturn(false);

        for (RolPublico rolPedido : RolPublico.values()) {
            RegistroRequest req = new RegistroRequest(
                    rolPedido.name().toLowerCase() + "@trabajito.test", "contrasena123",
                    "Test", "Rol", null, null, rolPedido, null, null);

            AuthResponse resp = authService.registrar(req);

            assertThat(resp.usuario().rol()).isEqualTo(rolPedido.aRol());
            assertThat(resp.usuario().rol()).isNotEqualTo(Rol.ADMIN);
        }
    }

    @Test
    void registrar_normalizaCorreoAMinusculasYSinEspacios() {
        RegistroRequest req = new RegistroRequest(
                "  MAYUS.Culas@Ejemplo.COM  ", "contrasena123",
                "Test", "Normaliza", null, null,
                RolPublico.EMPLEADOR, null, null);
        when(usuarios.existsByCorreo("mayus.culas@ejemplo.com")).thenReturn(false);

        AuthResponse resp = authService.registrar(req);

        assertThat(resp.usuario().correo()).isEqualTo("mayus.culas@ejemplo.com");
    }

    // ── Freno de fuerza bruta (tarea 015, ADR-0010) ──────────────────

    @Test
    void login_conLaIpPasada_deCupo_niSiquieraComprubaLaContrasena() {
        // El tope por IP corta ANTES de BCrypt: es lo que evita que un
        // atacante queme CPU del servidor a base de intentos.
        doThrow(new IntentosExcedidosException("Demasiados intentos", 900))
                .when(controlFuerzaBruta).exigirCupoDeIp(IP);

        assertThatThrownBy(() -> authService.login(
                new LoginRequest("victima@trabajito.test", "loQueSea"), IP))
                .isInstanceOf(IntentosExcedidosException.class);

        verify(authenticationManager, never()).authenticate(any());
    }

    @Test
    void login_fallido_seRegistraElIntento() {
        doThrow(new BadCredentialsException("mal")).when(authenticationManager).authenticate(any());

        assertThatThrownBy(() -> authService.login(
                new LoginRequest("victima@trabajito.test", "malaClave"), IP))
                .isInstanceOf(BadCredentialsException.class);

        verify(controlFuerzaBruta).registrarFallo("victima@trabajito.test", IP);
    }

    @Test
    void login_fallido_conLaCuentaYaConFriccion_responde429EnVezDe401() {
        doThrow(new BadCredentialsException("mal")).when(authenticationManager).authenticate(any());
        when(controlFuerzaBruta.cuentaConFriccion("victima@trabajito.test")).thenReturn(true);

        assertThatThrownBy(() -> authService.login(
                new LoginRequest("victima@trabajito.test", "malaClave"), IP))
                .isInstanceOf(IntentosExcedidosException.class)
                .extracting(e -> ((ApiException) e).getStatus())
                .isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
    }

    @Test
    void login_conContrasenaCORRECTA_entraAunqueLaCuentaEsteBajoAtaque() {
        // EL test que justifica el diseño (ADR-0010): un atacante que acumule
        // fallos contra la cuenta de otro NO puede dejar fuera a su dueño,
        // porque la contraseña correcta nunca se rechaza. Si algún día alguien
        // convierte esto en un bloqueo de cuenta, este test se pone rojo.
        lenient().when(controlFuerzaBruta.cuentaConFriccion(any())).thenReturn(true);
        Usuario existente = Usuario.builder()
                .correo("victima@trabajito.test")
                .passwordHash(passwordEncoder.encode("claveBuena123"))
                .nombres("Vic").apellidos("Tima").rol(Rol.TRABAJADOR).build();
        existente.setId(UUID.randomUUID());
        when(usuarios.findByCorreo("victima@trabajito.test"))
                .thenReturn(Optional.of(existente));

        AuthResponse resp = authService.login(
                new LoginRequest("victima@trabajito.test", "claveBuena123"), IP);

        assertThat(resp.token()).isNotBlank();
        // Y el login correcto limpia el contador de la cuenta.
        verify(controlFuerzaBruta).registrarExito("victima@trabajito.test", IP);
    }
}
