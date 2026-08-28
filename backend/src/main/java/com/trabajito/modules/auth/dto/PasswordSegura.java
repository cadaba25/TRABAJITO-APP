package com.trabajito.modules.auth.dto;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Política de contraseñas del registro (tarea 015, ADR-0010).
 *
 * <p>Sustituye al antiguo {@code @Size(min = 8)}. El criterio es el de NIST
 * 800-63B: <b>longitud sobre complejidad</b>. No se exige mezcla obligatoria de
 * mayúsculas/dígitos/símbolos (empuja a patrones predecibles del tipo
 * {@code Password1!}); se exigen 10 caracteres y se filtran las contraseñas que
 * de verdad se adivinan: las de lista común, las que son solo dígitos (teléfono
 * o fecha de nacimiento) y las de un solo carácter repetido.
 *
 * <p>El máximo de 72 no es cosmético: <b>BCrypt trunca en 72 bytes</b>. Aceptar
 * más caracteres daría una falsa sensación de fortaleza, porque los de más allá
 * del byte 72 no se usan al comparar.
 *
 * @see ValidadorPasswordSegura
 */
@Documented
@Constraint(validatedBy = ValidadorPasswordSegura.class)
@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.RECORD_COMPONENT})
@Retention(RetentionPolicy.RUNTIME)
public @interface PasswordSegura {

    String message() default "La contraseña no cumple la política de seguridad";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
