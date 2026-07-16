package com.trabajito.config;

import com.trabajito.common.enums.Rol;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Crea una cuenta de administrador por defecto en desarrollo si no existe.
 * Solo se activa con el perfil "dev" ({@code SPRING_PROFILES_ACTIVE=dev}).
 * Credenciales por defecto: admin@trabajito.local / Admin1234
 * (¡cámbialas en producción!).
 */
@Component
@Profile("dev")
public class DataSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    private final UsuarioRepository usuarios;
    private final PasswordEncoder passwordEncoder;

    public DataSeeder(UsuarioRepository usuarios, PasswordEncoder passwordEncoder) {
        this.usuarios = usuarios;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) {
        String correo = "admin@trabajito.local";
        if (usuarios.existsByCorreo(correo)) return;
        usuarios.save(Usuario.builder()
                .correo(correo)
                .passwordHash(passwordEncoder.encode("Admin1234"))
                .nombres("Admin")
                .apellidos("Trabajito")
                .rol(Rol.ADMIN)
                .build());
        log.info("Cuenta admin creada: {} / Admin1234 (cámbiala)", correo);
    }
}
