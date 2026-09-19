import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/boton_texto.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('enseña el texto y dispara onPressed al tocar', (tester) async {
    var toques = 0;
    await tester.pumpWidget(envolver(
      BotonTexto(texto: 'Cancelar', onPressed: () => toques++),
    ));

    expect(find.text('Cancelar'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(toques, 1);
  });

  testWidgets('respeta el alto mínimo de 48', (tester) async {
    await tester.pumpWidget(envolver(
      BotonTexto(texto: 'Cancelar', onPressed: () {}),
    ));

    final boton = tester.widget<TextButton>(find.byType(TextButton));
    final minimo = boton.style?.minimumSize?.resolve(const {});
    expect(minimo?.height, 48);
  });

  testWidgets('con icono lo enseña junto al texto', (tester) async {
    await tester.pumpWidget(envolver(
      BotonTexto(texto: 'Eliminar', icono: Icons.delete, onPressed: () {}),
    ));

    expect(find.text('Eliminar'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });
}
