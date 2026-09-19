import 'package:flutter/material.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/tema/app_colores.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';

/// Decoración de los tres campos DD/MM/AAAA de fecha de nacimiento.
///
/// Compartida entre `registro_trabajador_screen.dart` y
/// `registro_empleador_screen.dart` (antes duplicada como `_decoFecha` en
/// ambos archivos, idéntica salvo el `hint`).
InputDecoration decoracionCampoFecha(BuildContext context, String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColores.grisMedio),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: AppEspaciado.md, vertical: AppEspaciado.lg),
    filled: true,
    fillColor: colorSuperficie(context),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadios.campo),
      borderSide: BorderSide(color: colorBorde(context), width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadios.campo),
      borderSide: BorderSide(color: colorBorde(context), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadios.campo)),
      borderSide: const BorderSide(color: AppColores.acento, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadios.campo)),
      borderSide: const BorderSide(color: AppColores.error, width: 1.5),
    ),
  );
}
