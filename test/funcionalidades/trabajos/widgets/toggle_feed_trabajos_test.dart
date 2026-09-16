import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/toggle_feed_trabajos.dart';

/// Cubre ADR-0015 fase 5: el toggle "Trabajos"/"Mis publicaciones" cambia de
/// color con un `AnimatedContainer`, no un corte seco.
void main() {
  testWidgets('usa AnimatedContainer y dispara onCambia con el valor opuesto',
      (tester) async {
    bool? recibido;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ToggleFeedTrabajos(
            soloMias: false,
            onCambia: (v) => recibido = v,
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedContainer), findsNWidgets(2));

    await tester.tap(find.text('Mis publicaciones'));
    await tester.pumpAndSettle();

    expect(recibido, isTrue);
  });
}
