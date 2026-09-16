// Tarea 027 B-2b: `TarjetaTrabajo` salió de `trabajos_tab.dart`. Su lógica de
// presentación no trivial: los chips de categoría/plazo y la rama del botón
// según el rol y si el trabajador ya se postuló.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/modelos/publicacion.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/tarjeta_trabajo.dart';

Publicacion pub() => Publicacion(
      uidEmpleador: 'e',
      autor: 'Marta',
      categoria: 'Construccion',
      titulo: 'Pintar sala',
      descripcion: 'Dos paredes',
      ciudad: 'Tegucigalpa',
      departamento: 'Francisco Morazan',
      presupuesto: 'L. 1200',
      plazo: 'Corto plazo',
      fechaCreacion: DateTime(2026, 9, 4),
    );

Future<void> montar(
  WidgetTester tester, {
  required bool esEmpleador,
  required bool yaPostulado,
  VoidCallback? onAbrir,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TarjetaTrabajo(
          publicacion: pub(),
          oscuro: false,
          esEmpleador: esEmpleador,
          yaPostulado: yaPostulado,
          onAbrir: onAbrir ?? () {},
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('trabajador que no se ha postulado: botón "Postularme"',
      (tester) async {
    await montar(tester, esEmpleador: false, yaPostulado: false);

    expect(find.text('Postularme'), findsOneWidget);
    expect(find.text('Ya te postulaste'), findsNothing);
    expect(find.text('Construccion'), findsOneWidget);
    expect(find.text('Corto plazo'), findsOneWidget);
  });

  testWidgets('trabajador ya postulado: botón "Ya te postulaste"',
      (tester) async {
    await montar(tester, esEmpleador: false, yaPostulado: true);

    expect(find.text('Ya te postulaste'), findsOneWidget);
    expect(find.text('Postularme'), findsNothing);
  });

  testWidgets('empleador: botón "Ver detalles" y nunca "Postularme"',
      (tester) async {
    await montar(tester, esEmpleador: true, yaPostulado: true);

    expect(find.text('Ver detalles'), findsOneWidget);
    expect(find.text('Postularme'), findsNothing);
    expect(find.text('Ya te postulaste'), findsNothing);
  });

  testWidgets('tocar la tarjeta dispara onAbrir', (tester) async {
    var llamado = false;
    await montar(tester,
        esEmpleador: false, yaPostulado: false, onAbrir: () => llamado = true);

    await tester.tap(find.text('Pintar sala'));
    expect(llamado, isTrue);
  });

  // El botón es la vía real por la que el trabajador entra a postularse; que
  // esté cableado a onAbrir importa tanto como su texto.
  testWidgets('el botón "Postularme" dispara onAbrir', (tester) async {
    var llamado = false;
    await montar(tester,
        esEmpleador: false, yaPostulado: false, onAbrir: () => llamado = true);

    await tester.tap(find.text('Postularme'));
    expect(llamado, isTrue);
  });

  testWidgets('el botón "Ya te postulaste" dispara onAbrir', (tester) async {
    var llamado = false;
    await montar(tester,
        esEmpleador: false, yaPostulado: true, onAbrir: () => llamado = true);

    await tester.tap(find.text('Ya te postulaste'));
    expect(llamado, isTrue);
  });

  testWidgets('el botón "Ver detalles" del empleador dispara onAbrir',
      (tester) async {
    var llamado = false;
    await montar(tester,
        esEmpleador: true, yaPostulado: false, onAbrir: () => llamado = true);

    await tester.tap(find.text('Ver detalles'));
    expect(llamado, isTrue);
  });
}
