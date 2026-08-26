package com.trabajito.config;

import com.trabajito.common.enums.Rol;
import com.trabajito.modules.usuarios.Usuario;
import com.trabajito.modules.usuarios.UsuarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Aprovisiona el administrador inicial en el arranque. Es la ÚNICA vía
 * soportada para crear un {@code ADMIN}: el registro público
 * ({@code POST /api/auth/registro}) no puede hacerlo, por diseño (ADR-0005).
 *
 * <p>Inerte por defecto: si no están definidas {@code ADMIN_INICIAL_CORREO} y
 * {@code ADMIN_INICIAL_PASSWORD}, no hace absolutamente nada, en ningún
 * perfil. Antes esto era {@code DataSeeder}, que con {@code @Profile("dev")}
 * creaba {@code admin@trabajito.local / Admin1234} — una credencial conocida
 * publicada en Git, a un {@code SPRING_PROFILES_ACTIVE=dev} de distancia.
 *
 * <p>Reglas deliberadas:
 * <ul>
 *   <li>No promueve cuentas ya existentes. Si el correo ya está en uso, avisa
 *       y no toca nada: promover en silencio a un usuario que se registró
 *       solo sería otra escalada de privilegios, más difícil de ver.</li>
 *   <li>Exige contraseña de al menos 12 caracteres (el registro normal pide
 *       8): es la cuenta con más poder del sistema.</li>
 *   <li>No hay endpoint para crear ni promover administradores. Un segundo
 *       ADMIN se crea con SQL de operación, auditable — ver
 *       {@code backend/README.md}.</li>
 * </ul>
 */
@Component
public class AdminInicialSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminInicialSeeder.class);
    private static final int MIN_PASSWORD = 12;

    private final UsuarioRepository usuarios;
    private final PasswordEncoder passwordEncoder;
    private final String correo;
    private final String password;

    public AdminInicialSeeder(UsuarioRepository usuarios,
                              PasswordEncoder passwordEncoder,
                              @Value("${trabajito.admin-inicial.correo:}") String correo,
                              @Value("${trabajito.admin-inicial.password:}") String password) {
        this.usuarios = usuarios;
        this.passwordEncoder = passwordEncoder;
        this.correo = correo;
        this.password = password;
    }

    @Override
    public void run(String... args) {
        String correoNormalizado = correo == null ? "" : correo.toLowerCase().trim();
        if (correoNormalizado.isEmpty() || password == null || password.isEmpty()) {
            // Estado seguro por defecto: el sistema arranca SIN ningún ADMIN.
            log.debug("ADMIN_INICIAL_* no definido: no se aprovisiona ningún administrador");
            return;
        }
        if (password.length() < MIN_PASSWORD) {
            log.error("ADMIN_INICIAL_PASSWORD tiene menos de {} caracteres: "
                    + "no se creó el administrador inicial", MIN_PASSWORD);
            return;
        }
        if (usuarios.existsByCorreo(correoNormalizado)) {
            log.warn("Ya existe una cuenta con el correo {}: no se toca. "
                    + "Promover una cuenta existente a ADMIN es una operación manual "
                    + "(ver backend/README.md)", correoNormalizado);
            return;
        }
        usuarios.save(Usuario.builder()
                .correo(correoNormalizado)
                .passwordHash(passwordEncoder.encode(password))
                .nombres("Admin")
                .apellidos("Trabajito")
                .rol(Rol.ADMIN)
                .build());
        log.info("Administrador inicial creado: {} (la contraseña salió de "
                + "ADMIN_INICIAL_PASSWORD; cámbiala tras el primer acceso)", correoNormalizado);
    }
}
