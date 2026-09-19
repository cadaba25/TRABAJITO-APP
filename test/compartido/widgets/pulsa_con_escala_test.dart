import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/pulsa_con_escala.dart';

/// Cubre ADR-0015 punto 2: feedback al tacto en lo que hoy usa
/// `GestureDetector` desnudo, y punto 5: respeta
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

  testWidgets('al mantener pulsada la tarjeta, su escala baja a 0.97',
      (tester) async {
    await tester.pumpWidget(
      envolver(
        PulsaConEscala(
          onTap: () {},
          child: const SizedBox(width: 100, height: 100, key: Key('hijo')),
        ),
      ),
    );

    final gesto = await tester.startGesture(tester.getCenter(find.byType(PulsaConEscala)));
    await tester.pump();

    final escala = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(escala.scale, 0.97);

    await gesto.up();
    await tester.pumpAndSettle();

    final escalaFinal = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(escalaFinal.scale, 1.0);
  });

  testWidgets(
      'con disableAnimations la escala no baja, pero onTap se dispara igual',
      (tester) async {
    var toques = 0;
    await tester.pumpWidget(
      envolver(
        PulsaConEscala(
          onTap: () => toques++,
          child: const SizedBox(width: 100, height: 100),
        ),
        disableAnimations: true,
      ),
    );

    final gesto = await tester.startGesture(tester.getCenter(find.byType(PulsaConEscala)));
    await tester.pump();

    // La escala sigue bajando internamente (es el mismo AnimatedScale), pero
    // la duración pasa por movimiento_accesible y queda en cero: no hay
    // animación visible, es instantánea.
    final escala = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(escala.duration, Duration.zero);

    await gesto.up();
    await tester.pumpAndSettle();

    expect(toques, 1);
  });

  testWidgets('onTap se dispara con un toque simple sin disableAnimations',
      (tester) async {
    var toques = 0;
    await tester.pumpWidget(
      envolver(
        PulsaConEscala(
          onTap: () => toques++,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );

    await tester.tap(find.byType(PulsaConEscala));
    await tester.pumpAndSettle();

    expect(toques, 1);
  });
}
