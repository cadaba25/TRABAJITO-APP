package com.trabajito.modules.usuarios;

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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

/**
 * Tarea 019 — el perfil completo del trabajador, a nivel HTTP.
 *
 * <p>Es la prueba de que <b>la fase 2 de la migración (ADR-0009) ya no pierde
 * datos</b>: se guarda un perfil con todo lo que recoge el registro de 5 pasos
 * de Flutter (incluidos experiencia y estudios, que antes no existían en el
 * backend) y se recupera igual.
 *
 * <p>Levanta el contexto contra H2 en memoria y pega a la API con MockMvc, con
 * la cadena de Spring Security puesta, igual que {@code MapeoErroresHttpTest}.
 * <b>No sustituye</b> a {@code backend/scripts/prueba-flujo-negocio.sh}: H2 se
 * recrea en cada arranque, así que aquí es imposible ver los fallos de esquema
 * contra una base de datos que ya existía (que es justo lo que ha mordido dos
 * veces a este proyecto).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class PerfilCompletoHttpTest {

    private static final String PASSWORD = "Prueba1234";

    @Autowired
    private MockMvc mvc;

    private final ObjectMapper json = new ObjectMapper();

    private String token;
    private String miId;

    @BeforeEach
    void registrarme() throws Exception {
        String correo = "perfil." + System.nanoTime() + "@trabajito.local";
        JsonNode r = cuerpo(registrar(correo, "TRABAJADOR"));
        token = r.get("token").asText();
        miId = r.get("usuario").get("id").asText();
    }

    // ── El caso que bloqueaba la fase 2 ──────────────────────────────

    @Test
    @DisplayName("se guarda y se recupera un perfil de trabajador COMPLETO, con experiencia y estudios")
    void perfilCompletoIdaYVuelta() throws Exception {
        MvcResult guardado = mvc.perform(put("/api/usuarios/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nombres":"Tomás","apellidos":"Pérez",
                                 "telefono":"9988-7766","telefonoEmergencia":"3311-2233",
                                 "fechaNacimiento":"15/03/1995","genero":"Masculino",
                                 "presentacion":"Electricista con 8 años de experiencia.",
                                 "urlCV":"/uploads/cv-tomas.pdf",
                                 "departamento":"Cortés","ciudad":"San Pedro Sula",
                                 "codigoPostal":"21102","pais":"Honduras","viveEnHonduras":true,
                                 "registroCompleto":true,
                                 "habilidades":["Electricidad","Plomería","electricidad"]}
                                """))
                .andReturn();
        assertThat(guardado.getResponse().getStatus()).isEqualTo(200);

        crearExperiencia();
        crearEstudio();

        JsonNode yo = cuerpo(mvc.perform(get("/api/auth/yo")
                .header("Authorization", "Bearer " + token)).andReturn());

        assertThat(yo.get("telefonoEmergencia").asText()).isEqualTo("3311-2233");
        // dd/MM/yyyy entra; ISO sale (ver UsuarioService.fechaDeNacimiento).
        assertThat(yo.get("fechaNacimiento").asText()).isEqualTo("1995-03-15");
        assertThat(yo.get("genero").asText()).isEqualTo("Masculino");
        assertThat(yo.get("codigoPostal").asText()).isEqualTo("21102");
        assertThat(yo.get("pais").asText()).isEqualTo("Honduras");
        assertThat(yo.get("viveEnHonduras").asBoolean()).isTrue();
        assertThat(yo.get("urlCV").asText()).isEqualTo("/uploads/cv-tomas.pdf");
        assertThat(yo.get("registroCompleto").asBoolean()).isTrue();
        assertThat(yo.get("creadoEn").asText()).isNotBlank();
        assertThat(yo.get("activo").asBoolean()).isTrue();

        // Habilidades: se normalizan (la repetida con otra caja no se duplica).
        assertThat(textos(yo.get("habilidades"))).containsExactlyInAnyOrder("Electricidad", "Plomería");

        JsonNode exp = yo.get("experiencia").get(0);
        assertThat(exp.get("empresa").asText()).isEqualTo("Constructora del Valle");
        assertThat(exp.get("puesto").asText()).isEqualTo("Electricista");
        assertThat(exp.get("fechaInicio").asText()).isEqualTo("01/2018");
        assertThat(exp.get("trabajaActualmente").asBoolean()).isTrue();
        // Si sigue ahí, la fecha de fin no significa nada y se guarda vacía.
        assertThat(exp.get("fechaFin").asText()).isEmpty();

        JsonNode est = yo.get("estudios").get(0);
        assertThat(est.get("nivel").asText()).isEqualTo("Universidad");
        assertThat(est.get("centro").asText()).isEqualTo("UNAH-VS");
        assertThat(est.get("fechaFin").asText()).isEqualTo("11/2016");
    }

    @Test
    @DisplayName("el perfil se puede editar y borrar puesto a puesto")
    void experienciaEditableYBorrable() throws Exception {
        String id = cuerpo(crearExperiencia()).get("id").asText();

        MvcResult editado = mvc.perform(put("/api/usuarios/me/experiencia/" + id)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"empresa":"Constructora del Valle","puesto":"Jefe de cuadrilla",
                                 "fechaInicio":"01/2018","fechaFin":"06/2024",
                                 "trabajaActualmente":false}
                                """))
                .andReturn();
        assertThat(editado.getResponse().getStatus()).isEqualTo(200);
        assertThat(cuerpo(editado).get("puesto").asText()).isEqualTo("Jefe de cuadrilla");
        assertThat(cuerpo(editado).get("fechaFin").asText()).isEqualTo("06/2024");

        assertThat(mvc.perform(delete("/api/usuarios/me/experiencia/" + id)
                        .header("Authorization", "Bearer " + token))
                .andReturn().getResponse().getStatus()).isEqualTo(200);

        JsonNode yo = cuerpo(mvc.perform(get("/api/auth/yo")
                .header("Authorization", "Bearer " + token)).andReturn());
        assertThat(yo.get("experiencia")).isEmpty();
    }

    @Test
    @DisplayName("nadie puede editar la experiencia de otra persona: 403")
    void noSePuedeEditarLaExperienciaAjena() throws Exception {
        String idExperiencia = cuerpo(crearExperiencia()).get("id").asText();
        String tokenAjeno = cuerpo(registrar("intruso." + System.nanoTime() + "@trabajito.local",
                "TRABAJADOR")).get("token").asText();

        MvcResult r = mvc.perform(put("/api/usuarios/me/experiencia/" + idExperiencia)
                        .header("Authorization", "Bearer " + tokenAjeno)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"empresa":"Otra","puesto":"Otro","trabajaActualmente":false}
                                """))
                .andReturn();

        assertThat(r.getResponse().getStatus()).isEqualTo(403);
    }

    // ── Privacidad del perfil público ────────────────────────────────

    @Test
    @DisplayName("el perfil de otra persona enseña el CV pero no sus datos personales ni su saldo")
    void perfilPublicoNoExponeDatosPersonales() throws Exception {
        mvc.perform(put("/api/usuarios/me")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"telefonoEmergencia":"3311-2233","fechaNacimiento":"15/03/1995",
                         "genero":"Masculino","codigoPostal":"21102","rtn":"08019995123456",
                         "habilidades":["Electricidad"]}
                        """)).andReturn();
        crearExperiencia();

        String tokenAjeno = cuerpo(registrar("curioso." + System.nanoTime() + "@trabajito.local",
                "EMPLEADOR")).get("token").asText();
        JsonNode publico = cuerpo(mvc.perform(get("/api/usuarios/" + miId)
                .header("Authorization", "Bearer " + tokenAjeno)).andReturn());

        // Lo que un contratista necesita para decidir sí se ve:
        assertThat(publico.get("nombreCompleto").asText()).isNotBlank();
        assertThat(textos(publico.get("habilidades"))).containsExactly("Electricidad");
        assertThat(publico.get("experiencia")).hasSize(1);
        assertThat(publico.get("calificacionComoTrabajador")).isNotNull();

        // Lo que no le incumbe, no:
        assertThat(publico.get("correo").isNull()).isTrue();
        assertThat(publico.get("dni").isNull()).isTrue();
        assertThat(publico.get("telefono").isNull()).isTrue();
        assertThat(publico.get("telefonoEmergencia").isNull()).isTrue();
        assertThat(publico.get("fechaNacimiento").isNull()).isTrue();
        assertThat(publico.get("genero").isNull()).isTrue();
        assertThat(publico.get("codigoPostal").isNull()).isTrue();
        assertThat(publico.get("rtn").isNull()).isTrue();
        assertThat(publico.get("saldo").isNull()).isTrue();
    }

    // ── Reglas de negocio del perfil ─────────────────────────────────

    @Test
    @DisplayName("un menor de 18 no puede guardar su fecha de nacimiento: 400")
    void menorDeEdadRechazado() throws Exception {
        String fechaDeUnMenor = java.time.LocalDate.now().minusYears(17)
                .format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy"));

        MvcResult r = mvc.perform(put("/api/usuarios/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fechaNacimiento\":\"" + fechaDeUnMenor + "\"}"))
                .andReturn();

        assertThat(r.getResponse().getStatus()).isEqualTo(400);
        assertThat(cuerpo(r).get("message").asText()).contains("18");
    }

    @Test
    @DisplayName("una fecha de nacimiento con formato raro da 400, no 500")
    void fechaInvalidaDa400() throws Exception {
        MvcResult r = mvc.perform(put("/api/usuarios/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fechaNacimiento\":\"31/02/1990\"}"))
                .andReturn();

        assertThat(r.getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    @DisplayName("el perfil no acepta textos más largos que su columna: 400 con el campo señalado")
    void textoDemasiadoLargoDa400() throws Exception {
        String muyLargo = "x".repeat(300);

        MvcResult r = mvc.perform(put("/api/usuarios/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"presentacion\":\"" + muyLargo + "\"}"))
                .andReturn();

        assertThat(r.getResponse().getStatus()).isEqualTo(400);
        assertThat(cuerpo(r).get("fields").has("presentacion")).isTrue();
    }

    @Test
    @DisplayName("crear una experiencia sin empresa ni puesto da 400")
    void experienciaIncompletaDa400() throws Exception {
        MvcResult r = mvc.perform(post("/api/usuarios/me/experiencia")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fechaInicio\":\"01/2018\"}"))
                .andReturn();

        assertThat(r.getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    @DisplayName("PUT /me/habilidades reemplaza la lista completa")
    void habilidadesSeReemplazan() throws Exception {
        mvc.perform(put("/api/usuarios/me/habilidades")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"habilidades\":[\"Albañilería\",\"Pintura\"]}")).andReturn();

        MvcResult segunda = mvc.perform(put("/api/usuarios/me/habilidades")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"habilidades\":[\"Soldadura\"]}"))
                .andReturn();

        assertThat(segunda.getResponse().getStatus()).isEqualTo(200);
        assertThat(textos(cuerpo(segunda))).containsExactly("Soldadura");

        JsonNode yo = cuerpo(mvc.perform(get("/api/usuarios/me")
                .header("Authorization", "Bearer " + token)).andReturn());
        assertThat(textos(yo.get("habilidades"))).containsExactly("Soldadura");
    }

    @Test
    @DisplayName("el perfil sigue sin poder cambiarse el rol a sí mismo (ADR-0005)")
    void elPerfilNoCambiaElRol() throws Exception {
        MvcResult r = mvc.perform(put("/api/usuarios/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombres\":\"Tomás\",\"rol\":\"ADMIN\"}"))
                .andReturn();

        assertThat(cuerpo(r).get("rol").asText()).isEqualTo("TRABAJADOR");
    }

    // ── Utilidades ───────────────────────────────────────────────────

    private MvcResult registrar(String correo, String rol) throws Exception {
        MvcResult r = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"correo":"%s","password":"%s","nombres":"Perfil",
                                 "apellidos":"Prueba","rol":"%s"}
                                """.formatted(correo, PASSWORD, rol)))
                .andReturn();
        assertThat(r.getResponse().getStatus()).isEqualTo(200);
        return r;
    }

    private MvcResult crearExperiencia() throws Exception {
        MvcResult r = mvc.perform(post("/api/usuarios/me/experiencia")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"empresa":"Constructora del Valle","puesto":"Electricista",
                                 "habilidades":"Instalaciones residenciales",
                                 "descripcion":"Cableado y tableros.",
                                 "fechaInicio":"01/2018","fechaFin":"","trabajaActualmente":true}
                                """))
                .andReturn();
        assertThat(r.getResponse().getStatus()).isEqualTo(201);
        return r;
    }

    private MvcResult crearEstudio() throws Exception {
        MvcResult r = mvc.perform(post("/api/usuarios/me/estudios")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nivel":"Universidad","centro":"UNAH-VS",
                                 "fechaInicio":"01/2012","fechaFin":"11/2016",
                                 "cursandoActualmente":false}
                                """))
                .andReturn();
        assertThat(r.getResponse().getStatus()).isEqualTo(201);
        return r;
    }

    private JsonNode cuerpo(MvcResult r) throws Exception {
        return json.readTree(r.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }

    private java.util.List<String> textos(JsonNode array) {
        java.util.List<String> lista = new java.util.ArrayList<>();
        array.forEach(n -> lista.add(n.asText()));
        return lista;
    }
}
