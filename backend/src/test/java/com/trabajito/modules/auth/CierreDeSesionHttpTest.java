package com.trabajito.modules.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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
 * Tarea 024 (ADR-0012) — cerrar sesión revoca la FAMILIA de refresh tokens,
 * no solo la fila presentada.
 *
 * <p>El fallo que motiva estos tests es real, no hipotético: lo reprodujo la
 * revisión de QA de la tarea 022 en un emulador. Cerrar sesión mientras había
 * una renovación en vuelo dejaba en el dispositivo un par de tokens recién
 * rotado <b>que el servidor seguía aceptando</b>, y al siguiente arranque la
 * app entraba sola en una sesión que el usuario creía cerrada.
 *
 * <p>Los dos primeros tests fallan con el código anterior
 * ({@code RefreshTokenService.revocar}, que marcaba una sola fila).
 *
 * <p>MockMvc + H2, sin Docker, igual que {@link LoginExigenteHttpTest}. Cada
 * test usa su propio correo y su propia IP: la BD H2 se comparte entre clases
 * del mismo JVM y los contadores del freno de fuerza bruta son acumulativos.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class CierreDeSesionHttpTest {

    private static final String PASSWORD = "CierroSesion7";

    @Autowired
    private MockMvc mvc;

    private final ObjectMapper json = new ObjectMapper();

    // ── 1. El fallo de fondo: la renovación en vuelo ─────────────────

    @Test
    @DisplayName("logout revoca TODA la familia: el token rotado mientras se cerraba sesión tampoco vale")
    void logoutRevocaLaFamiliaEntera() throws Exception {
        String ip = "203.0.113.10";
        String refreshViejo = refreshDe(registrar(nuevoCorreo(), ip));

        // Renovación "en vuelo": el cliente ya tiene un par nuevo (misma familia)...
        String refreshNuevo = refreshDe(refrescar(refreshViejo, ip));
        assertThat(refreshNuevo).isNotEqualTo(refreshViejo);

        // ...pero el logout sale con el token viejo, que es el que el cliente
        // tenía guardado cuando el usuario pulsó "cerrar sesión".
        assertThat(logout(refreshViejo, ip).getResponse().getStatus()).isEqualTo(204);

        // Antes de la tarea 024 esto respondía 200: la sesión seguía viva y la
        // app entraba sola al siguiente arranque.
        assertThat(refrescar(refreshNuevo, ip).getResponse().getStatus())
                .as("el token rotado durante el logout debe morir con la familia")
                .isEqualTo(401);
        assertThat(refrescar(refreshViejo, ip).getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    @DisplayName("logout mata la familia aunque el token presentado ya estuviera rotado dos veces")
    void logoutConTokenYaRotadoVariasVeces() throws Exception {
        String ip = "203.0.113.11";
        String r0 = refreshDe(registrar(nuevoCorreo(), ip));
        String r1 = refreshDe(refrescar(r0, ip));
        String r2 = refreshDe(refrescar(r1, ip));

        assertThat(logout(r0, ip).getResponse().getStatus()).isEqualTo(204);
        assertThat(refrescar(r2, ip).getResponse().getStatus()).isEqualTo(401);
    }

    // ── 2. Un dispositivo no arrastra a los demás ────────────────────

    @Test
    @DisplayName("cerrar sesión en un dispositivo NO cierra la sesión del otro (familias distintas)")
    void cerrarSesionEnUnDispositivoNoCierraElOtro() throws Exception {
        String ip = "203.0.113.20";
        String correo = nuevoCorreo();
        registrar(correo, ip);

        String movil = refreshDe(login(correo, PASSWORD, ip));
        String tablet = refreshDe(login(correo, PASSWORD, ip));
        assertThat(movil).isNotEqualTo(tablet);

        assertThat(logout(movil, ip).getResponse().getStatus()).isEqualTo(204);

        assertThat(refrescar(movil, ip).getResponse().getStatus()).isEqualTo(401);
        assertThat(refrescar(tablet, ip).getResponse().getStatus())
                .as("cerrar sesión en el móvil no puede cerrarla en la tablet")
                .isEqualTo(200);
    }

    // ── 3. Cerrar sesión en todos los dispositivos ───────────────────

    @Test
    @DisplayName("logout-todos cierra todas las sesiones del usuario y ninguna de otro usuario")
    void logoutDeTodosLosDispositivos() throws Exception {
        String ip = "203.0.113.30";
        String correo = nuevoCorreo();
        registrar(correo, ip);
        String movil = refreshDe(login(correo, PASSWORD, ip));
        MvcResult sesionTablet = login(correo, PASSWORD, ip);
        String tablet = refreshDe(sesionTablet);
        String accesoTablet = cuerpo(sesionTablet).get("token").asText();

        // Otro usuario, para comprobar que la revocación no se lleva por
        // delante sesiones ajenas.
        String ajeno = refreshDe(registrar(nuevoCorreo(), ip));

        MvcResult salida = mvc.perform(post("/api/auth/logout-todos")
                        .header("Authorization", "Bearer " + accesoTablet))
                .andReturn();
        assertThat(salida.getResponse().getStatus()).isEqualTo(204);

        assertThat(refrescar(movil, ip).getResponse().getStatus()).isEqualTo(401);
        assertThat(refrescar(tablet, ip).getResponse().getStatus())
                .as("incluye la sesión desde la que se pidió")
                .isEqualTo(401);
        assertThat(refrescar(ajeno, ip).getResponse().getStatus())
                .as("la sesión de otro usuario no se toca")
                .isEqualTo(200);
    }

    @Test
    @DisplayName("logout-todos sin token de acceso responde 401 (no es un endpoint público)")
    void logoutDeTodosExigeTokenDeAcceso() throws Exception {
        String ip = "203.0.113.40";
        String refresh = refreshDe(registrar(nuevoCorreo(), ip));

        assertThat(mvc.perform(post("/api/auth/logout-todos")).andReturn().getResponse().getStatus())
                .isEqualTo(401);
        assertThat(mvc.perform(post("/api/auth/logout-todos")
                        .header("Authorization", "Bearer no-es-un-jwt"))
                .andReturn().getResponse().getStatus()).isEqualTo(401);

        // Y la sesión sigue viva: el 401 no revocó nada.
        assertThat(refrescar(refresh, ip).getResponse().getStatus()).isEqualTo(200);
    }

    // ── 4. El logout sigue sin ser un oráculo de tokens ──────────────

    @Test
    @DisplayName("logout de un token inventado responde 204, no 401 ni 404")
    void logoutDeTokenInventado() throws Exception {
        assertThat(logout("token-que-no-existe", "203.0.113.50").getResponse().getStatus())
                .isEqualTo(204);
    }

    @Test
    @DisplayName("logout repetido es idempotente: sigue respondiendo 204")
    void logoutRepetido() throws Exception {
        String ip = "203.0.113.51";
        String refresh = refreshDe(registrar(nuevoCorreo(), ip));

        assertThat(logout(refresh, ip).getResponse().getStatus()).isEqualTo(204);
        assertThat(logout(refresh, ip).getResponse().getStatus()).isEqualTo(204);
    }

    @Test
    @DisplayName("tras logout el token de acceso ya emitido sigue valiendo hasta que caduca (límite asumido)")
    void elAccessTokenSobreviveAlLogout() throws Exception {
        String ip = "203.0.113.60";
        MvcResult alta = registrar(nuevoCorreo(), ip);
        String acceso = cuerpo(alta).get("token").asText();

        assertThat(logout(refreshDe(alta), ip).getResponse().getStatus()).isEqualTo(204);

        // Documenta la decisión de ADR-0010 (sin lista negra de JWT): la
        // revocación vive en el refresh; el access muere solo, en <=15 min.
        assertThat(mvc.perform(get("/api/auth/yo").header("Authorization", "Bearer " + acceso))
                .andReturn().getResponse().getStatus()).isEqualTo(200);
    }

    // ── helpers ──────────────────────────────────────────────────────

    private String nuevoCorreo() {
        return "cierre." + System.nanoTime() + "@trabajito.local";
    }

    private MvcResult registrar(String correo, String ip) throws Exception {
        MvcResult r = mvc.perform(desde(post("/api/auth/registro"), ip)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"correo":"%s","password":"%s","nombres":"Cie",
                         "apellidos":"Rre","rol":"TRABAJADOR"}
                        """.formatted(correo, PASSWORD)))
                .andReturn();
        assertThat(r.getResponse().getStatus()).isEqualTo(200);
        return r;
    }

    private MvcResult login(String correo, String password, String ip) throws Exception {
        MvcResult r = mvc.perform(desde(post("/api/auth/login"), ip)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"correo\":\"%s\",\"password\":\"%s\"}".formatted(correo, password)))
                .andReturn();
        assertThat(r.getResponse().getStatus()).isEqualTo(200);
        return r;
    }

    private MvcResult refrescar(String refreshToken, String ip) throws Exception {
        return mvc.perform(desde(post("/api/auth/refresh"), ip)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"%s\"}".formatted(refreshToken)))
                .andReturn();
    }

    private MvcResult logout(String refreshToken, String ip) throws Exception {
        return mvc.perform(desde(post("/api/auth/logout"), ip)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"%s\"}".formatted(refreshToken)))
                .andReturn();
    }

    private String refreshDe(MvcResult r) throws Exception {
        return cuerpo(r).get("refreshToken").asText();
    }

    private JsonNode cuerpo(MvcResult r) throws Exception {
        return json.readTree(r.getResponse().getContentAsString());
    }

    /** Fija la IP de origen de la petición simulada. */
    private MockHttpServletRequestBuilder desde(MockHttpServletRequestBuilder b, String ip) {
        return b.with(req -> {
            req.setRemoteAddr(ip);
            return req;
        });
    }
}
