// Tarea 052: CarteraScreen con servicios inyectados, contra un backend falso.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/funcionalidades/cartera/pantallas/cartera_screen.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/configuracion_api.dart';
import 'package:trabajito/nucleo/inyeccion/proveedores.dart';
import 'package:trabajito/nucleo/sesion/sesion_usuario.dart';

import '../../api/ayudas_api.dart';

const _idTarjeta = 'b7e1c9a0-1d2e-4f3a-8b4c-5d6e7f8a9b0c';

Map<String, dynamic> _perfil(num saldo) => {
      'id': '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc',
      'correo': 'ana@trabajito.test',
      'nombres': 'Ana',
      'apellidos': 'Qa',
      'rol': 'TRABAJADOR',
      'saldo': saldo,
    };

Map<String, dynamic> _tarjeta() => {
      'id': _idTarjeta,
      'marca': 'Visa',
      'ultimos4': '4242',
      'titular': 'Ana Qa',
      'vencimiento': '12/28',
    };

void main() {
  tearDown(() {
    ApiClient.fijarInstancia(null);
    sesionActual.salir();
  });

  Future<EspiaHttp> montar(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) responder,
  ) async {
    final espia = EspiaHttp();
    final (cliente, _) = await clienteConSesion(
      clienteFalso(espia, responder),
      sesion: sesionDePrueba(),
    );
    ApiClient.fijarInstancia(cliente);
    final usuario = Usuario.desdeJson(_perfil(25.5));
    sesionActual.entrar(usuario);
    await tester.pumpWidget(MultiProvider(
      providers: proveedoresDeLaApp(),
      child: MaterialApp(home: CarteraScreen(usuario: usuario)),
    ));
    await tester.pumpAndSettle();
    return espia;
  }

  testWidgets('enseña el saldo de la sesión y las tarjetas del servidor',
      (tester) async {
    final espia = await montar(tester, (p) async {
      if (p.url.path == RutasApi.tarjetas) {
        return respuestaJson([_tarjeta()], 200);
      }
      if (p.url.path == RutasApi.yo) return respuestaJson(_perfil(80), 200);
      return respuestaError(404, 'ruta inesperada ${p.url.path}');
    });

    expect(find.text('Visa •••• 4242'), findsOneWidget);
    // El saldo se refrescó al entrar (recargarPerfil), sin stream.
    expect(find.text('L. 80.00'), findsOneWidget);
    expect(espia.llamadasA(RutasApi.tarjetas), 1);
    expect(espia.llamadasA(RutasApi.yo), 1);
  });

  testWidgets('sin tarjetas lo dice; si la carga falla, no finge que no hay',
      (tester) async {
    await montar(tester, (p) async {
      if (p.url.path == RutasApi.tarjetas) {
        return respuestaError(500, 'boom');
      }
      return respuestaJson(_perfil(25.5), 200);
    });
    expect(find.text('No tienes tarjetas guardadas.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('borrar una tarjeta hace DELETE por id y vuelve a listar',
      (tester) async {
    var borrada = false;
    final espia = await montar(tester, (p) async {
      if (p.url.path == RutasApi.tarjetas) {
        return respuestaJson(borrada ? [] : [_tarjeta()], 200);
      }
      if (p.method == 'DELETE' && p.url.path == RutasApi.tarjeta(_idTarjeta)) {
        borrada = true;
        return respuestaJson(null, 200);
      }
      return respuestaJson(_perfil(25.5), 200);
    });

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(espia.llamadasA(RutasApi.tarjeta(_idTarjeta)), 1);
    expect(find.text('Visa •••• 4242'), findsNothing);
    expect(find.text('No tienes tarjetas guardadas.'), findsOneWidget);
  });

  testWidgets('recargar manda el monto y refresca el saldo', (tester) async {
    var recargado = false;
    final espia = await montar(tester, (p) async {
      if (p.url.path == RutasApi.tarjetas) return respuestaJson([], 200);
      if (p.url.path == RutasApi.recargar) {
        recargado = true;
        return respuestaJson(125.5, 200);
      }
      return respuestaJson(_perfil(recargado ? 125.5 : 25.5), 200);
    });

    await tester.tap(find.text('Recargar saldo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Recargar'));
    await tester.pumpAndSettle();

    expect(espia.llamadasA(RutasApi.recargar), 1);
    expect(find.text('L. 125.50'), findsOneWidget);
  });
}
