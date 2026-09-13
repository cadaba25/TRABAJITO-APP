import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trabajito/compartido/widgets/estado_exito.dart';

/// Cubre ADR-0015 fase 6: el check de éxito entra con escalado y respeta
/// `MediaQuery.disableAnimations`.
void main() {
  Widget envolver(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('enseña el mensaje y el check llega a su escala final',
      (tester) async {
    await tester.pumpWidget(
      envolver(const EstadoExito(mensaje: '¡Listo!')),
    );

    expect(find.text('¡Listo!'), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);

    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(find.descendant(
      of: find.byType(EstadoExito),
      matching: find.byType(Transform),
    ));
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.001));
  });

  testWidgets('con disableAnimations aparece ya en su tamaño final',
      (tester) async {
    await tester.pumpWidget(
      envolver(
        const EstadoExito(mensaje: '¡Listo!'),
        disableAnimations: true,
      ),
    );

    await tester.pump();

    final transform = tester.widget<Transform>(find.descendant(
      of: find.byType(EstadoExito),
      matching: find.byType(Transform),
    ));
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.001));
  });
}
