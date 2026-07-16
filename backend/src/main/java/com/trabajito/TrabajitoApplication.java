package com.trabajito;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Punto de entrada del backend de Trabajito.
 *
 * <p>Arranque local:
 * <ol>
 *   <li>Levanta la base de datos:  {@code docker compose up -d db}</li>
 *   <li>Corre la app:  {@code mvn spring-boot:run}  (o desde el IDE)</li>
 *   <li>Documentación de la API:  http://localhost:8080/swagger-ui.html</li>
 * </ol>
 */
@SpringBootApplication
public class TrabajitoApplication {
    public static void main(String[] args) {
        SpringApplication.run(TrabajitoApplication.class, args);
    }
}
