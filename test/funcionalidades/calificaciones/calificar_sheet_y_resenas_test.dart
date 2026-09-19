// Tarea 052: la hoja de calificar y la sección de reseñas usan el servicio
// inyectado (API), no Firestore.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/modelos/publicacion.dart';
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/compartido/widgets/resenas.dart';
import 'package:trabajito/funcionalidades/calificaciones/pantallas/calificar_sheet.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/configuracion_api.dart';
import 'package:trabajito/nucleo/inyeccion/proveedores.dart';

import '../../api/ayudas_api.dart';

Future<EspiaHttp> _instalar(
    Future<http.Response> Function(http.Request) responder) async {
  final espia = EspiaHttp();
  final (cliente, _) = await clienteConSesion(
    clienteFalso(espia, responder),
    sesion: sesionDePrueba(),
  );
  ApiClient.fijarInstancia(cliente);
  addTearDown(() => ApiClient.fijarInstancia(null));
  return espia;
}

void main() {
  testWidgets('SeccionResenas lista lo que responde el servidor',
      (tester) async {
    final espia = await _instalar((p) async => respuestaJson([
          {
            'id': 'c-1',
            'trabajoId': 't-1',
            'autorId': 'a-1',
            'receptorId': 'r-1',
            'rolCalificado': 'TRABAJADOR',
            'estrellas': 5,
            'comentario': 'Muy puntual',
            'creadoEn': '2026-09-09T10:00:00Z',
          }
        ], 200));
    await tester.pumpWidget(MultiProvider(
      providers: proveedoresDeLaApp(),
      child: const MaterialApp(home: Scaffold(body: SeccionResenas(uid: 'r-1'))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Muy puntual'), findsOneWidget);
    expect(find.text('Anónimo'), findsOneWidget,
        reason: 'el backend aún no manda el nombre del autor');
    expect(espia.rutas.single, RutasApi.calificacionesDe('r-1'));
  });

  testWidgets('SeccionResenas no finge "sin reseñas" si la carga falla',
      (tester) async {
    await _instalar((p) async => respuestaError(500, 'boom'));
    await tester.pumpWidget(MultiProvider(
      providers: proveedoresDeLaApp(),
      child: const MaterialApp(home: Scaffold(body: SeccionResenas(uid: 'r-1'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar las reseñas.'), findsOneWidget);
    expect(find.text('Todavía no tiene reseñas.'), findsNothing);
  });

  testWidgets('la hoja envía POST con el id del trabajo y las estrellas',
      (tester) async {
    final espia = await _instalar((p) async => respuestaJson({
          'id': 'c-1',
          'trabajoId': 't-1',
          'estrellas': 3,
        }, 200));
    final pub = Publicacion.desdeJson(const {'id': 't-1'});
    final yo = Usuario.desdeJson(const {'id': 'a-1', 'rol': 'EMPLEADOR'});
    bool? resultado;

    await tester.pumpWidget(MultiProvider(
      providers: proveedoresDeLaApp(),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await mostrarCalificarSheet(context,
                    publicacion: pub,
                    calificador: yo,
                    paraUid: 'r-1',
                    paraNombre: 'Ana');
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_rounded).at(2)); // 3 estrellas
    await tester.pump();
    await tester.tap(find.text('Enviar calificación'));
    await tester.pumpAndSettle();

    final p = espia.ultimaA(RutasApi.calificaciones);
    expect(p.method, 'POST');
    final cuerpo = jsonDecode(p.body) as Map<String, dynamic>;
    expect(cuerpo['trabajoId'], 't-1');
    expect(cuerpo['estrellas'], 3);
    expect(resultado, isTrue);
  });
}
