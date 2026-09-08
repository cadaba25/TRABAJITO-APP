import 'package:flutter/material.dart';

import 'app_colores.dart';

// ─────────────────────────────────────────────────────────────
// TEMA
// ─────────────────────────────────────────────────────────────
class AppTema {
  static RoundedRectangleBorder get _formaBoton =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  static OutlineInputBorder _borde(Color color, double ancho) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: ancho),
      );

  /// Compatibilidad: por defecto devuelve el tema claro.
  static ThemeData obtenerTema() => temaClaro();

  // ── TEMA CLARO ───────────────────────────────────────────
  static ThemeData temaClaro() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: ThemeData(brightness: Brightness.light).textTheme.apply(fontFamily: 'Sora'),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColores.secundario,
        brightness: Brightness.light,
        primary: AppColores.secundario,
        onPrimary: AppColores.blanco,
        secondary: AppColores.acento,
        onSecondary: AppColores.blanco,
        surface: AppColores.blanco,
        onSurface: AppColores.texto,
        error: AppColores.error,
      ),
      scaffoldBackgroundColor: AppColores.fondo,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.secundario,
          foregroundColor: AppColores.blanco,
          minimumSize: const Size(double.infinity, 52),
          shape: _formaBoton,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColores.secundario,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColores.secundario, width: 1.5),
          shape: _formaBoton,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColores.blanco,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _borde(AppColores.grisClaro, 1.5),
        enabledBorder: _borde(AppColores.grisClaro, 1.5),
        focusedBorder: _borde(AppColores.secundario, 2),
        errorBorder: _borde(AppColores.error, 1.5),
        focusedErrorBorder: _borde(AppColores.error, 2),
        labelStyle: const TextStyle(color: AppColores.grisTexto),
        hintStyle: const TextStyle(color: AppColores.grisMedio),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColores.principal,
        foregroundColor: AppColores.blanco,
        elevation: 0,
        centerTitle: true,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColores.secundario;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  // ── TEMA OSCURO ──────────────────────────────────────────
  static ThemeData temaOscuro() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: ThemeData(brightness: Brightness.dark).textTheme.apply(fontFamily: 'Sora'),
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColores.acento,
        onPrimary: AppColores.blanco,
        secondary: AppColores.acento,
        onSecondary: AppColores.blanco,
        surface: AppColores.superficieOscura,
        onSurface: AppColores.textoOscuro,
        error: AppColores.error,
        onError: AppColores.blanco,
      ),
      scaffoldBackgroundColor: AppColores.fondoOscuro,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.acento,
          foregroundColor: AppColores.blanco,
          minimumSize: const Size(double.infinity, 52),
          shape: _formaBoton,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColores.textoOscuro,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColores.bordeOscuro, width: 1.5),
          shape: _formaBoton,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColores.superficieOscura,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _borde(AppColores.bordeOscuro, 1.5),
        enabledBorder: _borde(AppColores.bordeOscuro, 1.5),
        focusedBorder: _borde(AppColores.acento, 2),
        errorBorder: _borde(AppColores.error, 1.5),
        focusedErrorBorder: _borde(AppColores.error, 2),
        labelStyle: const TextStyle(color: AppColores.grisMedio),
        hintStyle: const TextStyle(color: AppColores.grisMedio),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColores.principal,
        foregroundColor: AppColores.blanco,
        elevation: 0,
        centerTitle: true,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColores.acento;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
