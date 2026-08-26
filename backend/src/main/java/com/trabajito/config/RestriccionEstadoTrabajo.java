package com.trabajito.config;

import com.trabajito.common.enums.EstadoTrabajo;
import java.util.Arrays;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Mantiene al día el CHECK que PostgreSQL tiene sobre {@code trabajos.estado}
 * cuando se añaden valores nuevos al enum {@link EstadoTrabajo}.
 *
 * <p><b>Por qué hace falta.</b> Hibernate genera un
 * {@code CHECK (estado IN (...))} a partir del enum, pero **solo al crear la
 * tabla**. Con {@code ddl-auto=update} —lo que usa este backend hoy— una tabla
 * que ya existe conserva el CHECK viejo para siempre. Al añadir
 * {@code EN_DISPUTA} en la tarea 010, el servidor de pruebas empezó a
 * responder <b>500</b> en {@code POST /api/trabajos/&#123;id&#125;/reclamar} con:
 *
 * <pre>ERROR: new row for relation "trabajos" violates check constraint "trabajos_estado_check"</pre>
 *
 * <p>Es decir: la válvula de escape de una disputa —justo lo que impide que
 * una de las partes se quede con el dinero— quedaba inutilizable, y el fallo
 * solo aparecía contra una base de datos preexistente, no en los tests (que
 * usan H2 con {@code create-drop} y sí regeneran el CHECK).
 *
 * <p><b>Es un parche provisional, igual que {@link RestriccionSaldoNoNegativo}.</b>
 * Lo correcto es Flyway/Liquibase (pendiente conocido en
 * {@code backend/README.md}). Cuando entren migraciones versionadas, este
 * componente se borra y esto pasa a ser una migración más. Mientras tanto,
 * cualquier valor nuevo del enum queda cubierto automáticamente: el CHECK se
 * regenera desde {@code EstadoTrabajo.values()}.
 */
@Component
public class RestriccionEstadoTrabajo implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(RestriccionEstadoTrabajo.class);

    /** Nombre que genera Hibernate para el check del enum en esta tabla. */
    static final String NOMBRE = "trabajos_estado_check";

    private final JdbcTemplate jdbc;

    public RestriccionEstadoTrabajo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!esPostgres()) {
            // H2 (tests) usa create-drop: Hibernate regenera el CHECK en cada arranque.
            return;
        }
        String valores = Arrays.stream(EstadoTrabajo.values())
                .map(e -> "'" + e.name() + "'")
                .collect(Collectors.joining(", "));

        String definicionActual = definicionActual();
        if (definicionActual != null && cubreTodosLosEstados(definicionActual)) {
            log.debug("El CHECK {} ya admite los {} estados del enum.",
                    NOMBRE, EstadoTrabajo.values().length);
            return;
        }

        try {
            if (definicionActual != null) {
                jdbc.execute("ALTER TABLE trabajos DROP CONSTRAINT " + NOMBRE);
            }
            jdbc.execute("ALTER TABLE trabajos ADD CONSTRAINT " + NOMBRE
                    + " CHECK (estado IN (" + valores + "))");
            log.info("CHECK {} regenerado con los {} estados del enum.",
                    NOMBRE, EstadoTrabajo.values().length);
        } catch (RuntimeException e) {
            log.error("No se pudo regenerar el CHECK {} sobre trabajos.estado. "
                    + "Las transiciones a estados nuevos del enum fallarán con error 500 "
                    + "hasta que se corrija a mano.", NOMBRE, e);
        }
    }

    /** Devuelve la definición del CHECK, o {@code null} si no existe. */
    private String definicionActual() {
        return jdbc.query(
                "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = ?",
                rs -> rs.next() ? rs.getString(1) : null,
                NOMBRE);
    }

    /** ¿La definición actual menciona todos los valores del enum? */
    private boolean cubreTodosLosEstados(String definicion) {
        return Arrays.stream(EstadoTrabajo.values())
                .allMatch(e -> definicion.contains("'" + e.name() + "'"));
    }

    private boolean esPostgres() {
        String producto = jdbc.execute((ConnectionCallback<String>) c ->
                c.getMetaData().getDatabaseProductName());
        return producto != null && producto.toLowerCase().contains("postgres");
    }
}
