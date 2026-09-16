// Generador de la captura del logo (`LogoTrabajito`) para el reporte de la
// tarea 039 (letra dorada movida de la segunda "t" a la "i", pedido
// explícito del dueño). NO es un test de regresión: no hace ningún
// `expect`, solo monta el widget real y guarda un PNG real
// (`RenderRepaintBoundary.toImage()`) en `docs/agent-reports/capturas/`,
// mismo patrón que `test/manual/generar_capturas_*.dart` de las tareas
// 033-036.
//
// "Antes"/"después": este archivo captura siempre el código tal cual está
// en el árbol de trabajo. La captura "antes" de esta tarea se generó
// corriendo este mismo archivo con `git stash push -- lib/compartido/widgets/logo_trabajito.dart`
// aplicado, y la "después" tras `git stash pop`.
//
// No se nombra `*_test.dart` a propósito: `flutter test` (sin argumentos)
// no lo descubre ni lo ejecuta. Se invoca a mano:
//   flutter test test/manual/generar_capturas_logo.dart
//   flutter test test/manual/generar_capturas_logo.dart --dart-define=SUFIJO=antes
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/logo_trabajito.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

const _carpeta = 'docs/agent-reports/capturas';

const String _sufijo = String.fromEnvironment('SUFIJO', defaultValue: 'despues');

Future<void> _capturar(
  WidgetTester tester, {
  required bool oscuro,
}) async {
  final boundaryKey = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(320, 140));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTema.temaClaro(),
      darkTheme: AppTema.temaOscuro(),
      themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: LogoTrabajito(altura: 48),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final imagen = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final sufijoTema = oscuro ? 'oscuro' : 'claro';
    final archivo = File('$_carpeta/039-logo-$_sufijo-$sufijoTema.png');
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

  testWidgets('captura el logo claro/oscuro', (tester) async {
    for (final oscuro in [false, true]) {
      await _capturar(tester, oscuro: oscuro);
    }
  });
}
