package com.trabajito.common.exception;

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

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * Tarea 009 — mapeo de errores HTTP. Cada caso de esta clase devolvia
 * <b>500 "Error interno del servidor"</b> antes del arreglo.
 *
 * <p>Es el primer test de la capa HTTP del backend (hasta ahora todos los
 * tests eran unitarios con Mockito, sin servidor ni cadena de filtros, y por
 * eso no detectaron nada de esto). Levanta el contexto completo contra H2 en
 * memoria — igual que {@code TrabajitoApplicationTests}, sin Docker — y pega
 * a la API con MockMvc, con la cadena de Spring Security puesta.
 *
 * <p>No sustituye a {@code backend/scripts/prueba-flujo-negocio.sh}: ese
 * corre contra PostgreSQL real. Este solo cubre el mapeo de codigos.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MapeoErroresHttpTest {

    private static final String PASSWORD = "Prueba1234";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private UsuarioRepository usuarios;

    private final ObjectMapper json = new ObjectMapper();

    private String token;
    private String correo;

    @BeforeEach
    void registrarUsuario() throws Exception {
        correo = "errores." + System.nanoTime() + "@trabajito.local";
        MvcResult r = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"correo":"%s","password":"%s","nombres":"Error",
                                 "apellidos":"Prueba","rol":"TRABAJADOR"}
                                """.formatted(correo, PASSWORD)))
                .andReturn();
        assertThat(r.getResponse().getStatus()).isEqualTo(200);
        token = cuerpo(r).get("token").asText();
    }

    // ── Autenticacion ────────────────────────────────────────────────
    @Test
    @DisplayName("sin token, un endpoint protegido responde 401 con cuerpo JSON (antes: 403 vacio)")
    void sinToken_da401() throws Exception {
        MvcResult r = mvc.perform(post("/api/cartera/recargar")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"monto\":100}"))
                .andReturn();

        assertThat(r.getResponse().getStatus()).isEqualTo(401);
        assertThat(cuerpo(r).get("message").asText()).isNotBlank();
        assertThat(cuerpo(r).get("status").asInt()).isEqualTo(401);
    }

    @Test
    @DisplayName("una cuenta suspendida responde 401 con el MISMO mensaje que una contraseña mala")
    void cuentaSuspendida_noSeDistingueDeContrasenaMala() throws Exception {
        MvcResult malaPassword = login(correo, "otra-cosa-1234");

        Usuario u = usuarios.findByCorreo(correo).orElseThrow();
        u.setActivo(false);
        usuarios.save(u);

        MvcResult suspendida = login(correo, PASSWORD);

        assertThat(suspendida.getResponse().getStatus()).isEqualTo(401);
        assertThat(malaPassword.getResponse().getStatus()).isEqualTo(401);
        // La fuga que cerramos: antes esto era 500 vs 401, asi que desde un
        // endpoint publico se podia saber que cuentas estaban suspendidas.
        assertThat(cuerpo(suspendida).get("message").asText())
                .isEqualTo(cuerpo(malaPassword).get("message").asText());
    }

    // ── Protocolo HTTP ───────────────────────────────────────────────
    @Test
    @DisplayName("una ruta que no existe responde 404")
    void rutaInexistente_da404() throws Exception {
        assertThat(conToken(get("/api/no-existe")).getResponse().getStatus()).isEqualTo(404);
    }

    @Test
    @DisplayName("un metodo no permitido responde 405")
    void metodoNoPermitido_da405() throws Exception {
        MvcResult r = conToken(get("/api/cartera/recargar"));
        assertThat(r.getResponse().getStatus()).isEqualTo(405);
        assertThat(r.getResponse().getHeader("Allow")).contains("POST");
    }

    // ── Cuerpo de la peticion ────────────────────────────────────────
    @Test
    @DisplayName("un cuerpo que no es JSON responde 400")
    void jsonMalformado_da400() throws Exception {
        assertThat(recargar("no soy json").getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    @DisplayName("un monto de texto responde 400")
    void montoTexto_da400() throws Exception {
        assertThat(recargar("{\"monto\":\"mil\"}").getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    @DisplayName("un monto ausente responde 400 con el campo en 'fields'")
    void montoAusente_da400() throws Exception {
        MvcResult r = recargar("{}");
        assertThat(r.getResponse().getStatus()).isEqualTo(400);
        assertThat(cuerpo(r).get("fields").has("monto")).isTrue();
    }

    @Test
    @DisplayName("un monto desbordado responde 400")
    void montoDesbordado_da400() throws Exception {
        assertThat(recargar("{\"monto\":99999999999999999999}").getResponse().getStatus())
                .isEqualTo(400);
    }

    @Test
    @DisplayName("un UUID invalido en la ruta responde 400")
    void uuidInvalido_da400() throws Exception {
        assertThat(conToken(get("/api/trabajos/no-es-uuid")).getResponse().getStatus())
                .isEqualTo(400);
    }

    @Test
    @DisplayName("postular sin trabajoId responde 400, no 500")
    void postularSinTrabajoId_da400() throws Exception {
        MvcResult r = conToken(post("/api/postulaciones")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"mensaje\":\"sin id\"}"));
        assertThat(r.getResponse().getStatus()).isEqualTo(400);
        assertThat(cuerpo(r).get("fields").has("trabajoId")).isTrue();
    }

    @Test
    @DisplayName("calificar sin trabajoId responde 400, no 404/500")
    void calificarSinTrabajoId_da400() throws Exception {
        MvcResult r = conToken(post("/api/calificaciones")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"estrellas\":5}"));
        assertThat(r.getResponse().getStatus()).isEqualTo(400);
        assertThat(cuerpo(r).get("fields").has("trabajoId")).isTrue();
    }

    @Test
    @DisplayName("el cuerpo de error mantiene el formato del contrato (ADR-0008)")
    void formatoDelCuerpoDeError() throws Exception {
        JsonNode body = cuerpo(recargar("{}"));
        assertThat(body.has("timestamp")).isTrue();
        assertThat(body.has("status")).isTrue();
        assertThat(body.has("error")).isTrue();
        assertThat(body.has("message")).isTrue();
    }

    // ── helpers ──────────────────────────────────────────────────────
    private MvcResult recargar(String cuerpo) throws Exception {
        return conToken(post("/api/cartera/recargar")
                .contentType(MediaType.APPLICATION_JSON).content(cuerpo));
    }

    private MvcResult login(String correo, String password) throws Exception {
        return mvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"correo\":\"%s\",\"password\":\"%s\"}"
                                .formatted(correo, password)))
                .andReturn();
    }

    private MvcResult conToken(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder b)
            throws Exception {
        return mvc.perform(b.header("Authorization", "Bearer " + token)).andReturn();
    }

    private JsonNode cuerpo(MvcResult r) throws Exception {
        return json.readTree(r.getResponse().getContentAsString());
    }
}
