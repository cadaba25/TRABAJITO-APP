// Generador de capturas de `DetalleTrabajoScreen` en los estados visibles del
// trabajo (activo, asignado, en progreso, esperando confirmación, en disputa,
// completado), claro/oscuro, para el reporte de la tarea 035 (ADR-0016).
//
// NO es un test de regresión: no hace ningún `expect`, solo monta la
// pantalla real con `PublicacionService`/`PostulacionService` reales
// apuntando a un `MockClient` en memoria (mismo patrón que
// `test/manual/generar_capturas_trabajos.dart`, tarea 034) y guarda un PNG
// real (`RenderRepaintBoundary.toImage`) en `docs/agent-reports/capturas/`.
//
// Por qué un widget test y no el emulador: mismo criterio que las tareas 033
// y 034 — no arriesgar la sesión ajena que ya tumbó dos veces un emulador en
// esta cadena de tareas. `DetalleTrabajoScreen` ya recibe sus dos servicios
// por inyección (`context.read<PublicacionService>()`/`<PostulacionService>()`/
// `<ChatService>()`, ADR-0014); `ChatService` (tarea 053) ya no es excepción,
// pero este archivo no lo ejercita (ningún escenario llama a `_reservarPago`).
//
// No se nombra `*_test.dart` a propósito: `flutter test` (sin argumentos)
// solo descubre `test/**_test.dart`, así que esto NO se ejecuta en la suite
// normal. Se invoca a mano:
//   flutter test test/manual/generar_capturas_detalle_trabajo.dart
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
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/funcionalidades/postulaciones/datos/postulacion_service.dart';
import 'package:trabajito/funcionalidades/trabajos/datos/publicacion_service.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/detalle_trabajo_screen.dart';
import 'package:trabajito/nucleo/api/almacen_sesion.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/sesion_api.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

const _carpeta = 'docs/agent-reports/capturas';
const _idTrabajo = 'trab-1';

final _empleador = Usuario(
  uid: 'emp-1',
  tipoUsuario: 'empleador',
  nombres: 'Marta',
  apellidos: 'Contratista',
  correo: 'marta@trabajito.test',
  fechaRegistro: DateTime(2026, 1, 1),
  rol: 'empleador',
);

final _trabajador = Usuario(
  uid: 'trab-uid-1',
  tipoUsuario: 'trabajador',
  nombres: 'Carlos',
  apellidos: 'Demo',
  correo: 'carlos@trabajito.test',
  fechaRegistro: DateTime(2026, 1, 1),
  rol: 'trabajador',
);

/// Un tercero que no participa en el trabajo (para el estado "activo", el
/// único en el que la pantalla enseña el botón de postularse en vez de una
/// acción de las dos partes).
final _otroTrabajador = Usuario(
  uid: 'trab-uid-2',
  tipoUsuario: 'trabajador',
  nombres: 'Ana',
  apellidos: 'Candidata',
  correo: 'ana@trabajito.test',
  fechaRegistro: DateTime(2026, 1, 1),
  rol: 'trabajador',
);

Map<String, dynamic> _trabajoJson({
  String estado = 'ACTIVO',
  bool asignado = false,
  double montoAcordado = 0,
  String tiempoAcordado = '',
  bool pagoRetenido = false,
  bool entregado = false,
  bool pagoLiberado = false,
  bool correccionSolicitada = false,
  bool calificadoPorEmpleador = false,
  bool calificadoPorTrabajador = false,
}) =>
    <String, dynamic>{
      'id': _idTrabajo,
      'empleadorId': _empleador.uid,
      'autorNombre': 'Marta Contratista',
      'titulo': 'Instalar cerco perimetral de malla',
      'descripcion':
          'Necesito instalar 40 metros de cerco de malla ciclón en el '
          'patio trasero, con dos postes de refuerzo. Materiales ya '
          'comprados, solo hace falta la mano de obra.',
      'categoria': 'Construcción',
      'departamento': 'Francisco Morazán',
      'ciudad': 'Tegucigalpa',
      'zona': 'Col. Kennedy',
      'presupuesto': 'L. 2500',
      'plazo': 'Corto plazo',
      'estado': estado,
      'trabajadorAsignadoId': asignado ? _trabajador.uid : null,
      'trabajadorAsignadoNombre': asignado ? 'Carlos Demo' : null,
      'montoAcordado': montoAcordado,
      'tiempoAcordado': tiempoAcordado,
      'fechaAcuerdo': asignado
          ? DateTime.now().toUtc().subtract(const Duration(days: 2)).toIso8601String()
          : null,
      'fechaInicio': (asignado && estado != 'ASIGNADO' && estado != 'ACORDADO')
          ? DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String()
          : null,
      'pagoRetenido': pagoRetenido,
      'entregado': entregado,
      'pagoLiberado': pagoLiberado,
      'correccionSolicitada': correccionSolicitada,
      'motivoCorreccion': correccionSolicitada ? 'Falta reforzar dos postes.' : null,
      'calificadoPorEmpleador': calificadoPorEmpleador,
      'calificadoPorTrabajador': calificadoPorTrabajador,
      'creadoEn': DateTime.now().toUtc().subtract(const Duration(days: 3)).toIso8601String(),
    };

Map<String, dynamic> _evidenciaJson(String texto) => <String, dynamic>{
      'id': 'ev-1',
      'texto': texto,
      'autorId': _trabajador.uid,
      'autorNombre': 'Carlos Demo',
      'creadoEn': DateTime.now().toUtc().subtract(const Duration(hours: 5)).toIso8601String(),
    };

