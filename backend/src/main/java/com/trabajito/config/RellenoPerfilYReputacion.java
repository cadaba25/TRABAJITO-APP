package com.trabajito.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Rellena los datos que faltan en una base de datos que ya existía cuando la
 * tarea 019 añadió el perfil completo y la reputación por rol.
 *
 * <p><b>Por qué hace falta.</b> {@code ddl-auto=update} sabe añadir columnas,
 * pero no sabe rellenarlas, y hay dos cosas que no puede resolver solo:
 * <ol>
 *   <li>{@code calificaciones.rol_calificado} llega vacía en las filas
 *       anteriores. Su valor correcto depende de cada fila (¿al receptor lo
 *       calificaron como trabajador o como contratista?), así que un
 *       {@code DEFAULT} sería mentira en la mitad de los casos: hay que
 *       deducirlo del trabajo. Sin esto, las reseñas viejas se quedarían fuera
 *       de las dos reputaciones nuevas.</li>
 *   <li>Las columnas nuevas de {@code usuarios} se declaran con
 *       {@code @ColumnDefault} y sin {@code NOT NULL} porque PostgreSQL no
 *       admite añadir una columna NOT NULL sin valor por defecto a una tabla
 *       con filas. Si por lo que sea alguna quedara a NULL, aquí se pone a su
 *       valor por defecto: un NULL en un {@code int} de la entidad reventaría
 *       al leer el usuario.</li>
 * </ol>
 *
 * <p><b>Es un parche provisional</b>, igual que {@link RestriccionSaldoNoNegativo}
 * y {@link RestriccionEstadoTrabajo}: esto es exactamente el trabajo de una
 * migración de Flyway/Liquibase (pendiente en {@code backend/README.md} y
 * propuesto en ADR-0011). Es idempotente: en el segundo arranque no hace nada.
 */
@Component
public class RellenoPerfilYReputacion implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(RellenoPerfilYReputacion.class);

    private final JdbcTemplate jdbc;

    public RellenoPerfilYReputacion(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!esPostgres()) {
            // H2 (tests) usa create-drop: no hay datos viejos que rellenar.
            return;
        }
        rellenarDefectosDeUsuarios();
        int deducidas = deducirRolCalificado();
        if (deducidas > 0) {
            recalcularReputacionPorRol();
        }
    }

    /** Tapa cualquier NULL en las columnas nuevas de usuarios. */
    private void rellenarDefectosDeUsuarios() {
        int tocadas = 0;
        tocadas += poner("calificacion_como_trabajador", "0");
        tocadas += poner("total_calificaciones_como_trabajador", "0");
        tocadas += poner("calificacion_como_empleador", "0");
        tocadas += poner("total_calificaciones_como_empleador", "0");
        tocadas += poner("registro_completo", "false");
        tocadas += poner("vive_en_honduras", "true");
        tocadas += poner("pais", "'Honduras'");
        if (tocadas > 0) {
            log.info("Perfil: {} valor(es) por defecto rellenados en usuarios.", tocadas);
        }
    }

    private int poner(String columna, String valor) {
        try {
            return jdbc.update("UPDATE usuarios SET " + columna + " = " + valor
                    + " WHERE " + columna + " IS NULL");
        } catch (RuntimeException e) {
            log.error("No se pudo rellenar usuarios.{}. Si la columna no existe, "
                    + "Hibernate no pudo añadirla y el perfil quedará incompleto.", columna, e);
            return 0;
        }
    }

    /**
     * Deduce el rol calificado de las reseñas anteriores a la tarea 019: si el
     * receptor era el trabajador asignado de ese trabajo, la recibió como
     * TRABAJADOR; si no, como EMPLEADOR.
     */
    private int deducirRolCalificado() {
        try {
            int n = jdbc.update("""
                    UPDATE calificaciones c
                       SET rol_calificado = CASE
                             WHEN c.receptor_id = t.trabajador_asignado_id THEN 'TRABAJADOR'
                             ELSE 'EMPLEADOR' END
                      FROM trabajos t
                     WHERE t.id = c.trabajo_id
                       AND c.rol_calificado IS NULL
                    """);
            if (n > 0) {
                log.info("Reputación por rol: {} calificación(es) antiguas clasificadas.", n);
            }
            Integer huerfanas = jdbc.queryForObject(
                    "SELECT count(*) FROM calificaciones WHERE rol_calificado IS NULL",
                    Integer.class);
            if (huerfanas != null && huerfanas > 0) {
                log.warn("Quedan {} calificación(es) sin rol_calificado: su trabajo ya no existe. "
                        + "No suman en ninguna de las dos reputaciones.", huerfanas);
            }
            return n;
        } catch (RuntimeException e) {
            log.error("No se pudo deducir rol_calificado de las calificaciones antiguas. "
                    + "Las reputaciones por rol arrancarán solo con lo nuevo.", e);
            return 0;
        }
    }

    /**
     * Recalcula las dos medias por rol desde la tabla de calificaciones. Solo
     * corre el arranque en el que se clasificaron reseñas antiguas: a partir de
     * ahí las mantiene {@code CalificacionService} de forma incremental.
     */
    private void recalcularReputacionPorRol() {
        try {
            int trabajador = recalcular("TRABAJADOR",
                    "calificacion_como_trabajador", "total_calificaciones_como_trabajador");
            int empleador = recalcular("EMPLEADOR",
                    "calificacion_como_empleador", "total_calificaciones_como_empleador");
            log.info("Reputación por rol recalculada: {} usuario(s) con reseñas como trabajador, "
                    + "{} como contratista.", trabajador, empleador);
        } catch (RuntimeException e) {
            log.error("No se pudieron recalcular las reputaciones por rol.", e);
        }
    }

    private int recalcular(String rol, String columnaMedia, String columnaTotal) {
        return jdbc.update("""
                UPDATE usuarios u
                   SET %s = s.media,
                       %s = s.total
                  FROM (SELECT receptor_id,
                               ROUND(AVG(estrellas)::numeric, 2) AS media,
                               COUNT(*)                          AS total
                          FROM calificaciones
                         WHERE rol_calificado = ?
                         GROUP BY receptor_id) s
                 WHERE u.id = s.receptor_id
                """.formatted(columnaMedia, columnaTotal), rol);
    }

    private boolean esPostgres() {
        String producto = jdbc.execute((ConnectionCallback<String>) c ->
                c.getMetaData().getDatabaseProductName());
        return producto != null && producto.toLowerCase().contains("postgres");
    }
}
