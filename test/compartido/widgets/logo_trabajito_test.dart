import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/logo_trabajito.dart';
import 'package:trabajito/nucleo/tema/app_colores.dart';

/// Cubre el pedido explícito del dueño (tarea 039): la letra dorada de la
/// marca es la "i" de "Trabajito", no la "t". Antes de la 039 el split era
/// `'Trabaji' + 't'(dorado) + 'o'`; ahora es `'Trabaj' + 'i'(dorado) +
/// 'to'`. Se comprueba inspeccionando los `TextSpan` en vez de solo el texto
/// completo: es lo único que puede detectar que se movió el color a la letra
/// equivocada.
void main() {
  /// Recorre los `TextSpan` de un `RichText` y devuelve, en orden, los
  /// `(texto, esDorado)` de cada tramo.
  List<(String, bool)> tramos(RichText rich) {
    final raiz = rich.text as TextSpan;
    return raiz.children!
        .cast<TextSpan>()
        .map((s) => (s.text!, s.style?.color == AppColores.dorado))
        .toList();
  }

  testWidgets('LogoTextoSolo pinta la "i" de dorado, no la "t"',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogoTextoSolo())),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    expect(tramos(rich), [
      ('Trabaj', false),
      ('i', true),
      ('to', false),
    ]);
  });

  testWidgets('LogoTrabajito pinta la "i" de dorado, no la "t"',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogoTrabajito())),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    expect(tramos(rich), [
      ('Trabaj', false),
      ('i', true),
      ('to', false),
    ]);
  });
}
