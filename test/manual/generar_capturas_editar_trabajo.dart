// Capturas reales de `EditarTrabajoScreen` para el reporte de la tarea 041,
// claro/oscuro — mismo patrón que `generar_capturas_trabajos.dart` (034): no
// hay emulador libre en este entorno (sin `adb`), así que se monta la
// pantalla real con `PublicacionService` real sobre un `MockClient` en
// memoria y se guarda un PNG con `RenderRepaintBoundary.toImage`. NO es un
// test de regresión (sin `expect`) y no se nombra `*_test.dart` a propósito:
// se invoca a mano con
//   flutter test test/manual/generar_capturas_editar_trabajo.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/modelos/publicacion.dart';
import 'package:trabajito/funcionalidades/trabajos/datos/publicacion_service.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/editar_trabajo_screen.dart';
import 'package:trabajito/nucleo/api/almacen_sesion.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/sesion_api.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

const _carpeta = 'docs/agent-reports/capturas';

Publicacion _publicacion() => Publicacion(
      id: 'trabajo-1',
      uidEmpleador: 'emp-1',
      autor: 'Marta Contratista',
      categoria: 'Plomería',
      titulo: 'Reparar tubería',
      descripcion: 'Fuga en la cocina, urge antes del fin de semana.',
      departamento: 'Cortés',
      ciudad: 'San Pedro Sula',
      zona: 'Centro',
      presupuesto: 'L. 500/hora',
      plazo: 'Corto plazo',
      fechaCreacion: DateTime(2026, 9, 4),
    );

Future<PublicacionService> _servicio() async {
  final mock = MockClient((_) async =>
      http.Response('{}', 200, headers: {'content-type': 'application/json'}));
  final almacen = AlmacenSesionEnMemoria();
  final cliente = ApiClient(
      clienteHttp: mock, almacen: almacen, urlBase: 'http://prueba.local:8080');
  await cliente.guardarSesion(SesionApi(
    token: 't',
    refreshToken: 'r',
    expiraEn: DateTime.now().add(const Duration(minutes: 15)),
    usuario: const {'correo': 'prueba@trabajito.test'},
  ));
  return PublicacionService(cliente: cliente);
}

Future<void> _capturar(WidgetTester tester,
    {required PublicacionService pub, required bool oscuro}) async {
  final boundaryKey = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(420, 900));
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<PublicacionService>.value(value: pub)],
      child: MaterialApp(
        theme: AppTema.temaClaro(),
        darkTheme: AppTema.temaOscuro(),
        themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
        home: RepaintBoundary(
          key: boundaryKey,
          child: EditarTrabajoScreen(publicacion: _publicacion()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final imagen = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final sufijoTema = oscuro ? 'oscuro' : 'claro';
    final archivo = File('$_carpeta/041-editar-trabajo-$sufijoTema.png');
    archivo.parent.createSync(recursive: true);
    archivo.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final cargador = FontLoader('Sora')..addFont(rootBundle.load('assets/fonts/Sora.ttf'));
    await cargador.load();
  });

  testWidgets('captura EditarTrabajoScreen prellenada, claro y oscuro',
      (tester) async {
    for (final oscuro in [false, true]) {
      final pub = await _servicio();
      await _capturar(tester, pub: pub, oscuro: oscuro);
    }
  });
}
