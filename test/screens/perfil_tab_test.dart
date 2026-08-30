// Tarea 023: la pestaña "Perfil" no puede enseñar como buenos unos datos que
// no ha podido confirmar.
//
// El caso real (reproducido en el emulador Pixel_6 contra el backend de la VM,
// primero en la tarea 022 y otra vez aquí): la app arranca sin conexión, hay
// sesión guardada, y `AuthService.restaurarSesion()` entra con el perfil que
// se guardó junto a la sesión —el que devolvió el login—. Ese perfil trae
// `habilidades`, `experiencia` y `estudios` a `null` (`cvCargado == false`).
// La pestaña lo pintaba tal cual: `Experiencias 0`, `Estudios 0`, "Sin
// habilidades registradas" y ni una palabra de que no había conexión. Para el
// usuario eso se lee como "la app me borró el CV", y es falso: en el servidor
// está intacto.
//
// Estos tests fijan las tres decisiones:
//  1. si el perfil no se pudo confirmar, se avisa;
//  2. si el CV no venía en la respuesta, no se pinta a cero;
//  3. deslizar para actualizar vuelve a pedirlo, y al llegar los avisos se van.
//
// Y uno más que protege la decisión del `tech-lead` para la fase 2: con datos
// buenos, abrir la pestaña **no** gasta ninguna petición. Nada de sondeo.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trabajito/models/usuario.dart';
import 'package:trabajito/screens/tabs/perfil_tab.dart';
import 'package:trabajito/services/api/api_client.dart';
import 'package:trabajito/services/api/configuracion_api.dart';
import 'package:trabajito/services/sesion_usuario.dart';
import 'package:trabajito/utils/constantes.dart';

import '../api/ayudas_api.dart';

/// Perfil tal y como llega en la respuesta del login y, por tanto, tal y como
/// se guarda en el dispositivo: **sin las tres listas del CV**.
Map<String, dynamic> perfilDeLogin() => {
      'id': '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc',
      'correo': 'ana@trabajito.test',
      'nombres': 'Ana',
      'apellidos': 'QaVeintitres',
      'rol': 'TRABAJADOR',
      'telefono': '99887766',
      'activo': true,
      'registroCompleto': true,
      'habilidades': null,
      'experiencia': null,
      'estudios': null,
    };

