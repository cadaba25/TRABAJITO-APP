// Tarea 049, hallazgo 5 — verificación pendiente en el criterio de
// aceptación: que "Retirar postulación" en `mis_postulaciones_screen.dart`
// muestre el diálogo de confirmación ANTES de llamar al servicio, y que
// cancelar el diálogo no dispare la llamada. Mismo motivo que
// `trabajadores_ranking_navegacion_test.dart` para preferir un test de
// widget determinista a una inspección en el emulador: sin acceso a la VM
// del backend real desde este entorno, esto prueba lo mismo (y queda como
// regresión automática).
//
// Es también el caso de "doble submit"/multi-toque que pide vigilar
// `docs/agent-context/RETOMAR-AQUI.md`: si el diálogo desapareciera, dos
// toques rápidos en "Retirar" podrían disparar dos DELETE. Se comprueba
// aparte que un segundo toque en "Sí" (tras el primero, con el diálogo ya
// cerrado) no repite la llamada.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/funcionalidades/postulaciones/datos/postulacion_service.dart';
import 'package:trabajito/funcionalidades/postulaciones/pantallas/mis_postulaciones_screen.dart';
import 'package:trabajito/funcionalidades/trabajos/datos/publicacion_service.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/configuracion_api.dart';

import '../../api/ayudas_api.dart';

/// Postulación pendiente propia. `trabajoId` se deja vacío a propósito: la
/// pantalla filtra los ids vacíos antes de pedir cada trabajo
/// (`ids.removeWhere((id) => id.isEmpty)`), así este test no necesita
/// mockear también `GET /api/trabajos/{id}` — no es relevante para lo que
/// se está probando aquí (la confirmación de "Retirar").
Map<String, dynamic> postulacionPendiente() => {
      'id': 'a1a1a1a1-0000-0000-0000-000000000001',
      'trabajoId': '',
      'tituloTrabajo': 'Reparar tubería',
      'trabajadorId': '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc',
      'trabajadorNombre': 'Ana QaVeintitres',
      'empleadorId': 'empleador-1',
      'estado': 'pendiente',
      'creadoEn': DateTime.now().toIso8601String(),
    };

Usuario usuarioDePrueba() => Usuario.desdeJson(const {
      'id': '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc',
      'nombres': 'Ana',
      'apellidos': 'QaVeintitres',
      'rol': 'TRABAJADOR',
    });

Future<EspiaHttp> montar(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) responderDelete,
}) async {
  final espia = EspiaHttp();
  final (cliente, _) = await clienteConSesion(
    clienteFalso(espia, (peticion) async {
      if (peticion.url.path == RutasApi.misPostulaciones) {
        return respuestaJson([postulacionPendiente()], 200);
      }
      if (peticion.method == 'DELETE' &&
          peticion.url.path == RutasApi.postulacion(postulacionPendiente()['id'] as String)) {
        return responderDelete(peticion);
      }
      return respuestaError(404, 'ruta inesperada: ${peticion.url.path}');
    }),
    sesion: sesionDePrueba(),
  );
  ApiClient.fijarInstancia(cliente);

  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<PostulacionService>(create: (_) => PostulacionService()),
      Provider<PublicacionService>(create: (_) => PublicacionService()),
    ],
    child: MaterialApp(
      home: MisPostulacionesScreen(usuario: usuarioDePrueba()),
    ),
  ));
  await tester.pumpAndSettle();
  return espia;
}

void main() {
  tearDown(() => ApiClient.fijarInstancia(null));

  testWidgets(
      'tocar "Retirar" muestra el diálogo de confirmación y NO llama al '
      'servicio todavía', (tester) async {
    final espia = await montar(tester,
        responderDelete: (_) async =>
            respuestaError(500, 'no debería llamarse sin confirmar'));

    expect(find.text('Reparar tubería'), findsOneWidget);

    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Retirar esta postulación?'), findsOneWidget);
    expect(find.text('Perderás tu puesto en la cola de este trabajo.'),
        findsOneWidget);
    // El diálogo bloquea: todavía no se llamó al DELETE.
    expect(
        espia.llamadasA(
            RutasApi.postulacion(postulacionPendiente()['id'] as String)),
        0);
  });

  testWidgets('cancelar el diálogo ("No") no llama al servicio',
      (tester) async {
    final espia = await montar(tester,
        responderDelete: (_) async =>
            respuestaError(500, 'no debería llamarse tras cancelar'));

    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(find.text('¿Retirar esta postulación?'), findsNothing);
    expect(
        espia.llamadasA(
            RutasApi.postulacion(postulacionPendiente()['id'] as String)),
        0,
        reason: 'cancelar el diálogo no debe disparar el DELETE');
    // La postulación sigue en la lista, sin tocar.
    expect(find.text('Reparar tubería'), findsOneWidget);
  });

  testWidgets('confirmar el diálogo ("Sí") llama al servicio exactamente una '
      'vez', (tester) async {
    var llamadasDelete = 0;
    final espia = await montar(tester, responderDelete: (_) async {
      llamadasDelete++;
      return respuestaJson(null, 204);
    });

    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sí'));
    await tester.pumpAndSettle();

    expect(llamadasDelete, 1);
    expect(
        espia.llamadasA(
            RutasApi.postulacion(postulacionPendiente()['id'] as String)),
        1);
  });
}
