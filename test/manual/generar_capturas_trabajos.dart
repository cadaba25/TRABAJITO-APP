// Generador de capturas del feed de "Trabajos" y de "Mis publicaciones",
// claro/oscuro, con y sin resultados, para el reporte de la tarea 034
// (ADR-0016). NO es un test de regresión: no hace ningún `expect`, solo
// monta las pantallas reales (`TrabajosTab`/`MisPublicacionesScreen`) con los
// servicios reales apuntando a un `MockClient` en memoria (mismo patrón que
// `test/funcionalidades/trabajos/trabajos_y_postulaciones_test.dart`) y
// guarda un PNG real (`RenderRepaintBoundary.toImage`) en
// `docs/agent-reports/capturas/`.
//
// Por qué un widget test y no el emulador: mismo criterio que la tarea 033
// (`test/manual/generar_capturas_registro.dart`) — no hay que arriesgar la
// sesión ajena que ya tumbó dos veces un emulador en esta cadena de tareas
// (031, 032). Las pantallas de "Trabajos" ya reciben sus servicios por
// inyección (`context.read<PublicacionService>()`/`<PostulacionService>()`,
// ADR-0014), así que montarlas de verdad con un `MultiProvider` + un backend
// falso prueba exactamente lo que hay que probar: el feed y "Mis
// publicaciones" reales, no una recomposición manual de sus widgets.
//
// "Antes"/"después": este archivo captura siempre el código tal cual está en
// el árbol de trabajo en el momento de correrlo. Las capturas "antes" de esta
// tarea se generaron corriendo este mismo archivo con
// `git stash push -- <los 14 archivos de la tarea 034>` aplicado (revierte
// los tokens sin tocar este generador, que no cambió ninguna firma pública),
// y las "después" corriendo otra vez tras `git stash pop`. Ver el reporte de
// la tarea 034 para el paso a paso exacto.
//
// No se nombra `*_test.dart` a propósito: `flutter test` (sin argumentos)
// solo descubre `test/**_test.dart`, así que esto NO se ejecuta en la suite
// normal. Se invoca a mano:
//   flutter test test/manual/generar_capturas_trabajos.dart
//   flutter test test/manual/generar_capturas_trabajos.dart --dart-define=SUFIJO=antes
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/funcionalidades/postulaciones/datos/postulacion_service.dart';
import 'package:trabajito/funcionalidades/trabajos/datos/publicacion_service.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/mis_publicaciones_screen.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/trabajos_tab.dart';
import 'package:trabajito/nucleo/api/almacen_sesion.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/sesion_api.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

const _carpeta = 'docs/agent-reports/capturas';

/// `antes` (previo a esta tarea, con `git stash` sobre los 14 archivos) o
/// `despues` (con los tokens de la 031 aplicados) — ver docstring del archivo.
const String _sufijo = String.fromEnvironment('SUFIJO', defaultValue: 'despues');

Map<String, dynamic> _trabajoJson({
  required String id,
  required String titulo,
  String categoria = 'Construccion',
  String plazo = 'Corto plazo',
  String presupuesto = 'L. 1200',
  String estado = 'ACTIVO',
}) =>
    <String, dynamic>{
      'id': id,
      'empleadorId': 'e-$id',
      'autorNombre': 'Marta Contratista',
      'titulo': titulo,
      'descripcion':
          'Necesito a alguien con experiencia para empezar cuanto antes, '
          'trabajo serio y con buen pago.',
      'categoria': categoria,
      'departamento': 'Francisco Morazan',
      'ciudad': 'Tegucigalpa',
      'zona': 'Col. Kennedy',
      'presupuesto': presupuesto,
      'plazo': plazo,
      'estado': estado,
      'trabajadorAsignadoId': null,
      'trabajadorAsignadoNombre': null,
      'montoAcordado': 0,
      'tiempoAcordado': null,
      'fechaAcuerdo': null,
      'fechaInicio': null,
      'pagoRetenido': false,
      'entregado': false,
      'pagoLiberado': false,
      'correccionSolicitada': false,
      'motivoCorreccion': null,
      'fechaSolicitudCorreccion': null,
      'disputaAbiertaPorId': null,
      'motivoDisputa': null,
      'resolucionDisputa': null,
      'calificadoPorEmpleador': false,
      'calificadoPorTrabajador': false,
      'creadoEn': DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String(),
    };

Map<String, dynamic> _paginaJson(List<Map<String, dynamic>> contenido) => <String, dynamic>{
      'content': contenido,
      'pageable': {'pageNumber': 0, 'pageSize': 20},
      'totalElements': contenido.length,
      'totalPages': 1,
      'last': true,
      'first': true,
      'numberOfElements': contenido.length,
      'size': 20,
      'number': 0,
      'empty': contenido.isEmpty,
    };

