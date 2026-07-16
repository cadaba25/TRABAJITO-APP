package com.trabajito.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/** Configuración de CORS para permitir el consumo desde la app Flutter (web/dev). */
@Configuration
public class CorsConfig {

    @Value("${trabajito.cors.allowed-origins}")
    private String allowedOrigins;

    @Bean
    public UrlBasedCorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        List<String> origenes = Arrays.stream(allowedOrigins.split(","))
                .map(String::trim).toList();

        if (origenes.size() == 1 && origenes.get(0).equals("*")) {
            // Comodín: en dev. allowedOriginPatterns permite '*' junto con credenciales.
            config.setAllowedOriginPatterns(List.of("*"));
        } else {
            config.setAllowedOrigins(origenes);
        }
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
