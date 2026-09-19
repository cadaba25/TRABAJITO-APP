// Generador de capturas para la tarea 043 (ADR-0017: iconografía Lucide,
// fase 0). NO es un test de regresión: no hace ningún `expect`, solo monta
// los widgets reales y guarda PNGs reales (`RenderRepaintBoundary.toImage()`)
// en `docs/agent-reports/capturas/`, mismo patrón que
// `test/manual/generar_capturas_*.dart` de las tareas 033-039.
//
// Cubre los dos widgets que pide el criterio de aceptación de la 043:
// `Estrellas`/`ResumenCalificacion` (de `estrellas.dart`/`resenas.dart`,
// rating con estrellas llena/media/vacía) y `mostrarSnackBar` (éxito y
// error).
//
// "Antes"/"después": este archivo captura siempre el código tal cual está
// en el árbol de trabajo. La captura "antes" de esta tarea se generó
// corriendo este mismo archivo con
//   git stash push -- lib/compartido/widgets/estrellas.dart lib/compartido/widgets/resenas.dart lib/compartido/widgets/mostrar_snackbar.dart
// aplicado (Icons.* de Material), y la "después" tras `git stash pop`
// (LucideIcons.*).
//
// No se nombra `*_test.dart` a propósito: `flutter test` (sin argumentos)
// no lo descubre ni lo ejecuta. Se invoca a mano:
//   flutter test test/manual/generar_capturas_iconografia_043.dart --dart-define=SUFIJO=antes
//   flutter test test/manual/generar_capturas_iconografia_043.dart --dart-define=SUFIJO=despues
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/estrellas.dart';
import 'package:trabajito/compartido/widgets/resenas.dart';
import 'package:trabajito/compartido/widgets/mostrar_snackbar.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

const _carpeta = 'docs/agent-reports/capturas';

const String _sufijo = String.fromEnvironment('SUFIJO', defaultValue: 'despues');

/// `flutter test` no carga NINGUNA fuente real por defecto (dibuja "tofu":
/// cuadrados) — ni las del SDK (MaterialIcons) ni las de un paquete
/// (Lucide) — a menos que se pidan explícitamente con [FontLoader], igual
/// que ya hacía este archivo con Sora. Sin esto, "antes" y "después" se ven
/// IGUALES (ambos en tofu) y la comparación no demuestra nada.
Future<void> _cargarFuenteDeArchivo(String familia, String rutaAbsoluta) async {
  final archivo = File(rutaAbsoluta);
  if (!archivo.existsSync()) {
    // No se quiere que este script (manual, de un solo uso) tumbe la
    // ejecución en otra máquina si las rutas no coinciden: se sigue sin esa
    // fuente y las capturas caen a "tofu", visible a simple vista.
    // ignore: avoid_print
    print('Aviso: no se encontró la fuente "$familia" en $rutaAbsoluta');
    return;
  }
  final cargador = FontLoader(familia)
    ..addFont(archivo.readAsBytes().then((b) => ByteData.view(
        b.buffer, b.offsetInBytes, b.lengthInBytes)));
  await cargador.load();
}

/// Busca la raíz del SDK de Flutter (para `MaterialIcons-Regular.otf`) sin
/// asumir una ruta fija: primero `FLUTTER_ROOT`, luego `where`/`which flutter`.
Future<String?> _raizFlutter() async {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && Directory(env).existsSync()) return env;
  try {
    final resultado = await Process.run(
        Platform.isWindows ? 'where' : 'which', const ['flutter']);
    final salida = (resultado.stdout as String).trim().split('\n').first.trim();
    if (salida.isEmpty) return null;
    // .../flutter/bin/flutter(.bat) -> dos niveles arriba es la raíz del SDK.
    return File(salida).parent.parent.path;
  } catch (_) {
    return null;
  }
}

