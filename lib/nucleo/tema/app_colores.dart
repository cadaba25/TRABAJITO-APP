import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// COLORES — Manual de marca Trabajito V1.0
// ─────────────────────────────────────────────────────────────
class AppColores {
  // Paleta de marca
  static const Color principal      = Color(0xFF0D1B2A); // Azul Marino
  static const Color azulProfesional= Color(0xFF1565C0); // Azul Profesional
  static const Color dorado         = Color(0xFFFFC107); // Amarillo Dorado (acento héroe)
  static const Color verde          = Color(0xFF20C997); // Verde Moderno
  static const Color grisLienzo     = Color(0xFFF1F3F6); // Gris Claro
  static const Color texto          = Color(0xFF0D1B2A); // Texto (marino)

  // Alias retrocompatibles (usados en todo el código existente)
  static const Color azulOscuro  = principal;            // #0D1B2A
  static const Color secundario  = principal;
  static const Color azul        = azulProfesional;      // #1565C0
  static const Color azulClaro   = Color(0xFF1E88E5);
  static const Color acento      = dorado;               // #FFC107

  /// Variante oscurecida de [dorado] para usarla como **texto** sobre fondo
  /// claro/blanco (nunca sobre el propio [dorado] — ese caso lo resuelve
  /// `AppTema.temaOscuro()` desde la tarea 031). `dorado` como texto sobre
  /// blanco da ~1.63:1 (falla WCAG AA); este tono da ~5.08:1. No es un color
  /// de marca nuevo, es el mismo dorado ajustado solo para ser legible como
  /// texto — ver `colorPrecio()` en `colores_por_tema.dart` (tarea 034,
  /// ADR-0016).
  static const Color doradoTexto = Color(0xFF8B6914);
  static const Color blanco      = Color(0xFFFFFFFF);
  static const Color grisClaro   = Color(0xFFE3E7EC);
  static const Color grisMedio   = Color(0xFF8A93A2);
  static const Color grisTexto   = Color(0xFF5B6675);
  static const Color error       = Color(0xFFEF4444);
  static const Color exito       = verde;                // #20C997
  static const Color fondo       = grisLienzo;           // #F1F3F6
  static const Color advertencia = dorado;

  // Superficies para modo oscuro
  static const Color fondoOscuro      = Color(0xFF0A1622);
  static const Color superficieOscura = Color(0xFF14273A);
  static const Color bordeOscuro      = Color(0xFF24384F);
  static const Color textoOscuro      = Color(0xFFE7ECF2);
}
