package com.trabajito.config;

import com.trabajito.security.JwtAuthFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpMethod;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;

/**
 * Configuración central de seguridad:
 * - Sin estado (JWT, no sesiones).
 * - Rutas públicas: registro/login, documentación, WebSocket handshake.
 * - Excepción: {@code POST /api/auth/logout-todos} sí exige token (ADR-0012).
 * - Todo lo demás requiere token válido.
 */
@Configuration
@EnableMethodSecurity   // habilita @PreAuthorize en los controllers
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final CorsConfigurationSource corsConfigurationSource;
    private final AuthenticationEntryPoint puntoDeEntradaNoAutenticado;
    private final AccessDeniedHandler manejadorAccesoDenegado;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter,
                          CorsConfigurationSource corsConfigurationSource,
                          AuthenticationEntryPoint puntoDeEntradaNoAutenticado,
                          AccessDeniedHandler manejadorAccesoDenegado) {
        this.jwtAuthFilter = jwtAuthFilter;
        this.corsConfigurationSource = corsConfigurationSource;
        this.puntoDeEntradaNoAutenticado = puntoDeEntradaNoAutenticado;
        this.manejadorAccesoDenegado = manejadorAccesoDenegado;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            // Sin esto, la cadena de filtros responde 403 con cuerpo vacio a
            // quien llega SIN token, y el cliente no sabe si reautenticar
            // (tarea 009). Ahora: 401 sin credenciales, 403 con credenciales
            // pero sin permiso, ambos con el JSON de error estandar.
            .exceptionHandling(ex -> ex
                    .authenticationEntryPoint(puntoDeEntradaNoAutenticado)
                    .accessDeniedHandler(manejadorAccesoDenegado))
            .authorizeHttpRequests(auth -> auth
                // Excepcion DENTRO de /api/auth/**: cerrar sesion en todos los
                // dispositivos es destructivo, asi que exige token de acceso
                // valido (tarea 024, ADR-0012). Va ANTES del permitAll porque
                // en Spring Security gana la primera regla que casa.
                .requestMatchers(HttpMethod.POST, "/api/auth/logout-todos").authenticated()
                .requestMatchers(
                        "/api/auth/**",
                        "/v3/api-docs/**",
                        "/swagger-ui/**",
                        "/swagger-ui.html",
                        "/uploads/**",           // archivos públicos (fotos, evidencias)
                        "/ws/**"                 // handshake WebSocket (token va en el mensaje)
                ).permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration cfg)
            throws Exception {
        return cfg.getAuthenticationManager();
    }
}
