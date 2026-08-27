package com.trabajito.modules.auth.dto;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.nio.charset.StandardCharsets;
import java.util.Set;

/**
 * Implementa la política de {@link PasswordSegura} (ADR-0010).
 *
 * <p>Devuelve un mensaje distinto por regla incumplida: si solo dijera "la
 * contraseña no es válida", el usuario prueba variaciones a ciegas y acaba
 * eligiendo algo peor. Los mensajes van en español, como el resto de la API.
 */
public class ValidadorPasswordSegura implements ConstraintValidator<PasswordSegura, String> {

    /** Mínimo de caracteres. Antes eran 8 (ADR-0010 lo sube a 10). */
    public static final int MIN = 10;

    /** Máximo: BCrypt ignora todo lo que pase de 72 BYTES, no de 72 caracteres. */
    public static final int MAX_BYTES = 72;

    /**
     * Lista de bloqueo mínima: las que aparecen primero en cualquier ataque de
     * diccionario, más el nombre de la app. No pretende ser exhaustiva (eso
     * sería un servicio tipo "have i been pwned"); corta lo más obvio sin
     * añadir dependencias.
     */
    private static final Set<String> BLOQUEADAS = Set.of(
            "password", "passw0rd", "contrasena", "contraseña", "micontrasena",
            "1234567890", "12345678", "123456789", "0123456789", "qwertyuiop",
            "qwerty123", "administrador", "trabajito", "trabajito123",
            "iloveyou", "bienvenido", "honduras", "tegucigalpa", "abc123456",
            "letmein123", "changeme123", "secret123", "usuario123"
    );

    @Override
    public boolean isValid(String password, ConstraintValidatorContext ctx) {
        // null/vacío es asunto de @NotBlank: no lo duplicamos aquí (si no,
        // el usuario recibiría dos mensajes por el mismo campo).
        if (password == null || password.isEmpty()) return true;

        if (password.length() < MIN) {
            return rechazar(ctx, "La contraseña debe tener al menos " + MIN + " caracteres");
        }
        if (password.getBytes(StandardCharsets.UTF_8).length > MAX_BYTES) {
            return rechazar(ctx, "La contraseña no puede pasar de " + MAX_BYTES + " caracteres");
        }
        if (password.chars().allMatch(Character::isDigit)) {
            return rechazar(ctx, "La contraseña no puede ser solo números: "
                    + "un teléfono o una fecha se adivinan enseguida");
        }
        if (password.chars().distinct().count() == 1) {
            return rechazar(ctx, "La contraseña no puede ser el mismo carácter repetido");
        }
        if (BLOQUEADAS.contains(password.toLowerCase())) {
            return rechazar(ctx, "Esa contraseña es demasiado común. Elige otra");
        }
        return true;
    }

    private boolean rechazar(ConstraintValidatorContext ctx, String mensaje) {
        ctx.disableDefaultConstraintViolation();
        ctx.buildConstraintViolationWithTemplate(mensaje).addConstraintViolation();
        return false;
    }
}
