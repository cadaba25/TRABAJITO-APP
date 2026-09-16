import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/nucleo/movimiento/app_movimiento.dart';
import 'package:trabajito/nucleo/movimiento/movimiento_accesible.dart';

/// Cubre ADR-0015 punto 5: ningún widget animado puede saltarse
/// `MediaQuery.disableAnimations`. Si `duracionMov`/`curvaMov` dejaran de
/// leerlo, estos tests se ponen rojos (comprobado a propósito rompiendo el
/// helper mientras se escribía este test).
void main() {
  const base = Duration(milliseconds: 240);
  const curvaBase = Curves.easeOutCubic;

  Future<BuildContext> construirContexto(
    WidgetTester tester, {
    required bool disableAnimations,
  }) async {
    late BuildContext capturado;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(
          builder: (context) {
            capturado = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return capturado;
  }

  testWidgets(
    'duracionMov devuelve Duration.zero cuando el sistema pide reducir movimiento',
    (tester) async {
      final context = await construirContexto(
        tester,
        disableAnimations: true,
      );

      expect(duracionMov(context, base), Duration.zero);
    },
  );

  testWidgets(
    'duracionMov devuelve la duración base cuando el sistema no pide reducir movimiento',
    (tester) async {
      final context = await construirContexto(
        tester,
        disableAnimations: false,
      );

      expect(duracionMov(context, base), base);
    },
  );

  testWidgets(
    'curvaMov devuelve un fundido simple cuando el sistema pide reducir movimiento',
    (tester) async {
      final context = await construirContexto(
        tester,
        disableAnimations: true,
      );

      expect(curvaMov(context, curvaBase), AppMovimiento.estandar);
    },
  );

  testWidgets(
    'curvaMov devuelve la curva base cuando el sistema no pide reducir movimiento',
    (tester) async {
      final context = await construirContexto(
        tester,
        disableAnimations: false,
      );

      expect(curvaMov(context, curvaBase), curvaBase);
    },
  );

  testWidgets(
    'prefiereMenosMovimiento refleja MediaQuery.disableAnimations',
    (tester) async {
      final conReduccion = await construirContexto(
        tester,
        disableAnimations: true,
      );
      expect(conReduccion.prefiereMenosMovimiento, isTrue);

      final sinReduccion = await construirContexto(
        tester,
        disableAnimations: false,
      );
      expect(sinReduccion.prefiereMenosMovimiento, isFalse);
    },
  );
}