/// Lo que devuelve `GET /api/auth/yo`: el perfil de verdad, con CV.
Map<String, dynamic> perfilCompleto() => {
      ...perfilDeLogin(),
      'presentacion': 'Plomera con 6 años de experiencia',
      'habilidades': ['Plomería', 'Electricidad'],
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

/// `SeccionResenas` sigue leyendo de Firestore (fase 2b), y sin backend de
/// Firebase suelta errores al montarse. Lo que se prueba aquí es el perfil, no
/// las reseñas: se descartan a propósito, igual que hace
/// `test/pantalla_inicial_test.dart`.
void descartarErroresDeFirestore(WidgetTester tester) {
  var descartados = 0;
  while (tester.takeException() != null) {
    descartados++;
    if (descartados > 10) break;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  tearDown(() {
    ApiClient.fijarInstancia(null);
    sesionActual.salir();
  });

  /// Monta la pestaña igual que la monta `InicioScreen`: escuchando
  /// `sesionActual`, de forma que una recarga con éxito se vea en pantalla.
  Future<EspiaHttp> montar(
    WidgetTester tester, {
    required Map<String, dynamic> perfil,
    required bool sinConfirmar,
    required Future<http.Response> Function(http.Request) responder,
  }) async {
    // El perfil es más alto que la pantalla de test (800x600) y un `ListView`
    // solo construye lo que se ve: sin esto, "no aparece el CV a cero" sería
    // cierto por estar fuera de pantalla, que no prueba nada. Con una ventana
    // alta se construye la pestaña entera.
    await tester.binding.setSurfaceSize(const Size(1000, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final espia = EspiaHttp();
    final (cliente, _) = await clienteConSesion(
      clienteFalso(espia, responder),
      sesion: sesionDePrueba(),
    );
    ApiClient.fijarInstancia(cliente);
    sesionActual.entrar(Usuario.desdeJson(perfil),
        perfilSinConfirmar: sinConfirmar);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<EstadoSesion>(
          valueListenable: sesionActual,
          builder: (contexto, estado, _) => PerfilTab(
            usuario: estado.usuario!,
            datosSinConfirmar: estado.avisoSinConexion,
          ),
        ),
      ),
    ));
    // Sin `pumpAndSettle`: la sección de reseñas puede quedarse girando
    // porque Firestore no responde en los tests.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    return espia;
  }

  /// Gesto real de "deslizar para actualizar" sobre la lista del perfil.
  /// El arrastre es largo a propósito: `RefreshIndicator` no dispara hasta un
  /// 25% de la altura del viewport, y aquí el viewport mide 3000.
  Future<void> deslizarParaActualizar(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, 1400), 2000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // Y un par más para que se asiente el perfil que respondió el servidor.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
      'sin conexión, el perfil restaurado se enseña con su aviso y sin pintar '
      'el CV a cero', (tester) async {
    final espia = await montar(
      tester,
      perfil: perfilDeLogin(),
      sinConfirmar: true,
      responder: (_) async => throw http.ClientException('sin conexión'),
    );

    // 1. Se avisa de que estos datos son de la última visita.
    expect(find.text(AppTextos.datosDeTuUltimaVisita), findsOneWidget);

    // 2. El CV no se pinta a cero: ni contadores en 0 ni "sin habilidades".
    expect(find.text('Sin habilidades registradas'), findsNothing,
        reason: 'el usuario lo lee como "me borraron las habilidades"');
    expect(find.text('Experiencias'), findsNothing);
    expect(find.text('Estudios'), findsNothing);
    expect(find.text(AppTextos.cvSinCargar), findsOneWidget);
    expect(find.textContaining('siguen guardados en tu cuenta'), findsOneWidget);

    // 3. Se intentó una vez —y solo una— traer el perfil de verdad.
    expect(espia.llamadasA(RutasApi.yo), 1);

    descartarErroresDeFirestore(tester);
  });

  testWidgets('deslizar para actualizar trae el perfil y retira los avisos',
      (tester) async {
    // El "modo avión" del emulador, en un booleano: la primera petición —el
    // intento automático al abrir la pestaña— muere sin conexión; después
    // vuelve la red, como cuando el usuario sale del ascensor.
    var hayRed = false;
    final espia = await montar(
      tester,
      perfil: perfilDeLogin(),
      sinConfirmar: true,
      responder: (peticion) async {
        if (peticion.url.path != RutasApi.yo) {
          return respuestaError(404, 'ruta inesperada: ${peticion.url.path}');
        }
        if (!hayRed) throw http.ClientException('sin conexión');
        return respuestaJson(perfilCompleto(), 200);
      },
    );
    expect(find.text(AppTextos.datosDeTuUltimaVisita), findsOneWidget);
    expect(espia.llamadasA(RutasApi.yo), 1);

    // Vuelve la red y el usuario desliza. Antes de la tarea 023 este gesto no
    // existía: el perfil se quedaba viejo hasta reiniciar la app.
    hayRed = true;
    await deslizarParaActualizar(tester);

    expect(espia.llamadasA(RutasApi.yo), 2);
    expect(find.text(AppTextos.datosDeTuUltimaVisita), findsNothing,
        reason: 'ya se confirmó contra el servidor');
    expect(find.text(AppTextos.cvSinCargar), findsNothing);
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Electricidad'), findsOneWidget);
    expect(find.text('Experiencias'), findsOneWidget);

    descartarErroresDeFirestore(tester);
  });

  testWidgets('con el perfil completo y confirmado, abrir la pestaña no pide '
      'nada al servidor', (tester) async {
    final espia = await montar(
      tester,
      perfil: perfilCompleto(),
      sinConfirmar: false,
      responder: (peticion) async =>
          respuestaError(404, 'no debería llamar a ${peticion.url.path}'),
    );

    // La decisión del `tech-lead` para la fase 2 es carga puntual: si esto
    // deja de ser 0, alguien ha convertido la pantalla en un sondeo.
    expect(espia.peticiones, isEmpty);
    expect(find.text(AppTextos.datosDeTuUltimaVisita), findsNothing);
    expect(find.text('Experiencias'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);

    descartarErroresDeFirestore(tester);
  });

  testWidgets('deslizar sobre un perfil bueno lo vuelve a pedir una sola vez',
      (tester) async {
    final espia = await montar(
      tester,
      perfil: perfilCompleto(),
      sinConfirmar: false,
      responder: (peticion) async => peticion.url.path == RutasApi.yo
          ? respuestaJson(perfilCompleto(), 200)
          : respuestaError(404, 'ruta inesperada: ${peticion.url.path}'),
    );

    await deslizarParaActualizar(tester);

    expect(espia.llamadasA(RutasApi.yo), 1);

    descartarErroresDeFirestore(tester);
  });
}
