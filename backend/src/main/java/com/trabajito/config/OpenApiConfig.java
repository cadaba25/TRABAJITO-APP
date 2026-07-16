package com.trabajito.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Configura Swagger UI con soporte para el token JWT (botón "Authorize"). */
@Configuration
public class OpenApiConfig {

    private static final String ESQUEMA = "bearerAuth";

    @Bean
    public OpenAPI trabajitoOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Trabajito API")
                        .description("API REST del backend de Trabajito")
                        .version("0.1.0"))
                .addSecurityItem(new SecurityRequirement().addList(ESQUEMA))
                .components(new Components().addSecuritySchemes(ESQUEMA,
                        new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")));
    }
}
