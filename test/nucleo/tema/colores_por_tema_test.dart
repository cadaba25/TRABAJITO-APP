import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/nucleo/tema/app_colores.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';
import 'package:trabajito/nucleo/tema/colores_por_tema.dart';

/// Contraste WCAG 2.x, calculado a mano — mismo criterio que
/// `test/nucleo/tema/app_tema_test.dart` (ADR-0016, tarea 031).
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

/// Primer test de `colores_por_tema.dart` (no tenía ninguno). Cubre los
/// cuatro roles que ya existían, los dos que añadió la tarea 031
/// (ADR-0016): `colorSuperficieAlterna` y `colorDeshabilitado`, y
/// `colorPrecio` de la tarea 034.
void main() {
  Future<BuildContext> construirContexto(WidgetTester tester, {required bool oscuro}) async {
    late BuildContext capturado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTema.temaClaro(),
        darkTheme: AppTema.temaOscuro(),
        themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
        home: Builder(
          builder: (context) {
            capturado = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    // Material 3 anima el cambio de tema con `AnimatedTheme`: sin dejar que
    // termine, `Theme.of(context).brightness` puede seguir reportando el
    // tema anterior justo tras el `pumpWidget` (comprobado a propósito: sin
    // este `pumpAndSettle` el segundo tema de un mismo test "no cambia").
    await tester.pumpAndSettle();
    return capturado;
  }

  testWidgets('los roles existentes cambian entre tema claro y oscuro', (tester) async {
    final claro = await construirContexto(tester, oscuro: false);
    expect(colorTextoFuerte(claro), AppColores.azulOscuro);
    expect(colorTextoSuave(claro), AppColores.grisTexto);
    expect(colorSuperficie(claro), AppColores.blanco);
    expect(colorBorde(claro), AppColores.grisClaro);

    final oscuro = await construirContexto(tester, oscuro: true);
    expect(colorTextoFuerte(oscuro), AppColores.textoOscuro);
    expect(colorTextoSuave(oscuro), AppColores.grisMedio);
    expect(colorSuperficie(oscuro), AppColores.superficieOscura);
    expect(colorBorde(oscuro), AppColores.bordeOscuro);
  });

  testWidgets('colorDeshabilitado coincide hoy con colorBorde en ambos temas', (tester) async {
    final claro = await construirContexto(tester, oscuro: false);
    expect(colorDeshabilitado(claro), colorBorde(claro));

    final oscuro = await construirContexto(tester, oscuro: true);
    expect(colorDeshabilitado(oscuro), colorBorde(oscuro));
  });

  testWidgets('colorSuperficieAlterna se distingue de colorSuperficie en ambos temas', (
    tester,
  ) async {
    final claro = await construirContexto(tester, oscuro: false);
    expect(colorSuperficieAlterna(claro), AppColores.grisClaro);
    expect(colorSuperficieAlterna(claro), isNot(colorSuperficie(claro)));

    final oscuro = await construirContexto(tester, oscuro: true);
    expect(colorSuperficieAlterna(oscuro), isNot(colorSuperficie(oscuro)));
  });

  testWidgets('colorPrecio cumple WCAG AA sobre colorSuperficie en ambos temas (tarea 034)', (
    tester,
  ) async {
    // El defecto real que encontró la 034: `AppColores.acento` (dorado)
    // directo como texto sobre blanco da ~1.63:1 — se rompe la prueba a
    // propósito cambiando `colorPrecio` por `AppColores.acento` para
    // confirmar que este test lo habría cazado.
    final claro = await construirContexto(tester, oscuro: false);
    expect(_contraste(AppColores.acento, colorSuperficie(claro)), lessThan(4.5),
        reason: 'el dorado sin ajustar sigue fallando AA sobre blanco: '
            'si esto deja de ser cierto, revisa que el ejemplo del comentario siga vigente');
    expect(_contraste(colorPrecio(claro), colorSuperficie(claro)), greaterThanOrEqualTo(4.5));
    expect(colorPrecio(claro), AppColores.doradoTexto);

    final oscuro = await construirContexto(tester, oscuro: true);
    // En oscuro la superficie ya es oscura: el dorado sin ajustar sí pasa,
    // por eso `colorPrecio` lo deja igual en vez de oscurecerlo también.
    expect(_contraste(AppColores.acento, colorSuperficie(oscuro)), greaterThanOrEqualTo(4.5));
    expect(colorPrecio(oscuro), AppColores.acento);
  });
}
