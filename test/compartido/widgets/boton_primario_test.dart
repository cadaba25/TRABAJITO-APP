import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/boton_primario.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('enseña el texto cuando no está cargando', (tester) async {
    await tester.pumpWidget(envolver(
      BotonPrimario(texto: 'Continuar', onPressed: () {}),
    ));

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cargando: true cambia el contenido a un spinner y no dispara onPressed',
      (tester) async {
    var tocado = false;
    await tester.pumpWidget(envolver(
      BotonPrimario(
        texto: 'Continuar',
        cargando: true,
        onPressed: () => tocado = true,
      ),
    ));

    expect(find.text('Continuar'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(tocado, isFalse);
  });

  testWidgets('onPressed null no dispara nada al tocar', (tester) async {
    await tester.pumpWidget(envolver(
      const BotonPrimario(texto: 'Continuar', onPressed: null),
    ));

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets('con icono enseña texto e icono juntos', (tester) async {
    await tester.pumpWidget(envolver(
      BotonPrimario(texto: 'Guardar', icono: Icons.save, onPressed: () {}),
    ));

    expect(find.text('Guardar'), findsOneWidget);
    expect(find.byIcon(Icons.save), findsOneWidget);
  });
}
