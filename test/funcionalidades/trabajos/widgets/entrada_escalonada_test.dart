import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/entrada_escalonada.dart';

/// Cubre ADR-0015 fase 4: stagger de la primera carga del feed. No depende
/// de tiempos frágiles: usa `pumpAndSettle` en vez de comprobar valores a
/// mitad de la animación.
void main() {
  Widget envolver(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    );
  }

  final opacidadDeEntrada = find.descendant(
    of: find.byType(EntradaEscalonada),
    matching: find.byType(Opacity),
  );

  testWidgets('tras asentarse, la tarjeta con índice alto queda visible',
      (tester) async {
    await tester.pumpWidget(
      envolver(
        const EntradaEscalonada(
          indice: 5,
          child: Text('tarjeta'),
        ),
      ),
    );

    // Antes de asentarse todavía no es del todo visible (retraso + fundido).
    expect(find.text('tarjeta'), findsOneWidget);
    final opacidadInicial = tester.widget<Opacity>(opacidadDeEntrada);
    expect(opacidadInicial.opacity, lessThan(1.0));

    await tester.pumpAndSettle();

    final opacidadFinal = tester.widget<Opacity>(opacidadDeEntrada);
    expect(opacidadFinal.opacity, 1.0);
  });

  testWidgets(
      'con disableAnimations la tarjeta aparece visible sin esperar nada, sin envoltorio',
      (tester) async {
    await tester.pumpWidget(
      envolver(
        const EntradaEscalonada(
          indice: 3,
          child: Text('tarjeta'),
        ),
        disableAnimations: true,
      ),
    );

    // Un solo pump (sin avanzar el tiempo): ya debe estar visible porque no
    // hay stagger ni animación con el sistema pidiendo reducir movimiento, y
    // ni siquiera se envuelve en `Opacity`.
    await tester.pump();

    expect(find.text('tarjeta'), findsOneWidget);
    expect(opacidadDeEntrada, findsNothing);
  });
}