/// Servicios reales sobre un `MockClient` en memoria — mismo patrón que
/// `trabajos_y_postulaciones_test.dart`. `feed`/`mias` son las respuestas que
/// se sirven según la ruta pedida; el resto (postulaciones propias) responde
/// siempre una lista vacía: no afecta a lo que se está capturando.
Future<(PublicacionService, PostulacionService)> _servicios({
  List<Map<String, dynamic>> feed = const [],
  List<Map<String, dynamic>> mias = const [],
}) async {
  final mock = MockClient((peticion) async {
    final ruta = peticion.url.path;
    if (ruta == '/api/trabajos') {
      return http.Response(jsonEncode(_paginaJson(feed)), 200,
          headers: {'content-type': 'application/json'});
    }
    if (ruta == '/api/trabajos/mios') {
      return http.Response(jsonEncode(mias), 200,
          headers: {'content-type': 'application/json'});
    }
    return http.Response(jsonEncode([]), 200,
        headers: {'content-type': 'application/json'});
  });
  final almacen = AlmacenSesionEnMemoria();
  final cliente = ApiClient(
      clienteHttp: mock, almacen: almacen, urlBase: 'http://prueba.local:8080');
  await cliente.guardarSesion(SesionApi(
    token: 't',
    refreshToken: 'r',
    expiraEn: DateTime.now().add(const Duration(minutes: 15)),
    usuario: const {'correo': 'prueba@trabajito.test'},
  ));
  return (PublicacionService(cliente: cliente), PostulacionService(cliente: cliente));
}

final _trabajador = Usuario(
  uid: 'trab-1',
  tipoUsuario: 'trabajador',
  nombres: 'Carlos',
  apellidos: 'Demo',
  correo: 'carlos@trabajito.test',
  fechaRegistro: DateTime(2026, 1, 1),
  rol: 'trabajador',
);

final _empleador = Usuario(
  uid: 'emp-1',
  tipoUsuario: 'empleador',
  nombres: 'Marta',
  apellidos: 'Contratista',
  correo: 'marta@trabajito.test',
  fechaRegistro: DateTime(2026, 1, 1),
  rol: 'empleador',
);

Future<void> _capturar(
  WidgetTester tester, {
  required String nombre,
  required Widget pantalla,
  required PublicacionService pub,
  required PostulacionService post,
  required bool oscuro,
}) async {
  final boundaryKey = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(420, 900));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PublicacionService>.value(value: pub),
        Provider<PostulacionService>.value(value: post),
      ],
      child: MaterialApp(
        theme: AppTema.temaClaro(),
        darkTheme: AppTema.temaOscuro(),
        themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
        home: RepaintBoundary(
          key: boundaryKey,
          child: Scaffold(body: SafeArea(child: pantalla)),
        ),
      ),
    ),
  );
  // Dos ciclos: la carga inicial es async (Future.then/setState) y el stagger
  // de la primera carga (ADR-0015) necesita asentarse.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final imagen = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final sufijoTema = oscuro ? 'oscuro' : 'claro';
    final archivo = File('$_carpeta/034-$nombre-$_sufijo-$sufijoTema.png');
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

  testWidgets('captura el feed y "Mis publicaciones", con y sin resultados',
      (tester) async {
    for (final oscuro in [false, true]) {
      // ── Feed, con resultados (trabajador) ──────────────────
      final (pubConFeed, postConFeed) = await _servicios(feed: [
        _trabajoJson(id: '1', titulo: 'Electricista para lámparas', presupuesto: 'L. 350/hora'),
        _trabajoJson(
            id: '2',
            titulo: 'Pintar sala y comedor',
            categoria: 'Pintura',
            plazo: 'Mediano plazo',
            presupuesto: 'L. 4500'),
      ]);
      await _capturar(tester,
          nombre: 'feed-con-resultados',
          pantalla: TrabajosTab(usuario: _trabajador),
          pub: pubConFeed,
          post: postConFeed,
          oscuro: oscuro);

      // ── Feed, sin resultados (trabajador) ──────────────────
      final (pubVacio, postVacio) = await _servicios();
      await _capturar(tester,
          nombre: 'feed-sin-resultados',
          pantalla: TrabajosTab(usuario: _trabajador),
          pub: pubVacio,
          post: postVacio,
          oscuro: oscuro);

      // ── Mis publicaciones, con resultados (empleador) ──────
      final (pubMias, postMias) = await _servicios(mias: [
        _trabajoJson(id: '3', titulo: 'Reparar techo de lámina', estado: 'ACTIVO'),
        _trabajoJson(
            id: '4', titulo: 'Instalar cerco perimetral', estado: 'EN_PROGRESO', presupuesto: ''),
      ]);
      await _capturar(tester,
          nombre: 'mis-publicaciones-con-resultados',
          pantalla: MisPublicacionesScreen(usuario: _empleador),
          pub: pubMias,
          post: postMias,
          oscuro: oscuro);

      // ── Mis publicaciones, sin resultados (empleador) ──────
      final (pubMiasVacio, postMiasVacio) = await _servicios();
      await _capturar(tester,
          nombre: 'mis-publicaciones-sin-resultados',
          pantalla: MisPublicacionesScreen(usuario: _empleador),
          pub: pubMiasVacio,
          post: postMiasVacio,
          oscuro: oscuro);
    }
  });
}
