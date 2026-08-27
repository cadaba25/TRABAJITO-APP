package com.trabajito.common.enums;

/**
 * Papel que tenía la persona CALIFICADA en el trabajo por el que se la
 * califica (tarea 019).
 *
 * <p>Decisión del dueño del proyecto: <i>"dos diferentes para cada rol"</i>.
 * Ser buen trabajador y ser buen contratista son cosas distintas, así que cada
 * calificación suma en una reputación o en la otra, nunca en las dos.
 *
 * <p>No se reutiliza {@link Rol} a propósito: {@code Rol} es el rol de la
 * <b>cuenta</b> (e incluye {@code ADMIN}, que aquí no significa nada) y con el
 * doble perfil (tarea 012) una misma cuenta podrá ser las dos cosas. Lo que
 * decide dónde suma la calificación es el papel en <b>ese</b> trabajo.
 */
public enum RolCalificado {
    /** Recibió la calificación por hacer el trabajo. */
    TRABAJADOR,
    /** La recibió por contratar y pagar. */
    EMPLEADOR
}
