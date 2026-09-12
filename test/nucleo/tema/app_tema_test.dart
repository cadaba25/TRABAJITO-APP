import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/nucleo/tema/app_colores.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

/// Contraste WCAG 2.x, calculado a mano (no hay lector de contraste en el
/// repo — mismo criterio que documenta ADR-0016 y el docstring de `AppTema`).
double _canalLineal(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminancia(Color color) =>
    0.2126 * _canalLineal(color.r) + 0.7152 * _canalLineal(color.g) + 0.0722 * _canalLineal(color.b);

double _contraste(Color a, Color b) {
  final la = _luminancia(a);
  final lb = _luminancia(b);
  final claro = math.max(la, lb);
  final oscuro = math.min(la, lb);
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Cubre ADR-0016 (tarea 031): el arreglo de contraste del modo oscuro.
/// Antes de esta tarea, `blanco` sobre `acento` daba ~1.63:1 (falla WCAG AA,
/// mínimo 4.5:1 para texto normal). Estos tests fijan el par correcto y se
/// ponen rojos si alguien vuelve a poner blanco sobre el dorado de acento.
void main() {
  test('el par viejo (blanco sobre acento) sigue confirmado por debajo de AA', () {
    // No se usa en ningún sitio ya, pero deja registrado el defecto que
    // motivó el arreglo: si esto deja de ser cierto, la auditoría de
    // ADR-0016 estaba mal y el arreglo no hacía falta.
    expect(_contraste(AppColores.blanco, AppColores.acento), lessThan(4.5));
  });

  test('AppColores.principal sobre AppColores.acento sí cumple WCAG AA', () {
    final contraste = _contraste(AppColores.principal, AppColores.acento);
    expect(contraste, greaterThanOrEqualTo(4.5));
  });

  group('temaOscuro() ya no pone texto blanco sobre el dorado de acento', () {
    final tema = AppTema.temaOscuro();

    test('colorScheme.onPrimary cumple AA sobre colorScheme.primary', () {
      expect(tema.colorScheme.primary, AppColores.acento);
      expect(tema.colorScheme.onPrimary, isNot(AppColores.blanco));
      expect(
        _contraste(tema.colorScheme.onPrimary, tema.colorScheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('colorScheme.onSecondary cumple AA sobre colorScheme.secondary (mismo par)', () {
      expect(tema.colorScheme.secondary, AppColores.acento);
      expect(
        _contraste(tema.colorScheme.onSecondary, tema.colorScheme.secondary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('el botón primario ya no usa foregroundColor blanco', () {
      final estilo = tema.elevatedButtonTheme.style!;
      final color = estilo.foregroundColor?.resolve({});
      expect(color, isNot(AppColores.blanco));
      expect(_contraste(color!, AppColores.acento), greaterThanOrEqualTo(4.5));
    });

    test('el check del checkbox seleccionado cumple AA sobre su relleno', () {
      final checkColor = tema.checkboxTheme.checkColor?.resolve({WidgetState.selected});
      final fillColor = tema.checkboxTheme.fillColor?.resolve({WidgetState.selected});
      expect(checkColor, isNotNull);
      expect(fillColor, isNotNull);
      expect(_contraste(checkColor!, fillColor!), greaterThanOrEqualTo(4.5));
    });
  });

  test('temaClaro() no tenía el defecto y no cambió: onPrimary sigue blanco sobre el marino', () {
    final tema = AppTema.temaClaro();
    expect(tema.colorScheme.onPrimary, AppColores.blanco);
    expect(
      _contraste(tema.colorScheme.onPrimary, tema.colorScheme.primary),
      greaterThanOrEqualTo(4.5),
    );
  });
}
