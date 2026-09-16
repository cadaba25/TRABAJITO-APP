import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/barra_busqueda_trabajos.dart';

/// Cubre ADR-0015 fase 5: el chip de plazo seleccionado cambia de color con
/// un `AnimatedContainer`, no un corte seco.
void main() {
  Widget montar({String plazoActivo = ''}) {
    return MaterialApp(
      home: Scaffold(
        body: BarraBusquedaTrabajos(
          oscuro: false,
          filtrosActivos: false,
          plazoActivo: plazoActivo,
          onBusquedaCambia: (_) {},
          onPlazoCambia: (_) {},
          onAbrirFiltros: () {},
        ),
      ),
    );
  }

  testWidgets('el chip "Todos" usa AnimatedContainer para su color de fondo',
      (tester) async {
    await tester.pumpWidget(montar());

    expect(find.byType(AnimatedContainer), findsWidgets);
    expect(find.text('Todos'), findsOneWidget);
  });

  testWidgets('pulsar un chip de plazo dispara el callback con su valor',
      (tester) async {
    String? recibido;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarraBusquedaTrabajos(
            oscuro: false,
            filtrosActivos: false,
            plazoActivo: '',
            onBusquedaCambia: (_) {},
            onPlazoCambia: (v) => recibido = v,
            onAbrirFiltros: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();

    expect(recibido, '');
  });
}
