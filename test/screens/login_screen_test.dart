// Regresión de la tarea 022 (revisión de QA de la migración).
//
// El botón "Iniciar sesión" ya se desactivaba mientras la petición estaba en
// vuelo (`onPressed: _cargando ? null : _iniciarSesion`), pero el campo de la
// contraseña llama al MISMO método desde la tecla "listo" del teclado
// (`alTerminar`), y ese camino no pasaba por el botón: pulsar "listo" dos
// veces seguidas lanzaba **dos** `POST /api/auth/login`.
//
// No es cosmético: cada login abre una familia de refresh tokens nueva en el
// servidor (ADR-0010) y la segunda respuesta pisa la sesión de la primera,
// dejando viva y sin revocar la familia que se acaba de descartar. Es la
// misma clase de fallo que el histórico de "botones que se quedaban cargando
// por multi-toque".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/screens/login_screen.dart';
import 'package:trabajito/widgets/custom_textfield.dart';
import 'package:trabajito/services/api/api_client.dart';
import 'package:trabajito/services/api/configuracion_api.dart';
import 'package:trabajito/services/sesion_usuario.dart';

import '../api/ayudas_api.dart';

void main() {
  tearDown(() {
    ApiClient.fijarInstancia(null);
    sesionActual.salir();
  });

  testWidgets('pulsar "listo" dos veces manda UN solo login', (tester) async {
    final espia = EspiaHttp();
    final (cliente, _) = await clienteConSesion(
      clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.login) {
          // Login lento: es lo que deja hueco al segundo envío.
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return respuestaJson(
              cuerpoSesion(token: 'token-0', refreshToken: 'refresh-0'), 200);
        }
        if (peticion.url.path == RutasApi.yo) {
          return respuestaJson({
            'id': '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc',
            'correo': 'ana@trabajito.test',
            'nombres': 'Ana',
            'apellidos': 'QaVeintidos',
            'rol': 'TRABAJADOR',
            'activo': true,
            'habilidades': const <String>[],
            'experiencia': const <Map<String, dynamic>>[],
            'estudios': const <Map<String, dynamic>>[],
          }, 200);
        }
        return respuestaError(404, 'ruta inesperada: ${peticion.url.path}');
      }),
    );
    ApiClient.fijarInstancia(cliente);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).first, 'ana@trabajito.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'QaTrabajito2026');

    // Dos eventos "listo" en el mismo frame: es lo que llega si el usuario
    // pulsa la tecla dos veces seguidas. Se invoca el callback del campo
    // directamente porque `testTextInput.receiveAction` no deja solapar dos
    // llamadas (TestAsyncUtils lo prohíbe), y aquí lo que se prueba es
    // justamente el solape.
    final campo =
        tester.widget<CustomTextField>(find.byType(CustomTextField).at(1));
    campo.alTerminar!("QaTrabajito2026");
    campo.alTerminar!("QaTrabajito2026");
    await tester.pumpAndSettle();

    expect(espia.llamadasA(RutasApi.login), 1,
        reason: 'dos logins abren dos familias de refresh tokens y la segunda '
            'sesión pisa a la primera, que queda viva y sin revocar');
  });
}
