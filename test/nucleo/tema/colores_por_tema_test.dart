import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/nucleo/tema/app_colores.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';
import 'package:trabajito/nucleo/tema/colores_por_tema.dart';

/// Primer test de `colores_por_tema.dart` (no tenía ninguno). Cubre los
/// cuatro roles que ya existían y los dos que añadió la tarea 031
/// (ADR-0016): `colorSuperficieAlterna` y `colorDeshabilitado`.
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
}
