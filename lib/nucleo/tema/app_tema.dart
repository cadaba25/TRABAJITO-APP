import 'package:flutter/material.dart';

import '../espaciado/app_espaciado.dart';
import 'app_colores.dart';

// ─────────────────────────────────────────────────────────────
// TEMA
// ─────────────────────────────────────────────────────────────
//
// Contraste corregido en el modo oscuro (ADR-0016, tarea 031): hasta esta
// tarea, `temaOscuro()` pintaba texto blanco sobre el dorado de acento
// (`AppColores.acento`, #FFC107) en el botón primario, en `onSecondary` y —
// por herencia del `ColorScheme` de Material— en el color del check del
// checkbox. Contraste medido con la fórmula WCAG 2.x (luminancia relativa +
// `(L1+0.05)/(L2+0.05)`): **blanco sobre `acento` = 1.63:1**, muy por debajo
// del mínimo AA de 4.5:1 para texto normal. `AppColores.principal` (el
// marino de marca, mismo valor que `AppColores.texto`) sobre `acento` da
// **10.67:1**, que cumple AA y AAA. Por eso `onPrimary`/`onSecondary` pasan
// de `AppColores.blanco` a `AppColores.principal` en `temaOscuro()` — ver el
// cálculo completo en `docs/agent-reports/031-*.md`. El tema claro no tenía
// este defecto (su `primary` es el marino, no el dorado) y no se toca.
class AppTema {
  static RoundedRectangleBorder get _formaBoton =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.campo));

  static OutlineInputBorder _borde(Color color, double ancho) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadios.campo),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppEspaciado.lg, vertical: AppEspaciado.lg),
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
        // Antes AppColores.blanco → 1.63:1 sobre `acento`, falla WCAG AA.
        // AppColores.principal sobre `acento` = 10.67:1. Ver docstring de la
        // clase para el cálculo completo.
        onPrimary: AppColores.principal,
        secondary: AppColores.acento,
        onSecondary: AppColores.principal, // mismo arreglo: mismo par de colores.
        surface: AppColores.superficieOscura,
        onSurface: AppColores.textoOscuro,
        error: AppColores.error,
        onError: AppColores.blanco,
      ),
      scaffoldBackgroundColor: AppColores.fondoOscuro,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.acento,
          foregroundColor: AppColores.principal, // ver arreglo de contraste arriba.
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppEspaciado.lg, vertical: AppEspaciado.lg),
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
        // Explícito, no heredado: Material 3 usa `colorScheme.onPrimary` como
        // color del check por defecto cuando está seleccionado, así que sin
        // esto el checkbox habría heredado el mismo blanco-sobre-dorado que
        // el botón (ver docstring de la clase). Con `onPrimary` ya corregido
        // este `checkColor` es en la práctica el mismo valor, pero se deja
        // explícito para que no vuelva a depender de una herencia implícita.
        checkColor: WidgetStateProperty.all(AppColores.principal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
