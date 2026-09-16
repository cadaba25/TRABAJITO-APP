import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/boton_destructivo.dart';
import 'package:trabajito/nucleo/tema/app_colores.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('enseña el texto y dispara onPressed al tocar', (tester) async {
    var toques = 0;
    await tester.pumpWidget(envolver(
      BotonDestructivo(texto: 'Eliminar', onPressed: () => toques++),
    ));

    expect(find.text('Eliminar'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(toques, 1);
  });

  testWidgets('onPressed null no dispara nada al tocar', (tester) async {
    await tester.pumpWidget(envolver(
      const BotonDestructivo(texto: 'Eliminar', onPressed: null),
    ));

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets('usa AppColores.error como fondo', (tester) async {
    await tester.pumpWidget(envolver(
      BotonDestructivo(texto: 'Eliminar', onPressed: () {}),
    ));

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final fondo = boton.style?.backgroundColor?.resolve(const {});
    expect(fondo, AppColores.error);
  });
}
