package com.trabajito.modules.chats;

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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/** Tarea 054: contrato REST del chat que necesita la app para dejar Firestore. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ChatHttpTest {

    @Autowired private MockMvc mvc;
    @Autowired private ChatRoomRepository salas;
    private final ObjectMapper json = new ObjectMapper();

    private String tokenEmp, tokenTrab, tokenAjeno;
    private UUID trabajoId, chatId;

    @BeforeEach
    void preparar() throws Exception {
        JsonNode emp = registrar("EMPLEADOR");
        JsonNode trab = registrar("TRABAJADOR");
        tokenEmp = emp.get("token").asText();
        tokenTrab = trab.get("token").asText();
        tokenAjeno = registrar("TRABAJADOR").get("token").asText();
        trabajoId = UUID.randomUUID();
        chatId = salas.save(ChatRoom.builder().trabajoId(trabajoId).tituloTrabajo("Pintar")
                .empleadorId(UUID.fromString(emp.get("usuario").get("id").asText()))
                .empleadorNombre("Emp")
                .trabajadorId(UUID.fromString(trab.get("usuario").get("id").asText()))
                .trabajadorNombre("Trab").fechaUltimoMensaje(Instant.now()).build()).getId();
    }

    @Test
    @DisplayName("el chat se resuelve por trabajo; un ajeno recibe 403 y un trabajo sin chat 404")
    void porTrabajo() throws Exception {
        MvcResult ok = llamar(get("/api/chats/trabajo/" + trabajoId), tokenEmp);
        assertThat(ok.getResponse().getStatus()).isEqualTo(200);
        assertThat(cuerpo(ok).get("id").asText()).isEqualTo(chatId.toString());
        assertThat(llamar(get("/api/chats/trabajo/" + trabajoId), tokenAjeno)
                .getResponse().getStatus()).isEqualTo(403);
        assertThat(llamar(get("/api/chats/trabajo/" + UUID.randomUUID()), tokenEmp)
                .getResponse().getStatus()).isEqualTo(404);
    }

    @Test
    @DisplayName("no-leidos cuenta lo del otro, y /leido lo deja en cero")
    void noLeidos() throws Exception {
        enviar(tokenTrab, "hola");
        enviar(tokenTrab, "sigues ahi?");
        JsonNode n = cuerpo(llamar(get("/api/chats/no-leidos"), tokenEmp));
        assertThat(n.get("total").asLong()).isEqualTo(2);
        assertThat(n.get("porChat").get(chatId.toString()).asLong()).isEqualTo(2);
        assertThat(cuerpo(llamar(get("/api/chats/no-leidos"), tokenTrab)).get("total").asLong())
                .isZero();

        llamar(post("/api/chats/" + chatId + "/leido"), tokenEmp);
        assertThat(cuerpo(llamar(get("/api/chats/no-leidos"), tokenEmp)).get("total").asLong())
                .isZero();
    }

    @Test
    @DisplayName("mensajes?desde= devuelve solo los posteriores")
    void mensajesDesde() throws Exception {
        enviar(tokenTrab, "uno");
        JsonNode primero = cuerpo(llamar(get("/api/chats/" + chatId + "/mensajes"), tokenEmp)).get(0);
        String desde = primero.get("creadoEn").asText();
        Thread.sleep(20);
        enviar(tokenEmp, "dos");
        JsonNode nuevos = cuerpo(llamar(
                get("/api/chats/" + chatId + "/mensajes").param("desde", desde), tokenEmp));
        assertThat(nuevos).hasSize(1);
        assertThat(nuevos.get(0).get("contenido").asText()).isEqualTo("dos");
    }

    @Test
    @DisplayName("mensaje de mas de 2000 caracteres: 400, no 500")
    void mensajeLargo() throws Exception {
        assertThat(enviar(tokenTrab, "x".repeat(2001)).getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    @DisplayName("aceptar-pago es idempotente y no duplica el mensaje de sistema")
    void aceptarPagoIdempotente() throws Exception {
        llamar(post("/api/chats/" + chatId + "/proponer-pago").contentType(MediaType.APPLICATION_JSON)
                .content("{\"monto\":150}"), tokenTrab);
        llamar(post("/api/chats/" + chatId + "/aceptar-pago"), tokenEmp);
        MvcResult segunda = llamar(post("/api/chats/" + chatId + "/aceptar-pago"), tokenEmp);
        assertThat(segunda.getResponse().getStatus()).isEqualTo(200);
        JsonNode sala = cuerpo(segunda);
        assertThat(sala.get("pagoAcordado").asBoolean()).isTrue();
        assertThat(sala.get("pagoMonto").decimalValue()).isEqualByComparingTo("150");
        // propuesta + 1 aceptacion, no 2
        assertThat(cuerpo(llamar(get("/api/chats/" + chatId + "/mensajes"), tokenEmp))).hasSize(2);
    }

    // ── Tarea 056 (revision de seguridad) ──
    @Test
    @DisplayName("un ajeno no puede marcar como leidos los mensajes de un chat ajeno (IDOR)")
    void marcarLeidoAjeno() throws Exception {
        enviar(tokenTrab, "hola");
        assertThat(llamar(post("/api/chats/" + chatId + "/leido"), tokenAjeno)
                .getResponse().getStatus()).isEqualTo(403);
        assertThat(cuerpo(llamar(get("/api/chats/no-leidos"), tokenEmp)).get("total").asLong())
                .isEqualTo(1);
    }

    @Test
    @DisplayName("el cliente no puede falsificar mensajes de SISTEMA ni de propuesta")
    void tipoFalsificado() throws Exception {
        for (String tipo : new String[]{"SISTEMA", "PROPUESTA_PAGO", "PROPUESTA_TIEMPO"}) {
            MvcResult r = llamar(post("/api/chats/" + chatId + "/mensajes")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"contenido\":\"Pago acordado\",\"tipo\":\"" + tipo + "\"}"), tokenTrab);
            assertThat(r.getResponse().getStatus()).isEqualTo(400);
        }
    }

    @Test
    @DisplayName("mensaje largo valido (>255) no rompe ultimoMensaje; tiempo >255 es 400")
    void largos() throws Exception {
        assertThat(enviar(tokenTrab, "x".repeat(1500)).getResponse().getStatus()).isEqualTo(200);
        assertThat(llamar(post("/api/chats/" + chatId + "/proponer-tiempo")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"tiempo\":\"" + "t".repeat(300) + "\"}"), tokenTrab)
                .getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    @DisplayName("la primera propuesta de pago solo la hace el trabajador")
    void primeraPropuestaTrabajador() throws Exception {
        assertThat(llamar(post("/api/chats/" + chatId + "/proponer-pago")
                .contentType(MediaType.APPLICATION_JSON).content("{\"monto\":100}"), tokenEmp)
                .getResponse().getStatus()).isEqualTo(400);
        assertThat(llamar(post("/api/chats/" + chatId + "/proponer-pago")
                .contentType(MediaType.APPLICATION_JSON).content("{\"monto\":100}"), tokenAjeno)
                .getResponse().getStatus()).isEqualTo(403);
    }

    // ── auxiliares ──
    private MvcResult llamar(MockHttpServletRequestBuilder b, String token) throws Exception {
        return mvc.perform(b.header("Authorization", "Bearer " + token)).andReturn();
    }

    private MvcResult enviar(String token, String texto) throws Exception {
        return llamar(post("/api/chats/" + chatId + "/mensajes").contentType(MediaType.APPLICATION_JSON)
                .content("{\"contenido\":\"" + texto + "\"}"), token);
    }

    private JsonNode registrar(String rol) throws Exception {
        MvcResult r = mvc.perform(post("/api/auth/registro").contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"correo":"chat.%d@trabajito.local","password":"Prueba1234",
                         "nombres":"Chat","apellidos":"Prueba","rol":"%s"}
                        """.formatted(System.nanoTime(), rol))).andReturn();
        assertThat(r.getResponse().getStatus()).isEqualTo(200);
        return cuerpo(r);
    }

    private JsonNode cuerpo(MvcResult r) throws Exception {
        return json.readTree(r.getResponse().getContentAsString());
    }
}
