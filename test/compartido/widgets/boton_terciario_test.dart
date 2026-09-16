import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/boton_terciario.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('enseña el texto y dispara onPressed al tocar', (tester) async {
    var toques = 0;
    await tester.pumpWidget(envolver(
      BotonTerciario(texto: 'Ver más', onPressed: () => toques++),
    ));

    expect(find.text('Ver más'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(toques, 1);
  });

  testWidgets('onPressed null deja el botón desactivado', (tester) async {
    await tester.pumpWidget(envolver(
      const BotonTerciario(texto: 'Ver más', onPressed: null),
    ));

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.onPressed, isNull);
  });
}
