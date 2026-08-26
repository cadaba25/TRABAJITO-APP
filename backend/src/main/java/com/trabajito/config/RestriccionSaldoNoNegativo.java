package com.trabajito.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Se asegura de que {@code usuarios.saldo} tenga el CHECK {@code >= 0} en
 * PostgreSQL, incluso en bases de datos que ya existían.
 *
 * <p><b>Por qué hace falta este componente.</b> La restricción está declarada
 * en la entidad ({@code @Check} en {@code Usuario}), pero Hibernate solo la
 * emite al <i>crear</i> la tabla: con {@code ddl-auto=update}, que es lo que
 * usa este backend hoy, las tablas que ya existen no reciben checks nuevos.
 * Sin esto, el servidor de pruebas —creado antes de la tarea 007— se quedaría
 * sin la última línea de defensa del dinero.
 *
 * <p><b>Es un parche provisional, no un sistema de migraciones.</b> Lo correcto
 * es Flyway/Liquibase (pendiente listado en {@code backend/README.md}); ver
 * ADR-0006 para por qué no se metió en esta tarea. Si acaban entrando
 * migraciones versionadas, este componente se borra y la restricción pasa a
 * ser una migración más.
 *
 * <p>La restricción se añade como {@code NOT VALID} (protege toda escritura
 * nueva desde ya, sin mirar las filas viejas) y después se intenta validar. Si
 * la validación falla porque hay saldos negativos heredados, se registra un
 * ERROR con el recuento y el arranque continúa: dejar la API sin arrancar por
 * datos históricos sería peor que arrancar con la restricción sin validar.
 */
@Component
public class RestriccionSaldoNoNegativo implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(RestriccionSaldoNoNegativo.class);

    /** Mismo nombre que declara {@code @Check} en la entidad Usuario. */
    static final String NOMBRE = "ck_usuarios_saldo_no_negativo";

    private final JdbcTemplate jdbc;

    public RestriccionSaldoNoNegativo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!esPostgres()) {
            // H2 (tests) ya la crea desde @Check porque usa create-drop.
            return;
        }
        Integer yaExiste = jdbc.queryForObject(
                "SELECT count(*) FROM pg_constraint WHERE conname = ?", Integer.class, NOMBRE);
        if (yaExiste != null && yaExiste > 0) {
            log.debug("La restricción {} ya existe.", NOMBRE);
            return;
        }
        try {
            jdbc.execute("ALTER TABLE usuarios ADD CONSTRAINT " + NOMBRE
                    + " CHECK (saldo >= 0) NOT VALID");
            log.info("Restricción {} añadida a usuarios.saldo.", NOMBRE);
        } catch (RuntimeException e) {
            log.error("No se pudo añadir la restricción {} sobre usuarios.saldo. "
                    + "La cartera queda sin su última línea de defensa en la BD.", NOMBRE, e);
            return;
        }
        try {
            jdbc.execute("ALTER TABLE usuarios VALIDATE CONSTRAINT " + NOMBRE);
        } catch (RuntimeException e) {
            Integer negativos = jdbc.queryForObject(
                    "SELECT count(*) FROM usuarios WHERE saldo < 0", Integer.class);
            log.error("La restricción {} quedó como NOT VALID: hay {} usuario(s) con saldo "
                            + "negativo heredado. Protege las escrituras nuevas, pero esos datos "
                            + "hay que corregirlos y volver a validarla a mano.",
                    NOMBRE, negativos, e);
        }
    }

    private boolean esPostgres() {
        String producto = jdbc.execute((ConnectionCallback<String>) c ->
                c.getMetaData().getDatabaseProductName());
        return producto != null && producto.toLowerCase().contains("postgres");
    }
}
