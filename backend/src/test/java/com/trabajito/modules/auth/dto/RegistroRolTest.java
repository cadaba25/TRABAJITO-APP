package com.trabajito.modules.auth.dto;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.trabajito.common.enums.Rol;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Contrato de seguridad del registro PÚBLICO (ADR-0005, tarea 008): el campo
 * `rol` que llega del cliente no puede producir un administrador.
 *
 * <p>Se prueba en la capa donde vive la defensa de verdad — la
 * deserialización JSON + Bean Validation del DTO — porque el ataque real es
 * un JSON crudo contra `POST /api/auth/registro`, no una llamada Java a
 * `AuthService`. Con el tipo `RolPublico`, un test unitario de `AuthService`
 * ni siquiera puede construir una petición con ADMIN: esa imposibilidad es
 * justo lo que estos tests documentan.
 */
class RegistroRolTest {

    private static ObjectMapper json;
    private static Validator validator;
    private static ValidatorFactory factory;

    @BeforeAll
    static void setUp() {
        json = new ObjectMapper();
        // La factory se mantiene abierta a proposito: al cerrarla, el
        // Validator que produjo deja de ser utilizable.
        factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @AfterAll
    static void tearDown() {
        factory.close();
    }

    private static String cuerpo(String rolJson) {
        return "{\"correo\":\"a@b.com\",\"password\":\"contrasena123\","
                + "\"nombres\":\"N\",\"apellidos\":\"A\",\"rol\":" + rolJson + "}";
    }

    // --- Lo que esta tarea cierra ------------------------------------------

    @Test
    void ningunRolPublicoMapeaAAdmin() {
        // Guardia contra la regresión más probable: que alguien añada ADMIN
        // al enum del DTO "para que el seeder lo use". Si esto falla, el
        // registro público volvió a poder crear administradores.
        for (RolPublico r : RolPublico.values()) {
            assertThat(r.aRol()).isNotEqualTo(Rol.ADMIN);
        }
        assertThat(RolPublico.values()).hasSize(2);
    }

    @Test
    void registroConRolAdmin_noDeserializaYQuedaInvalido() throws Exception {
        RegistroRequest req = json.readValue(cuerpo("\"ADMIN\""), RegistroRequest.class);

        // No hay forma de que este objeto llegue al servicio con ADMIN:
        // el tipo no lo admite, así que queda null...
        assertThat(req.rol()).isNull();
        // ...y @NotNull lo convierte en un 400 de validación, no en un 500.
        assertThat(validator.validate(req))
                .extracting(v -> v.getPropertyPath().toString())
                .contains("rol");
    }

    @ParameterizedTest
    @ValueSource(strings = {"ADMIN", "admin", " Admin ", "SUPERJEFE", "ROLE_ADMIN", ""})
    void valoresNoPermitidos_seRechazanIgual(String valor) throws Exception {
        RegistroRequest req = json.readValue(cuerpo("\"" + valor + "\""), RegistroRequest.class);
        assertThat(req.rol()).isNull();
        assertThat(validator.validate(req)).isNotEmpty();
    }

    @Test
    void rolAusenteONulo_tambienEsInvalido() throws Exception {
        assertThat(json.readValue(cuerpo("null"), RegistroRequest.class).rol()).isNull();
        String sinCampo = "{\"correo\":\"a@b.com\",\"password\":\"contrasena123\","
                + "\"nombres\":\"N\",\"apellidos\":\"A\"}";
        assertThat(json.readValue(sinCampo, RegistroRequest.class).rol()).isNull();
    }

    // --- Lo que debe seguir funcionando igual ------------------------------

    @Test
    void trabajadorYEmpleadorSiguenSiendoValidos() throws Exception {
        RegistroRequest tra = json.readValue(cuerpo("\"TRABAJADOR\""), RegistroRequest.class);
        RegistroRequest emp = json.readValue(cuerpo("\"EMPLEADOR\""), RegistroRequest.class);

        assertThat(tra.rol().aRol()).isEqualTo(Rol.TRABAJADOR);
        assertThat(emp.rol().aRol()).isEqualTo(Rol.EMPLEADOR);
        assertThat(validator.validate(tra)).isEmpty();
        assertThat(validator.validate(emp)).isEmpty();
    }

    @Test
    void minusculasYEspacios_seAceptan() {
        // Tolerancia nueva y deliberada: antes "trabajador" reventaba con 500.
        assertThat(RolPublico.desde(" trabajador ")).isEqualTo(RolPublico.TRABAJADOR);
        assertThat(RolPublico.desde("Empleador")).isEqualTo(RolPublico.EMPLEADOR);
    }
}
