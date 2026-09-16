// Generador de capturas de la bandeja de postulantes (`PostulantesScreen`),
// claro/oscuro, con 0/1/varios candidatos, para el reporte de la tarea 036
// (ADR-0016). NO es un test de regresión: no hace ningún `expect`, solo
// monta la pantalla real con los servicios reales apuntando a un
// `MockClient` en memoria (mismo patrón que
// `test/manual/generar_capturas_trabajos.dart` de la tarea 034 y
// `test/manual/generar_capturas_detalle_trabajo.dart` de la 035) y guarda un
// PNG real (`RenderRepaintBoundary.toImage`) en `docs/agent-reports/capturas/`.
//
// Por qué un widget test y no el emulador: mismo criterio que las tareas
// 032-035 (evitar pisar una sesión de `flutter run` ajena).
//
// "Antes"/"después": este archivo captura siempre el código tal cual está en
// el árbol de trabajo. Las capturas "antes" de esta tarea se generaron
// corriendo este mismo archivo con `git stash push` sobre los 6 archivos de
// `lib/` que tocó la tarea 036 (revierte los tokens sin tocar este
// generador), y las "después" tras `git stash pop`. Ver el reporte de la
// tarea 036 para el paso a paso exacto.
//
// No se nombra `*_test.dart` a propósito: `flutter test` (sin argumentos)
// no lo descubre ni lo ejecuta. Se invoca a mano:
//   flutter test test/manual/generar_capturas_postulaciones.dart
//   flutter test test/manual/generar_capturas_postulaciones.dart --dart-define=SUFIJO=antes
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
import 'package:trabajito/compartido/modelos/publicacion.dart';
import 'package:trabajito/funcionalidades/perfil/datos/perfil_service.dart';
import 'package:trabajito/funcionalidades/postulaciones/datos/postulacion_service.dart';
import 'package:trabajito/funcionalidades/postulaciones/pantallas/postulantes_screen.dart';
import 'package:trabajito/funcionalidades/trabajos/datos/publicacion_service.dart';
import 'package:trabajito/nucleo/api/almacen_sesion.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/sesion_api.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

const _carpeta = 'docs/agent-reports/capturas';

/// `antes` (previo a esta tarea, con `git stash` sobre los 6 archivos) o
/// `despues` (con los tokens de la 031 aplicados) — ver docstring del archivo.
const String _sufijo = String.fromEnvironment('SUFIJO', defaultValue: 'despues');

final Map<String, dynamic> _trabajoJson = <String, dynamic>{
  'id': 'trab-1',
  'empleadorId': 'emp-1',
  'autorNombre': 'Marta Contratista',
  'titulo': 'Pintar sala y comedor',
  'descripcion': 'Necesito a alguien con experiencia, trabajo serio.',
  'categoria': 'Pintura',
  'departamento': 'Francisco Morazan',
  'ciudad': 'Tegucigalpa',
  'zona': 'Col. Kennedy',
  'presupuesto': 'L. 4500',
  'plazo': 'Mediano plazo',
  'estado': 'ACTIVO',
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
  'creadoEn': DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String(),
};

Map<String, dynamic> _postulanteJson({
  required String id,
  required String nombre,
  String estado = 'PENDIENTE',
  String mensaje = 'Tengo 5 años de experiencia pintando interiores.',
}) =>
    <String, dynamic>{
      'id': id,
      'trabajoId': 'trab-1',
      'tituloTrabajo': 'Pintar sala y comedor',
      'trabajadorId': 'trab-$id',
      'trabajadorNombre': nombre,
      'empleadorId': 'emp-1',
      'mensaje': mensaje,
      'estado': estado,
      'creadoEn': DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String(),
    };

/// Servicios reales sobre un `MockClient` en memoria — mismo patrón que
/// `generar_capturas_trabajos.dart`. Responde el trabajo fijo en
/// `/api/trabajos/trab-1` y la lista de postulantes pedida en
/// `/api/postulaciones`.
Future<(PublicacionService, PostulacionService, PerfilService)> _servicios({
  List<Map<String, dynamic>> postulantes = const [],
}) async {
  final mock = MockClient((peticion) async {
    final ruta = peticion.url.path;
    if (ruta == '/api/trabajos/trab-1') {
      return http.Response(jsonEncode(_trabajoJson), 200,
          headers: {'content-type': 'application/json'});
    }
    if (ruta == '/api/postulaciones') {
      return http.Response(jsonEncode(postulantes), 200,
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
  return (
    PublicacionService(cliente: cliente),
    PostulacionService(cliente: cliente),
    PerfilService(cliente: cliente),
  );
}

Future<void> _capturar(
  WidgetTester tester, {
  required String nombre,
  required PublicacionService pub,
  required PostulacionService post,
  required PerfilService perfil,
  required bool oscuro,
}) async {
  final boundaryKey = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(420, 900));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PublicacionService>.value(value: pub),
        Provider<PostulacionService>.value(value: post),
        Provider<PerfilService>.value(value: perfil),
      ],
      child: MaterialApp(
        theme: AppTema.temaClaro(),
        darkTheme: AppTema.temaOscuro(),
        themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
        home: RepaintBoundary(
          key: boundaryKey,
          child: PostulantesScreen(
              publicacion: Publicacion.desdeJson(_trabajoJson)),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final imagen = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final sufijoTema = oscuro ? 'oscuro' : 'claro';
    final archivo = File('$_carpeta/036-$nombre-$_sufijo-$sufijoTema.png');
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

  testWidgets('captura la bandeja de postulantes con 0/1/varios candidatos',
      (tester) async {
    for (final oscuro in [false, true]) {
      final (pub0, post0, perfil0) = await _servicios();
      await _capturar(tester,
          nombre: 'postulantes-0', pub: pub0, post: post0, perfil: perfil0, oscuro: oscuro);

      final (pub1, post1, perfil1) = await _servicios(postulantes: [
        _postulanteJson(id: '1', nombre: 'Carlos Demo'),
      ]);
      await _capturar(tester,
          nombre: 'postulantes-1', pub: pub1, post: post1, perfil: perfil1, oscuro: oscuro);

      final (pubN, postN, perfilN) = await _servicios(postulantes: [
        _postulanteJson(id: '1', nombre: 'Carlos Demo'),
        _postulanteJson(
            id: '2',
            nombre: 'Ana Reyes',
            estado: 'ACEPTADA',
            mensaje: ''),
        _postulanteJson(id: '3', nombre: 'Luis Martínez', estado: 'RECHAZADA'),
      ]);
      await _capturar(tester,
          nombre: 'postulantes-varios', pub: pubN, post: postN, perfil: perfilN, oscuro: oscuro);
    }
  });
}