/// Servicios reales sobre un `MockClient` en memoria — mismo patrón que
/// `generar_capturas_trabajos.dart` (tarea 034). Sirve el trabajo pedido,
/// las evidencias (si las hay) y una lista vacía de postulaciones propias
/// (solo importa para el estado "activo" visto por un tercero).
Future<(PublicacionService, PostulacionService)> _servicios({
  required Map<String, dynamic> trabajo,
  List<Map<String, dynamic>> evidencias = const [],
}) async {
  final mock = MockClient((peticion) async {
    final ruta = peticion.url.path;
    if (ruta == '/api/trabajos/$_idTrabajo') {
      return http.Response(jsonEncode(trabajo), 200,
          headers: {'content-type': 'application/json'});
    }
    if (ruta == '/api/trabajos/$_idTrabajo/evidencias') {
      return http.Response(jsonEncode(evidencias), 200,
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

Future<void> _capturar(
  WidgetTester tester, {
  required String nombre,
  required Usuario usuario,
  required PublicacionService pub,
  required PostulacionService post,
  required Map<String, dynamic> trabajoInicial,
  required bool oscuro,
}) async {
  final boundaryKey = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(420, 1400));

  // La pantalla arranca con la `Publicacion` que le pasa quien navega (la de
  // la lista) y la reemplaza en cuanto responde `recargarPublicacion` — por
  // eso el JSON inicial y el que sirve el mock deben describir el mismo
  // estado, igual que en la app real.
  final publicacionInicial = trabajoInicial;

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
          child: DetalleTrabajoScreen(
            publicacion: Publicacion.desdeJson(publicacionInicial),
            usuario: usuario,
          ),
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
    final archivo = File('$_carpeta/035-$nombre-$sufijoTema.png');
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

  testWidgets('captura DetalleTrabajoScreen en los estados del trabajo',
      (tester) async {
    for (final oscuro in [false, true]) {
      // ── Activo, visto por un trabajador que aún no se postuló ──
      final activo = _trabajoJson(estado: 'ACTIVO');
      final (pubActivo, postActivo) = await _servicios(trabajo: activo);
      await _capturar(tester,
          nombre: 'activo',
          usuario: _otroTrabajador,
          pub: pubActivo,
          post: postActivo,
          trabajoInicial: activo,
          oscuro: oscuro);

      // ── Asignado (negociación en el chat), visto por el trabajador ──
      final asignado = _trabajoJson(estado: 'ASIGNADO', asignado: true);
      final (pubAsignado, postAsignado) = await _servicios(trabajo: asignado);
      await _capturar(tester,
          nombre: 'asignado',
          usuario: _trabajador,
          pub: pubAsignado,
          post: postAsignado,
          trabajoInicial: asignado,
          oscuro: oscuro);

      // ── En progreso, visto por el trabajador con un avance ya subido ──
      final enProgreso = _trabajoJson(
          estado: 'EN_PROGRESO',
          asignado: true,
          montoAcordado: 350,
          tiempoAcordado: '3 días',
          pagoRetenido: true);
      final (pubProgreso, postProgreso) = await _servicios(
          trabajo: enProgreso,
          evidencias: [_evidenciaJson('Ya instalé los dos postes de refuerzo.')]);
      await _capturar(tester,
          nombre: 'en-progreso',
          usuario: _trabajador,
          pub: pubProgreso,
          post: postProgreso,
          trabajoInicial: enProgreso,
          oscuro: oscuro);

      // ── Esperando confirmación, visto por el empleador (quien decide) ──
      final esperando = _trabajoJson(
          estado: 'ESPERANDO_CONFIRMACION',
          asignado: true,
          montoAcordado: 350,
          tiempoAcordado: '3 días',
          pagoRetenido: true,
          entregado: true);
      final (pubEsperando, postEsperando) = await _servicios(
          trabajo: esperando,
          evidencias: [_evidenciaJson('Cerco terminado, quedó firme.')]);
      await _capturar(tester,
          nombre: 'esperando-confirmacion',
          usuario: _empleador,
          pub: pubEsperando,
          post: postEsperando,
          trabajoInicial: esperando,
          oscuro: oscuro);

      // ── En disputa: ninguna acción, solo el aviso de soporte ──
      final disputa = _trabajoJson(
          estado: 'EN_DISPUTA',
          asignado: true,
          montoAcordado: 350,
          tiempoAcordado: '3 días',
          pagoRetenido: true,
          entregado: true);
      final (pubDisputa, postDisputa) = await _servicios(trabajo: disputa);
      await _capturar(tester,
          nombre: 'en-disputa',
          usuario: _trabajador,
          pub: pubDisputa,
          post: postDisputa,
          trabajoInicial: disputa,
          oscuro: oscuro);

      // ── Completado, visto por el empleador (pendiente de calificar) ──
      final completado = _trabajoJson(
          estado: 'COMPLETADO',
          asignado: true,
          montoAcordado: 350,
          tiempoAcordado: '3 días',
          pagoRetenido: true,
          entregado: true,
          pagoLiberado: true);
      final (pubCompletado, postCompletado) = await _servicios(
          trabajo: completado,
          evidencias: [_evidenciaJson('Cerco terminado, quedó firme.')]);
      await _capturar(tester,
          nombre: 'completado',
          usuario: _empleador,
          pub: pubCompletado,
          post: postCompletado,
          trabajoInicial: completado,
          oscuro: oscuro);
    }
  });
}
