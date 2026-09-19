// Generador de capturas de `InicioScreen` (las 5 pestañas del `BottomNav`) y
// de la pestaña "Perfil" con sus dos avisos ("datos sin confirmar" / "CV sin
// cargar"), claro/oscuro, para el reporte de la tarea 037 (ADR-0016). NO es
// un test de regresión: no hace ningún `expect`, solo monta la pantalla real
// (`InicioScreen`/`PerfilTab`) con los servicios reales apuntando a un
// `MockClient` en memoria (mismo patrón que
// `test/manual/generar_capturas_postulaciones.dart` de la tarea 036) y
// guarda un PNG real (`RenderRepaintBoundary.toImage`) en
// `docs/agent-reports/capturas/`.
//
// Por qué un widget test y no el emulador: mismo criterio que 032-036 (evitar
// pisar una sesión de `flutter run` ajena — puede haber otro agente con la
// app abierta en el mismo emulador ahora mismo).
//
// "Antes"/"después": este archivo captura siempre el código tal cual está en
// el árbol de trabajo. Las capturas "antes" de esta tarea se generaron
// corriendo este mismo archivo con `git stash push` aplicado sobre los
// archivos de `lib/` que tocó la 037 (revierte los tokens sin tocar este
// generador), y las "después" tras `git stash pop`. Ver el reporte de la
// tarea 037 para el paso a paso exacto.
//
// No se nombra `*_test.dart` a propósito: `flutter test` (sin argumentos) no
// lo descubre ni lo ejecuta. Se invoca a mano:
//   flutter test test/manual/generar_capturas_perfil_inicio.dart
//   flutter test test/manual/generar_capturas_perfil_inicio.dart --dart-define=SUFIJO=antes
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/funcionalidades/inicio/pantallas/inicio_screen.dart';
import 'package:trabajito/funcionalidades/perfil/pantallas/perfil_tab.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/inyeccion/proveedores.dart';
import 'package:trabajito/nucleo/sesion/sesion_usuario.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

import '../api/ayudas_api.dart';

const _carpeta = 'docs/agent-reports/capturas';

/// `antes` (previo a esta tarea) o `despues` (con los tokens de la 037
/// aplicados) — ver docstring del archivo.
const String _sufijo = String.fromEnvironment('SUFIJO', defaultValue: 'despues');

/// Perfil completo de un trabajador (con CV) — el estado "normal" en el que
/// se ven las 5 pestañas sin avisos.
Map<String, dynamic> _perfilCompleto() => {
      'id': '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc',
      'correo': 'ana@trabajito.test',
      'nombres': 'Ana',
      'apellidos': 'Martínez',
      'rol': 'TRABAJADOR',
      'telefono': '99887766',
      'ciudad': 'Tegucigalpa',
      'departamento': 'Francisco Morazán',
      'activo': true,
      'registroCompleto': true,
      'presentacion': 'Plomera con 6 años de experiencia',
      'habilidades': ['Plomería', 'Electricidad'],
      'calificacionPromedio': 4.8,
      'totalCalificaciones': 12,
      'trabajosCompletados': 9,
      'experiencia': [
        {
          'id': '0d8f6a3e-0a3d-4a54-9c4d-6f5a0e6b1f21',
          'empresa': 'Constructora Sula',
          'puesto': 'Plomera',
          'fechaInicio': '2021-01',
        },
      ],
      'estudios': [
        {
          'id': 'a1a2a3a4-0a3d-4a54-9c4d-6f5a0e6b1f22',
          'institucion': 'INFOP',
          'titulo': 'Técnico en fontanería',
          'anioFin': '2020',
        },
      ],
    };

/// Perfil tal y como llega en la respuesta del login (sin CV) — el estado que
/// dispara los avisos de "datos sin confirmar"/"CV sin cargar" (tarea 023).
Map<String, dynamic> _perfilDeLogin() => {
      ..._perfilCompleto(),
      'habilidades': null,
      'experiencia': null,
      'estudios': null,
    };

