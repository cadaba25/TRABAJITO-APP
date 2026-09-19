import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/estado_pantalla.dart';
import 'package:trabajito/funcionalidades/postulaciones/pantallas/widgets/estados_postulantes.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/estados_mis_publicaciones.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

Future<void> montar(WidgetTester t, Widget w, {bool oscuro = false}) =>
    t.pumpWidget(MaterialApp(
      theme: oscuro ? AppTema.temaOscuro() : AppTema.temaClaro(),
      home: Scaffold(body: w),
    ));

void main() {
  for (final oscuro in [false, true]) {
    testWidgets('EstadoPantalla muestra mensaje, detalle y CTA (oscuro=$oscuro)',
        (t) async {
      var toques = 0;
      await montar(
          t,
          EstadoPantalla(
            icono: Icons.inbox,
            mensaje: 'Nada por aquí',
            detalle: 'Prueba luego',
            etiquetaAccion: 'Hacer algo',
            onAccion: () => toques++,
          ),
          oscuro: oscuro);
      expect(find.text('Nada por aquí'), findsOneWidget);
      expect(find.text('Prueba luego'), findsOneWidget);
      await t.tap(find.text('Hacer algo'));
      expect(toques, 1);
    });
  }

  testWidgets('EstadoPantalla sin acción no dibuja botón', (t) async {
    await montar(t, const EstadoPantalla(icono: Icons.inbox, mensaje: 'Vacío'));
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('Mis publicaciones vacío ofrece publicar; error ofrece reintentar',
      (t) async {
    var publicar = 0, reintentar = 0;
    await montar(t,
        EstadoVacioMisPublicaciones(oscuro: false, onPublicar: () => publicar++));
    await t.tap(find.text('Publicar un trabajo'));
    expect(publicar, 1);

    await montar(
        t,
        EstadoErrorMisPublicaciones(
            error: 'x', oscuro: false, onReintentar: () => reintentar++));
    await t.tap(find.text('Reintentar'));
    expect(reintentar, 1);
  });

  testWidgets('Postulantes: vacío explica qué pasará; error reintenta', (t) async {
    var reintentar = 0;
    await montar(t, const EstadoVacioPostulantes(oscuro: false));
    expect(find.textContaining('aparecerá aquí'), findsOneWidget);
    await montar(t,
        EstadoErrorPostulantes(error: 'x', oscuro: true, onReintentar: () => reintentar++));
    await t.tap(find.text('Reintentar'));
    expect(reintentar, 1);
  });
}
