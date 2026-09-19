import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/boton_secundario.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('enseña el texto y dispara onPressed al tocar', (tester) async {
    var toques = 0;
    await tester.pumpWidget(envolver(
      BotonSecundario(texto: 'Ver detalles', onPressed: () => toques++),
    ));

    expect(find.text('Ver detalles'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(toques, 1);
  });

  testWidgets('onPressed null no dispara nada al tocar', (tester) async {
    await tester.pumpWidget(envolver(
      const BotonSecundario(texto: 'Ver detalles', onPressed: null),
    ));

    final boton = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets(
      'cargando: true reemplaza el texto por un spinner y no dispara onPressed',
      (tester) async {
    var tocado = false;
    await tester.pumpWidget(envolver(
      BotonSecundario(
        texto: 'Ver detalles',
        cargando: true,
        onPressed: () => tocado = true,
      ),
    ));

    expect(find.text('Ver detalles'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton), warnIfMissed: false);
    await tester.pump();
    expect(tocado, isFalse);
  });
}
