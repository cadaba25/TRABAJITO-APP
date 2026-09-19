import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/boton_icono.dart';
import 'package:trabajito/nucleo/tema/app_colores.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('el Tooltip envuelve el ícono con el texto pasado', (tester) async {
    await tester.pumpWidget(envolver(
      BotonIcono(icono: Icons.settings, onPressed: () {}, tooltip: 'Configuración'),
    ));

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Configuración');
    expect(
      find.descendant(of: find.byType(Tooltip), matching: find.byIcon(Icons.settings)),
      findsOneWidget,
    );
  });

  testWidgets('dispara onPressed al tocar', (tester) async {
    var toques = 0;
    await tester.pumpWidget(envolver(
      BotonIcono(icono: Icons.refresh, onPressed: () => toques++, tooltip: 'Actualizar'),
    ));

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(toques, 1);
  });

  testWidgets('tiene un área táctil mínima de 48x48', (tester) async {
    await tester.pumpWidget(envolver(
      BotonIcono(icono: Icons.refresh, onPressed: () {}, tooltip: 'Actualizar'),
    ));

    final boton = tester.widget<IconButton>(find.byType(IconButton));
    expect(boton.constraints?.minWidth, 48);
    expect(boton.constraints?.minHeight, 48);
  });

  testWidgets('seleccionado: true pinta el ícono con AppColores.acento', (tester) async {
    await tester.pumpWidget(envolver(
      BotonIcono(
        icono: Icons.tune,
        onPressed: () {},
        tooltip: 'Filtros',
        seleccionado: true,
      ),
    ));

    final icono = tester.widget<Icon>(find.byIcon(Icons.tune));
    expect(icono.color, AppColores.acento);
  });
}
