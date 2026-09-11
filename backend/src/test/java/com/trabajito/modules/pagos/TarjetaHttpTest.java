package com.trabajito.modules.pagos;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * Tarea 030 — endpoint mínimo de tarjetas, a nivel HTTP (MockMvc + H2), mismo
 * estilo que {@code PerfilCompletoHttpTest}.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class TarjetaHttpTest {

    private static final String PASSWORD = "Prueba1234";

    @Autowired
    private MockMvc mvc;

    private final ObjectMapper json = new ObjectMapper();

    private String token;

    @BeforeEach
    void registrarme() throws Exception {
        String correo = "tarjetas." + System.nanoTime() + "@trabajito.local";
        token = cuerpo(registrar(correo)).get("token").asText();
    }

    @Test
    @DisplayName("se agrega una tarjeta y aparece en el listado propio, sin el número completo")
    void agregarYListar() throws Exception {
        MvcResult creada = agregarTarjeta("4111111111111111", "Tomás Pérez", "12/28");
        assertThat(creada.getResponse().getStatus()).isEqualTo(201);
        JsonNode t = cuerpo(creada);
        assertThat(t.get("ultimos4").asText()).isEqualTo("1111");
        assertThat(t.get("marca").asText()).isEqualTo("Visa");
        assertThat(t.get("titular").asText()).isEqualTo("Tomás Pérez");
        assertThat(t.get("vencimiento").asText()).isEqualTo("12/28");
        assertThat(t.has("numero")).isFalse();

        MvcResult listado = mvc.perform(get("/api/cartera/tarjetas")
                .header("Authorization", "Bearer " + token)).andReturn();
        assertThat(listado.getResponse().getStatus()).isEqualTo(200);
        JsonNode arr = cuerpo(listado);
        assertThat(arr).hasSize(1);
        assertThat(arr.get(0).get("ultimos4").asText()).isEqualTo("1111");
    }

    @Test
    @DisplayName("el listado propio no muestra tarjetas de otro usuario")
    void listadoSoloPropias() throws Exception {
        agregarTarjeta("4111111111111111", "Yo", "01/30");

        String tokenAjeno = cuerpo(registrar("otro." + System.nanoTime() + "@trabajito.local"))
                .get("token").asText();
        MvcResult listadoAjeno = mvc.perform(get("/api/cartera/tarjetas")
                .header("Authorization", "Bearer " + tokenAjeno)).andReturn();

        assertThat(listadoAjeno.getResponse().getStatus()).isEqualTo(200);
        assertThat(cuerpo(listadoAjeno)).isEmpty();
    }

    @Test
    @DisplayName("un número de menos de 13 dígitos da 400")
    void numeroCortoDa400() throws Exception {
        MvcResult r = agregarTarjeta("4111", "Tomás Pérez", "12/28");
        assertThat(r.getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    @DisplayName("borrar la propia responde 200 y desaparece del listado")
    void borrarPropia() throws Exception {
        String id = cuerpo(agregarTarjeta("5111111111111111", "Yo", "05/27")).get("id").asText();

        MvcResult borrado = mvc.perform(delete("/api/cartera/tarjetas/" + id)
                .header("Authorization", "Bearer " + token)).andReturn();
        assertThat(borrado.getResponse().getStatus()).isEqualTo(200);

        MvcResult listado = mvc.perform(get("/api/cartera/tarjetas")
                .header("Authorization", "Bearer " + token)).andReturn();
        assertThat(cuerpo(listado)).isEmpty();
    }

    @Test
    @DisplayName("borrar una tarjeta ajena responde 404, no 403 (no revela que existe)")
    void borrarAjenaDa404() throws Exception {
        String id = cuerpo(agregarTarjeta("5111111111111111", "Yo", "05/27")).get("id").asText();

        String tokenAjeno = cuerpo(registrar("intruso." + System.nanoTime() + "@trabajito.local"))
                .get("token").asText();
        MvcResult r = mvc.perform(delete("/api/cartera/tarjetas/" + id)
                .header("Authorization", "Bearer " + tokenAjeno)).andReturn();

        assertThat(r.getResponse().getStatus()).isEqualTo(404);
    }

    @Test
    @DisplayName("borrar una tarjeta que no existe responde 404")
    void borrarInexistenteDa404() throws Exception {
        MvcResult r = mvc.perform(delete("/api/cartera/tarjetas/" + java.util.UUID.randomUUID())
                .header("Authorization", "Bearer " + token)).andReturn();
        assertThat(r.getResponse().getStatus()).isEqualTo(404);
    }

    // ── Utilidades ───────────────────────────────────────────────────

    private MvcResult registrar(String correo) throws Exception {
        MvcResult r = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"correo":"%s","password":"%s","nombres":"Tarjeta",
                                 "apellidos":"Prueba","rol":"EMPLEADOR"}
                                """.formatted(correo, PASSWORD)))
                .andReturn();
        assertThat(r.getResponse().getStatus()).isEqualTo(200);
        return r;
    }

    private MvcResult agregarTarjeta(String numero, String titular, String vencimiento) throws Exception {
        return mvc.perform(post("/api/cartera/tarjetas")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"numero":"%s","titular":"%s","vencimiento":"%s"}
                                """.formatted(numero, titular, vencimiento)))
                .andReturn();
    }

    private JsonNode cuerpo(MvcResult r) throws Exception {
        return json.readTree(r.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }
}