Map<String, dynamic> _paginaVacia() => <String, dynamic>{
      'content': const [],
      'pageable': {'pageNumber': 0, 'pageSize': 20},
      'totalElements': 0,
      'totalPages': 1,
      'last': true,
      'first': true,
      'numberOfElements': 0,
      'size': 20,
      'number': 0,
      'empty': true,
    };

Map<String, dynamic> _trabajadorRanking(String nombre, int completados) => {
      'id': 'trab-$nombre',
      'correo': '$nombre@trabajito.test',
      'nombres': nombre,
      'apellidos': 'Demo',
      'rol': 'TRABAJADOR',
      'registroCompleto': true,
      'activo': true,
      'trabajosCompletados': completados,
      'calificacionPromedio': 4.5,
      'totalCalificaciones': 6,
      'habilidades': null,
      'experiencia': null,
      'estudios': null,
    };

/// Cliente HTTP falso: feed y "mis trabajos" vacíos (no son el foco de esta
/// tarea, ya capturados en 034), ranking con dos trabajadores de muestra.
Future<ApiClient> _clienteFalso() async {
  final mock = MockClient((peticion) async {
    final ruta = peticion.url.path;
    if (ruta == '/api/trabajos') {
      return respuestaJson(_paginaVacia(), 200);
    }
    if (ruta == '/api/usuarios/ranking') {
      return respuestaJson([
        _trabajadorRanking('Carlos', 14),
        _trabajadorRanking('Luisa', 9),
      ], 200);
    }
    return respuestaJson(const [], 200);
  });
  final (cliente, _) = await clienteConSesion(
    mock,
    sesion: sesionDePrueba(),
  );
  return cliente;
}

