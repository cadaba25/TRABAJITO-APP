import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trabajito/compartido/widgets/estrellas.dart';
import 'package:trabajito/nucleo/tema/app_colores.dart';

/// Cubre un hallazgo de la tarea 043 (ADR-0017): a diferencia de Material,
/// Lucide no tiene una "estrella rellena" distinta de la vacía (es un set de
/// solo trazo). Sin distinguir por color, una calificación de 0 estrellas se
/// vería igual que una de 5. Este test fija que el color SÍ distingue
/// llena/media de vacía, para que nadie lo revierta sin darse cuenta.
void main() {
  testWidgets('estrella llena y vacía usan el mismo glifo pero distinto color',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Estrellas(valor: 2.5, total: 10, tamano: 20)),
      ),
    );

    final iconos = tester
        .widgetList<Icon>(find.descendant(
          of: find.byType(Estrellas),
          matching: find.byType(Icon),
        ))
        .toList();

    expect(iconos, hasLength(5));

    // Índices 0 y 1: llenas (doradas). Índice 2: media (dorada, starHalf).
    // Índices 3 y 4: vacías (gris).
    expect(iconos[0].color, AppColores.dorado);
    expect(iconos[0].icon, LucideIcons.star);
    expect(iconos[1].color, AppColores.dorado);
    expect(iconos[1].icon, LucideIcons.star);
    expect(iconos[2].color, AppColores.dorado);
    expect(iconos[2].icon, LucideIcons.starHalf);
    expect(iconos[3].color, AppColores.grisMedio);
    expect(iconos[3].icon, LucideIcons.star);
    expect(iconos[4].color, AppColores.grisMedio);
    expect(iconos[4].icon, LucideIcons.star);
  });

  testWidgets('sin calificaciones no dibuja estrellas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Estrellas(valor: 0, total: 0)),
      ),
    );

    expect(find.text('Sin calificaciones'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });
}