/// Busca el `.ttf` de `lucide_icons_flutter` en la carpeta hosted de pub,
/// sin fijar la versión a mano (`PUB_CACHE` o el default de cada SO).
String? _fuenteLucide() {
  final base = Platform.environment['PUB_CACHE'] ??
      (Platform.isWindows
          ? '${Platform.environment['LOCALAPPDATA']}/Pub/Cache'
          : '${Platform.environment['HOME']}/.pub-cache');
  final hosted = Directory('$base/hosted/pub.dev');
  if (!hosted.existsSync()) return null;
  final carpeta = hosted
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.replaceAll('\\', '/'))
      .firstWhere(
        (p) => p.split('/').last.startsWith('lucide_icons_flutter-'),
        orElse: () => '',
      );
  if (carpeta.isEmpty) return null;
  return '$carpeta/assets/lucide.ttf';
}

Future<void> _guardar(GlobalKey boundaryKey, String nombre) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final imagen = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
  final archivo = File('$_carpeta/043-$nombre-$_sufijo.png');
  archivo.parent.createSync(recursive: true);
  archivo.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final cargador = FontLoader('Sora')
      ..addFont(rootBundle.load('assets/fonts/Sora.ttf'));
    await cargador.load();

    final raizFlutter = await _raizFlutter();
    if (raizFlutter != null) {
      await _cargarFuenteDeArchivo('MaterialIcons',
          '$raizFlutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    } else {
      // ignore: avoid_print
      print('Aviso: no se encontró la raíz de Flutter (FLUTTER_ROOT/where flutter).');
    }
    final fuenteLucide = _fuenteLucide();
    if (fuenteLucide != null) {
      // `LucideIcons.*` se define con `fontPackage: 'lucide_icons_flutter'`,
      // así que Flutter la busca como "packages/<paquete>/<familia>", no
      // como "Lucide" a secas (eso es lo que de verdad faltaba: el aviso de
      // "no encontró la fuente" nunca saltó porque el archivo SÍ se hallaba,
      // solo que bajo el nombre de familia equivocado no se habría notado
      // sin comparar el resultado visual).
      await _cargarFuenteDeArchivo(
          'packages/lucide_icons_flutter/Lucide', fuenteLucide);
    } else {
      // ignore: avoid_print
      print('Aviso: no se encontró lucide_icons_flutter en el pub cache.');
    }
  });

  testWidgets('captura Estrellas (llena/media/vacía) y ResumenCalificacion',
      (tester) async {
    final boundaryKey = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(360, 260));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTema.temaClaro(),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Estrellas(valor: 3.5, total: 12, tamano: 24),
                  SizedBox(height: 20),
                  Estrellas(valor: 5, total: 40, tamano: 24),
                  SizedBox(height: 20),
                  Estrellas(valor: 0, total: 0, tamano: 24),
                  SizedBox(height: 24),
                  ResumenCalificacion(valor: 4.2, total: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() => _guardar(boundaryKey, 'estrellas-resenas'));
  });

  Future<void> capturarSnackBar(WidgetTester tester,
      {required bool esError}) async {
    final boundaryKey = GlobalKey();
    late BuildContext contextoCapturado;
    await tester.binding.setSurfaceSize(const Size(360, 200));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTema.temaClaro(),
        home: Builder(
          builder: (context) {
            contextoCapturado = context;
            return RepaintBoundary(
              key: boundaryKey,
              child: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => mostrarSnackBar(
                      context,
                      esError ? 'Algo salió mal' : '¡Guardado con éxito!',
                      esError: esError,
                    ),
                    child: const Text('Disparar'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Disparar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final sufijoTipo = esError ? 'error' : 'exito';
    await tester.runAsync(() => _guardar(boundaryKey, 'snackbar-$sufijoTipo'));

    // Retira el SnackBar explícitamente (cancela su temporizador interno) y
    // deja que la animación de salida termine DENTRO de este mismo test:
    // si no, el Timer/SemanticsHandle queda vivo y contamina el siguiente
    // test del mismo archivo (mismo isolate).
    ScaffoldMessenger.of(contextoCapturado).removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  testWidgets('captura mostrarSnackBar de éxito', (tester) async {
    await capturarSnackBar(tester, esError: false);
  });

  testWidgets('captura mostrarSnackBar de error', (tester) async {
    await capturarSnackBar(tester, esError: true);
  });
}