/// Encuentra el ícono (sin seleccionar) de una pestaña del `BottomNav` y la
/// abre. Los íconos activo/inactivo son distintos, así que buscar el inactivo
/// basta: en el momento del toque la pestaña destino todavía no está
/// seleccionada.
Future<void> _abrirPestana(WidgetTester tester, IconData iconoInactivo) async {
  final buscador = find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.byIcon(iconoInactivo),
  );
  await tester.tap(buscador.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _guardarCaptura(
    WidgetTester tester, GlobalKey boundaryKey, String archivo) async {
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final imagen = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_carpeta/$archivo');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Descarta los errores de Firestore (chat/reseñas siguen ahí; no están
/// mockeados). Mismo criterio que `perfil_tab_test.dart`.
void _descartarErroresDeFirestore(WidgetTester tester) {
  var descartados = 0;
  while (tester.takeException() != null) {
    descartados++;
    if (descartados > 20) break;
  }
}

Future<void> _capturarInicio(WidgetTester tester,
    {required bool oscuro, required Map<String, dynamic> perfil}) async {
  final sufijoTema = oscuro ? 'oscuro' : 'claro';
  final boundaryKey = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(420, 900));

  ApiClient.fijarInstancia(await _clienteFalso());
  sesionActual.entrar(Usuario.desdeJson(perfil));

  await tester.pumpWidget(MultiProvider(
    providers: proveedoresDeLaApp(),
    child: MaterialApp(
      theme: AppTema.temaClaro(),
      darkTheme: AppTema.temaOscuro(),
      themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
      home: RepaintBoundary(
        key: boundaryKey,
        child: const InicioScreen(),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  _descartarErroresDeFirestore(tester);

  // 0. Trabajos (pestaña inicial, ya seleccionada).
  await _guardarCaptura(
      tester, boundaryKey, '037-inicio-0-trabajos-$_sufijo-$sufijoTema.png');

  // 1. Trabajadores.
  await _abrirPestana(tester, Icons.people_outline_rounded);
  _descartarErroresDeFirestore(tester);
  await _guardarCaptura(tester, boundaryKey,
      '037-inicio-1-trabajadores-$_sufijo-$sufijoTema.png');

  // 2. Chats (sigue en Firestore, fuera del alcance de ADR-0016 — se
  // captura solo porque es una de las 5 pestañas del `BottomNav`).
  await _abrirPestana(tester, Icons.forum_outlined);
  _descartarErroresDeFirestore(tester);
  await _guardarCaptura(
      tester, boundaryKey, '037-inicio-2-chats-$_sufijo-$sufijoTema.png');

  // 3. Ranking semanal.
  await _abrirPestana(tester, Icons.emoji_events_outlined);
  _descartarErroresDeFirestore(tester);
  await _guardarCaptura(
      tester, boundaryKey, '037-inicio-3-ranking-$_sufijo-$sufijoTema.png');

  // 4. Perfil.
  await _abrirPestana(tester, Icons.person_outline_rounded);
  _descartarErroresDeFirestore(tester);
  await _guardarCaptura(
      tester, boundaryKey, '037-inicio-4-perfil-$_sufijo-$sufijoTema.png');

  await tester.binding.setSurfaceSize(null);
  ApiClient.fijarInstancia(null);
  sesionActual.salir();
}

/// Captura solo `PerfilTab` en el escenario de los dos avisos a la vez:
/// "datos sin confirmar" (`datosSinConfirmar: true`) y "CV sin cargar"
/// (`cvCargado == false`, perfil de login). Es el caso de contraste real que
/// pide el criterio de aceptación de la 037 — se aísla en su propia captura
/// para que sea fácil de comparar antes/después sin tener que localizarlo
/// dentro de la captura general de la pestaña.
Future<void> _capturarAvisosPerfil(WidgetTester tester,
    {required bool oscuro}) async {
  final sufijoTema = oscuro ? 'oscuro' : 'claro';
  final boundaryKey = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(420, 1400));

  ApiClient.fijarInstancia(await _clienteFalso());
  sesionActual.entrar(Usuario.desdeJson(_perfilDeLogin()), perfilSinConfirmar: true);

  await tester.pumpWidget(MultiProvider(
    providers: proveedoresDeLaApp(),
    child: MaterialApp(
      theme: AppTema.temaClaro(),
      darkTheme: AppTema.temaOscuro(),
      themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
      home: RepaintBoundary(
        key: boundaryKey,
        child: Scaffold(
          body: ValueListenableBuilder<EstadoSesion>(
            valueListenable: sesionActual,
            builder: (contexto, estado, _) => PerfilTab(
              usuario: estado.usuario!,
              datosSinConfirmar: estado.avisoSinConexion,
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  _descartarErroresDeFirestore(tester);

  await _guardarCaptura(
      tester, boundaryKey, '037-perfil-avisos-$_sufijo-$sufijoTema.png');

  await tester.binding.setSurfaceSize(null);
  ApiClient.fijarInstancia(null);
  sesionActual.salir();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final cargador = FontLoader('Sora')..addFont(rootBundle.load('assets/fonts/Sora.ttf'));
    await cargador.load();
  });

  testWidgets('captura las 5 pestañas de InicioScreen, claro/oscuro',
      (tester) async {
    // La pestaña "Chats" abre un stream de Firestore real (no mockeado, fase
    // 2b-2 pendiente) y su error de canal puede llegar en un microtask
    // posterior al `pump` que lo disparó. `runZonedGuarded` evita que ese
    // error asíncrono "gotee" fuera de este test y tumbe el siguiente.
    await runZonedGuarded(() async {
      for (final oscuro in [false, true]) {
        await _capturarInicio(tester, oscuro: oscuro, perfil: _perfilCompleto());
      }
    }, (error, stack) {
      // Esperado: Firestore no está mockeado en este generador de capturas.
    });
  });

  testWidgets(
      'captura PerfilTab con los avisos de datos sin confirmar y CV sin '
      'cargar, claro/oscuro', (tester) async {
    await runZonedGuarded(() async {
      for (final oscuro in [false, true]) {
        await _capturarAvisosPerfil(tester, oscuro: oscuro);
      }
    }, (error, stack) {
      // Esperado: `SeccionResenas` sigue leyendo de Firestore (fase 2b-2).
    });
  });
}
