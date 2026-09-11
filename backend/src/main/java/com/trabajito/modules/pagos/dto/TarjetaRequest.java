package com.trabajito.modules.pagos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Alta de una tarjeta. Trae el número completo solo de paso (igual que hace
 * hoy {@code CarteraService.agregarTarjeta} en Flutter contra Firestore):
 * {@code TarjetaService} lo valida y se queda solo con los últimos 4 dígitos;
 * el número completo nunca se guarda ni se devuelve. {@code marca} es
 * opcional — si no viene, el servidor la deduce del número.
 */
public record TarjetaRequest(
        @NotBlank(message = "Ingresa el número de la tarjeta")
        @Size(max = 32, message = "Número de tarjeta inválido")
        String numero,

        @NotBlank(message = "Ingresa el nombre del titular")
        @Size(max = 150)
        String titular,

        @NotBlank(message = "Ingresa el vencimiento (MM/AA)")
        @Size(max = 10)
        String vencimiento,

        @Size(max = 20)
        String marca
) {}
