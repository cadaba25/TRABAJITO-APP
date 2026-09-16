// Tarea 027 B-2b: `TarjetaPostulante` salió de `postulantes_screen.dart`.
// Ramas de presentación que conviene fijar: el badge de estado de la
// postulación, el check + marco del elegido, y el botón "Seleccionar" que solo
// aparece con el trabajo activo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/modelos/postulacion.dart';
import 'package:trabajito/compartido/modelos/publicacion.dart';
import 'package:trabajito/funcionalidades/postulaciones/pantallas/widgets/tarjeta_postulante.dart';
import 'package:trabajito/nucleo/dominio/estados.dart';

Publicacion pub({
  String estado = EstadosTrabajo.activo,
  String uidAsignado = '',
}) =>
    Publicacion(
      uidEmpleador: 'e',
      autor: 'Emp',
      categoria: 'c',
      titulo: 'Pintar sala',
      descripcion: 'd',
      estado: estado,
      uidTrabajadorAsignado: uidAsignado,
      fechaCreacion: DateTime(2026, 9, 4),
    );

Postulacion postulante({
  String estado = EstadosPostulacion.pendiente,
  String mensaje = 'Puedo empezar mañana',
}) =>
    Postulacion(
      id: 'p1',
      idPublicacion: 'abc',
      uidTrabajador: 't1',
      nombreTrabajador: 'Carlos Demo',
      uidEmpleador: 'e',
      mensaje: mensaje,
      estado: estado,
      fechaPostulacion: DateTime(2026, 9, 4),
    );

Future<void> montar(
  WidgetTester tester, {
  required Publicacion publicacion,
  required Postulacion postulacion,
  VoidCallback? onSeleccionar,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TarjetaPostulante(
          publicacion: publicacion,
          postulacion: postulacion,
          oscuro: false,
          onVerPerfil: () {},
          onSeleccionar: onSeleccionar ?? () {},
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('trabajo activo: sale "Seleccionar" y el badge Pendiente',
      (tester) async {
    await montar(tester, publicacion: pub(), postulacion: postulante());

    expect(find.text('Seleccionar'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('trabajo ya asignado a otro: sin botón "Seleccionar"',
      (tester) async {
    await montar(
      tester,
      publicacion: pub(estado: EstadosTrabajo.asignado, uidAsignado: 'otro'),
      postulacion: postulante(estado: EstadosPostulacion.rechazada),
    );

    expect(find.text('Seleccionar'), findsNothing);
    expect(find.text('Rechazada'), findsOneWidget);
  });

  testWidgets('el postulante elegido muestra el check y no el badge',
      (tester) async {
    await montar(
      tester,
      publicacion: pub(estado: EstadosTrabajo.acordado, uidAsignado: 't1'),
      postulacion: postulante(estado: EstadosPostulacion.aceptada),
    );

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Aceptada'), findsNothing);
  });

  testWidgets('sin mensaje, se invita a revisar el perfil', (tester) async {
    await montar(tester,
        publicacion: pub(), postulacion: postulante(mensaje: ''));

    expect(find.textContaining('No dejó un mensaje'), findsOneWidget);
  });

  testWidgets('pulsar "Seleccionar" dispara el callback', (tester) async {
    var llamado = false;
    await montar(tester,
        publicacion: pub(),
        postulacion: postulante(),
        onSeleccionar: () => llamado = true);

    await tester.tap(find.text('Seleccionar'));
    expect(llamado, isTrue);
  });
}
