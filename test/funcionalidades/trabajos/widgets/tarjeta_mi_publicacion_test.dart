// Tarea 027 B-2b: `TarjetaMiPublicacion` salió de `mis_publicaciones_screen.dart`.
// Su única lógica de presentación no trivial son dos ramas según el estado del
// trabajo: la etiqueta real del badge (ADR-0007) y si el botón "Cerrar" sigue
// disponible.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/modelos/publicacion.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/tarjeta_mi_publicacion.dart';
import 'package:trabajito/nucleo/dominio/estados.dart';

Publicacion pub({required String estado}) => Publicacion(
      uidEmpleador: 'e',
      autor: 'Emp',
      categoria: 'Construccion',
      titulo: 'Pintar sala',
      descripcion: 'Dos paredes',
      presupuesto: 'L. 1200',
      estado: estado,
      fechaCreacion: DateTime(2026, 9, 4),
    );

Future<void> montar(WidgetTester tester, Publicacion p,
    {VoidCallback? onCerrar}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TarjetaMiPublicacion(
          publicacion: p,
          oscuro: false,
          onAbrir: () {},
          onCerrar: onCerrar ?? () {},
          onEliminar: () {},
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('un trabajo activo muestra su etiqueta y deja cerrarlo',
      (tester) async {
    await montar(tester, pub(estado: EstadosTrabajo.activo));

    expect(find.text(EstadosTrabajo.etiqueta(EstadosTrabajo.activo)),
        findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);
    expect(find.text('Ya no se puede cerrar'), findsNothing);

    final boton = tester.widget<TextButton>(
      find.ancestor(
          of: find.text('Cerrar'), matching: find.byType(TextButton)),
    );
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('un trabajo en progreso ya no se puede cerrar', (tester) async {
    await montar(tester, pub(estado: EstadosTrabajo.enProgreso));

    expect(find.text('Ya no se puede cerrar'), findsOneWidget);
    expect(find.text('Cerrar'), findsNothing);

    final boton = tester.widget<TextButton>(
      find.ancestor(
          of: find.text('Ya no se puede cerrar'),
          matching: find.byType(TextButton)),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('pulsar "Cerrar" dispara el callback', (tester) async {
    var llamado = false;
    await montar(tester, pub(estado: EstadosTrabajo.activo),
        onCerrar: () => llamado = true);

    await tester.tap(find.text('Cerrar'));
    expect(llamado, isTrue);
  });
}
