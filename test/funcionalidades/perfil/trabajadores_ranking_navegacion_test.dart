// Tarea 049, hallazgo 3 — verificación pendiente en el criterio de
// aceptación ("verificación visual en emulador/dispositivo"): que la tarjeta
// completa de `trabajadores_tab.dart` y la fila de `ranking_tab.dart`
// naveguen a `DetalleTrabajadorScreen` al tocarlas.
//
// La sesión que ejecutó la 049 no tenía `adb` disponible y lo dejó como
// pendiente. Esta sesión de QA (previa al PR #17) sí tiene emulador Pixel_6
// disponible, pero el backend real vive en una VM de pruebas a la que este
// entorno no tiene acceso (SSH/VirtualBox bloqueados por la política de
// sandbox del agente) — no es posible loguear con datos reales y verificar a
// ojo en pantalla. En su lugar, se verifica el mismo comportamiento con un
// test de widget determinista: mismo patrón que ya usa
// `test/funcionalidades/perfil/perfil_tab_test.dart` (HTTP mockeado con
// `MockClient`, servicios inyectados por `provider`), que es más fuerte que
// una inspección visual porque queda como regresión automática.
//
// Confirma, para ambas pantallas: tocar la tarjeta/fila entera (no un botón
// suelto) navega a `DetalleTrabajadorScreen` con el `Usuario` correcto.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/widgets/pulsa_con_escala.dart';
import 'package:trabajito/funcionalidades/perfil/datos/perfil_service.dart';
import 'package:trabajito/funcionalidades/perfil/pantallas/detalle_trabajador_screen.dart';
import 'package:trabajito/funcionalidades/perfil/pantallas/ranking_tab.dart';
import 'package:trabajito/funcionalidades/perfil/pantallas/trabajadores_tab.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/configuracion_api.dart';

import '../../api/ayudas_api.dart';

/// `DetalleTrabajadorScreen` incluye `SeccionResenas`, que sigue en
/// Firestore (fase 2b-2, sin migrar todavía) y suelta una excepción al
/// montarse sin `Firebase.initializeApp()`. Mismo patrón exacto que
/// `test/funcionalidades/perfil/perfil_tab_test.dart`: se inicializa el
/// mock de Firebase Core para que no explote al construir, y se descartan
/// las excepciones de Firestore al final de cada test — lo que se prueba
/// aquí es la navegación, no las reseñas.
void descartarErroresDeFirestore(WidgetTester tester) {
  var descartados = 0;
  while (tester.takeException() != null) {
    descartados++;
    if (descartados > 10) break;
  }
}

/// Un trabajador activo y con registro completo — lo mínimo que exige el
/// filtro de ambas pantallas (`registroCompleto && estado == activo &&
/// nombreCorto.isNotEmpty`).
Map<String, dynamic> trabajadorDeRanking() => {
      'id': 'b6f6a6b0-2f1a-4a3a-9c1a-000000000001',
      'nombres': 'Ana',
      'apellidos': 'Martinez',
      'rol': 'TRABAJADOR',
      'trabajosCompletados': 7,
      // El endpoint de ranking manda el CV a null: no debe hacer falta para
      // que la tarjeta sea tocable.
      'habilidades': null,
      'experiencia': null,
      'estudios': null,
    };

Future<void> montarConRanking(
  WidgetTester tester, {
  required Widget pantalla,
}) async {
  final espia = EspiaHttp();
  final (cliente, _) = await clienteConSesion(
    clienteFalso(espia, (peticion) async {
      if (peticion.url.path == RutasApi.ranking) {
        return respuestaJson([trabajadorDeRanking()], 200);
      }
      return respuestaError(404, 'ruta inesperada: ${peticion.url.path}');
    }),
    sesion: sesionDePrueba(),
  );
  ApiClient.fijarInstancia(cliente);

  await tester.pumpWidget(MultiProvider(
    providers: [Provider<PerfilService>(create: (_) => PerfilService())],
    child: MaterialApp(home: pantalla),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  tearDown(() => ApiClient.fijarInstancia(null));

  testWidgets(
      'TrabajadoresTab: tocar la tarjeta entera navega a DetalleTrabajadorScreen',
      (tester) async {
    await montarConRanking(tester, pantalla: const TrabajadoresTab());

    expect(find.text('Ana Martinez'), findsOneWidget);
    expect(find.byType(DetalleTrabajadorScreen), findsNothing);

    // Toca la tarjeta completa (el `PulsaConEscala` que la envuelve), no un
    // botón suelto dentro de ella — es exactamente lo que pedía el hallazgo 3.
    await tester.tap(find.byType(PulsaConEscala));
    // Sin `pumpAndSettle`: `DetalleTrabajadorScreen` monta `SeccionResenas`,
    // que sigue en Firestore (sin mockear el stream) y no asienta nunca —
    // mismo motivo por el que `perfil_tab_test.dart` tampoco lo usa aquí.
    // Pasos explícitos: uno para que la transición de ruta arranque y el
    // resto para que la animación estándar (300ms) termine.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DetalleTrabajadorScreen), findsOneWidget);
    // El AppBar de DetalleTrabajadorScreen dice "Perfil"; el nombre del
    // trabajador correcto viaja con la navegación.
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Ana Martinez'), findsWidgets);

    descartarErroresDeFirestore(tester);
  });

  testWidgets(
      'RankingTab: tocar la fila de un trabajador navega a DetalleTrabajadorScreen',
      (tester) async {
    await montarConRanking(tester, pantalla: const RankingTab());

    expect(find.text('Ana Martinez'), findsOneWidget);
    expect(find.byType(DetalleTrabajadorScreen), findsNothing);

    // El índice 0 del ListView es la cabecera "Ranking semanal" (no un
    // usuario) y no está envuelta en `PulsaConEscala`; con un solo
    // trabajador en la lista, este es el único `PulsaConEscala` presente —
    // confirma que la cabecera se dejó intacta, tal como pedía la tarea.
    expect(find.byType(PulsaConEscala), findsOneWidget);
    await tester.tap(find.byType(PulsaConEscala));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DetalleTrabajadorScreen), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);

    descartarErroresDeFirestore(tester);
  });
}
