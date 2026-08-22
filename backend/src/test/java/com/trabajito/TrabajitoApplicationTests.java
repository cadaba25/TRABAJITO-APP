package com.trabajito;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Test de contexto: confirma que toda la aplicación Spring levanta
 * correctamente (todos los beans se instancian, no hay ciclos ni
 * configuración rota) usando H2 en memoria en vez de Postgres real, para no
 * depender de Docker corriendo en la máquina que ejecuta los tests. Ver la
 * justificación completa en docs/agent-reports/003-tests-base-backend.md.
 *
 * <p>Ya no existe el perfil "dev" que sembraba un admin con contraseña fija:
 * {@code AdminInicialSeeder} sí se instancia como bean aquí, pero es inerte
 * sin las variables {@code ADMIN_INICIAL_*} (ADR-0005), así que este test no
 * crea ningún administrador.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class TrabajitoApplicationTests {

    @Test
    void contextLoads() {
        // Si el contexto de Spring no levanta, este test falla solo con el
        // intento de @SpringBootTest de construir el ApplicationContext.
    }
}
