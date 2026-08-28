package com.trabajito.modules.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * Tarea 015 (ADR-0010) — login exigente, a nivel HTTP.
 *
 * <p>Cubre las tres piezas: freno de fuerza bruta, refresh token rotativo y
 * cierre de sesion real. Levanta el contexto completo contra H2 (sin Docker),
 * igual que {@code MapeoErroresHttpTest}.
 *
 * <p><b>Cada test usa su propia IP y su propio correo.</b> La BD H2 se comparte
 * entre clases dentro del mismo JVM, y los contadores del freno son
 * acumulativos: sin aislar la IP, un test agotaria el cupo de otro.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class LoginExigenteHttpTest {

    private static final String PASSWORD = "Prueba1234";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private UsuarioRepository usuarios;

    private final ObjectMapper json = new ObjectMapper();

    private String correo;

    @BeforeEach
    void nuevoCorreo() {
        correo = "exigente." + System.nanoTime() + "@trabajito.local";
    }

    // ── helpers ──────────────────────────────────────────────────────
    private MvcResult registrar(String correo, String password, String ip) throws Exception {
        return mvc.perform(desde(post("/api/auth/registro"), ip)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"correo":"%s","password":"%s","nombres":"Ex",
                         "apellidos":"Igente","rol":"TRABAJADOR"}
                        """.formatted(correo, password)))
                .andReturn();
    }

    private MvcResult login(String correo, String password, String ip) throws Exception {
        return mvc.perform(desde(post("/api/auth/login"), ip)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"correo\":\"%s\",\"password\":\"%s\"}".formatted(correo, password)))
                .andReturn();
    }

    /** Fija la IP de origen de la peticion simulada. */
    private MockHttpServletRequestBuilder desde(MockHttpServletRequestBuilder b, String ip) {
        return b.with(req -> {
            req.setRemoteAddr(ip);
            return req;
        });
    }

    private JsonNode cuerpo(MvcResult r) throws Exception {
        return json.readTree(r.getResponse().getContentAsString());
    }

    // ── 1. Freno de fuerza bruta ─────────────────────────────────────

    @Test
    @DisplayName("tras 5 fallos seguidos la cuenta responde 429, no 401 (antes: 401 indefinidos)")
    void fuerzaBrutaContraUnaCuenta_acabaEn429() throws Exception {
        String ip = "198.51.100.10";
        assertThat(registrar(correo, PASSWORD, ip).getResponse().getStatus()).isEqualTo(200);

        // Los primeros 5 fallos responden 401 (comportamiento normal).
        for (int i = 1; i <= 5; i++) {
            assertThat(login(correo, "malaClave" + i, ip).getResponse().getStatus())
                    .as("intento fallido n.º %d", i)
                    .isEqualTo(401);
        }
        // El 6.º ya no responde "como si nada": 429 + Retry-After.
        MvcResult sexto = login(correo, "malaClave6", ip);
        assertThat(sexto.getResponse().getStatus()).isEqualTo(429);
        assertThat(sexto.getResponse().getHeader("Retry-After")).isNotBlank();
        assertThat(cuerpo(sexto).get("message").asText()).contains("Demasiados intentos");
    }

    @Test
    @DisplayName("un usuario legítimo entra con su contraseña aunque un atacante haya quemado la cuenta")
    void cuentaBajoAtaque_elDuenoSigueEntrando() throws Exception {
        String ipAtacante = "198.51.100.20";
        String ipDelDueno = "198.51.100.21";
        assertThat(registrar(correo, PASSWORD, ipAtacante).getResponse().getStatus()).isEqualTo(200);

        // El atacante quema el cupo de la cuenta (10 fallos, el doble del tope).
        for (int i = 1; i <= 10; i++) {
            login(correo, "ataque" + i, ipAtacante);
        }
        // La cuenta está "con fricción": un fallo más responde 429.
        assertThat(login(correo, "ataque11", ipAtacante).getResponse().getStatus()).isEqualTo(429);

        // ...y aun así el dueño entra con su contraseña correcta. Esto es lo
        // que impide usar el freno como denegación de servicio contra una
        // persona concreta (ADR-0010).
        MvcResult ok = login(correo, PASSWORD, ipDelDueno);
        assertThat(ok.getResponse().getStatus()).isEqualTo(200);
        assertThat(cuerpo(ok).get("token").asText()).isNotBlank();

        // Y tras el login correcto, la cuenta queda limpia: vuelve a dar 401
        // (no 429), porque el contador de fallos se reinició.
        assertThat(login(correo, "otraMala", ipDelDueno).getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    @DisplayName("el tope por IP corta aunque el atacante cambie de cuenta en cada intento")
    void fuerzaBrutaRotandoCuentas_topePorIp() throws Exception {
        String ip = "198.51.100.30";
        int ultimoCodigo = 0;
        // 21 intentos contra 21 correos distintos: el freno por cuenta nunca
        // salta (1 fallo por cuenta), pero el de IP sí.
        for (int i = 1; i <= 21; i++) {
            ultimoCodigo = login("inexistente" + i + "@trabajito.local", "loQueSea", ip)
                    .getResponse().getStatus();
        }
        assertThat(ultimoCodigo).isEqualTo(429);
    }

    // ── 2. Refresh token ─────────────────────────────────────────────

    @Test
    @DisplayName("el login devuelve refreshToken y el access token es corto, no de 7 días")
    void loginDevuelveParDeTokens() throws Exception {
        String ip = "198.51.100.40";
        JsonNode r = cuerpo(registrar(correo, PASSWORD, ip));

        assertThat(r.get("token").asText()).isNotBlank();
        assertThat(r.get("refreshToken").asText()).isNotBlank();
        assertThat(r.get("tokenType").asText()).isEqualTo("Bearer");
        // 7 días eran 604800 s. Lo que se emite ahora tiene que ser mucho menos.
        assertThat(r.get("expiraEnSegundos").asLong()).isLessThanOrEqualTo(3600);
    }

    @Test
    @DisplayName("el refresh token se cambia por un par nuevo y el viejo deja de valer (rotación)")
    void refreshRota() throws Exception {
        String ip = "198.51.100.50";
        String refreshViejo = cuerpo(registrar(correo, PASSWORD, ip)).get("refreshToken").asText();

        MvcResult r1 = refrescar(refreshViejo, ip);
        assertThat(r1.getResponse().getStatus()).isEqualTo(200);
        String refreshNuevo = cuerpo(r1).get("refreshToken").asText();
        assertThat(refreshNuevo).isNotEqualTo(refreshViejo);
        // El token de acceso nuevo sirve de verdad.
        assertThat(usarToken(cuerpo(r1).get("token").asText()).getResponse().getStatus())
                .isEqualTo(200);

        // Reutilizar el viejo (rotado) es señal de robo: 401.
        assertThat(refrescar(refreshViejo, ip).getResponse().getStatus()).isEqualTo(401);
        // Y la detección de reutilización tumba TODA la familia: el nuevo
        // tampoco vale ya.
        assertThat(refrescar(refreshNuevo, ip).getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    @DisplayName("un refresh token inventado responde 401, no 404 ni 500")
    void refreshInventado() throws Exception {
        assertThat(refrescar("no-existe-este-token", "198.51.100.60")
                .getResponse().getStatus()).isEqualTo(401);
    }

    // ── 3. Cerrar sesión de verdad ───────────────────────────────────

    @Test
    @DisplayName("logout revoca la sesión: el refresh token deja de servir (antes era imposible)")
    void logoutInvalidaLaSesion() throws Exception {
        String ip = "198.51.100.70";
        JsonNode r = cuerpo(registrar(correo, PASSWORD, ip));
        String refresh = r.get("refreshToken").asText();

        MvcResult salida = mvc.perform(desde(post("/api/auth/logout"), ip)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"%s\"}".formatted(refresh)))
                .andReturn();
        assertThat(salida.getResponse().getStatus()).isEqualTo(204);

        // El refresh revocado ya no renueva nada: la sesión murió.
        assertThat(refrescar(refresh, ip).getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    @DisplayName("una cuenta suspendida no puede renovar su sesión con el refresh token")
    void cuentaSuspendidaNoRenueva() throws Exception {
        String ip = "198.51.100.80";
        String refresh = cuerpo(registrar(correo, PASSWORD, ip)).get("refreshToken").asText();

        Usuario u = usuarios.findByCorreo(correo).orElseThrow();
        u.setActivo(false);
        usuarios.save(u);

        assertThat(refrescar(refresh, ip).getResponse().getStatus()).isEqualTo(401);
    }

    private MvcResult refrescar(String refreshToken, String ip) throws Exception {
        return mvc.perform(desde(post("/api/auth/refresh"), ip)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"%s\"}".formatted(refreshToken)))
                .andReturn();
    }

    private MvcResult usarToken(String accessToken) throws Exception {
        return mvc.perform(get("/api/auth/yo").header("Authorization", "Bearer " + accessToken))
                .andReturn();
    }

    // ── 4. Política de contraseñas ───────────────────────────────────

    @Test
    @DisplayName("el registro rechaza contraseñas de menos de 10 caracteres, solo dígitos o de lista común")
    void politicaDeContrasenas() throws Exception {
        String ip = "198.51.100.90";
        // 9 caracteres: por debajo del mínimo nuevo (antes bastaban 8).
        assertThat(registrar("corta." + System.nanoTime() + "@t.local", "Abcdefgh1", ip)
                .getResponse().getStatus()).isEqualTo(400);
        // Solo dígitos: un teléfono o una fecha se adivinan enseguida.
        assertThat(registrar("digitos." + System.nanoTime() + "@t.local", "9988776655", ip)
                .getResponse().getStatus()).isEqualTo(400);
        // Lista de bloqueo.
        assertThat(registrar("comun." + System.nanoTime() + "@t.local", "contrasena", ip)
                .getResponse().getStatus()).isEqualTo(400);
        // El mismo carácter repetido.
        assertThat(registrar("repe." + System.nanoTime() + "@t.local", "aaaaaaaaaaaa", ip)
                .getResponse().getStatus()).isEqualTo(400);
        // Una razonable sí entra.
        assertThat(registrar("buena." + System.nanoTime() + "@t.local", "MiClaveDeTrabajo7", ip)
                .getResponse().getStatus()).isEqualTo(200);
    }

    @Test
    @DisplayName("el error de contraseña débil dice qué falla, en español y en 'fields'")
    void mensajeDePoliticaEnEspanol() throws Exception {
        MvcResult r = registrar("mensaje." + System.nanoTime() + "@t.local", "corta1", "198.51.100.91");

        assertThat(r.getResponse().getStatus()).isEqualTo(400);
        assertThat(cuerpo(r).get("fields").get("password").asText())
                .contains("al menos 10 caracteres");
    }
}
