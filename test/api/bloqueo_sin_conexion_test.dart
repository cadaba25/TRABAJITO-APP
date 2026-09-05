// ADR-0013: sin sesión confirmada, la app **no ejecuta ninguna acción que
// cree o modifique datos**, y se lo dice al usuario.
//
// Por qué esto necesita tests propios y no basta con "ya lo hará la pantalla":
//
// Firestore encolaba las escrituras sin conexión y las sincronizaba después,
// así que publicar sin señal "funcionaba" de una forma que el usuario no veía.
// Contra HTTP ese encolado no existe. Si nadie lo trata, la migración deja un
// comportamiento PEOR que el anterior sin que se note: un botón girando, o un
// "listo" que no guardó nada.
//
// La comprobación vive en un solo sitio (`ApiClient.exigirSesionConfirmada`),
// justamente para que ninguna de las nueve pantallas migradas pueda olvidarse
// de ella. Estos tests fijan las cuatro cosas que tienen que seguir siendo
// verdad:
//
//   1. Una escritura sin sesión confirmada NO sale a la red.
//   2. Una lectura sí sale: "leer sí, escribir no" es literal.
//   3. Si al comprobarlo resulta que la conexión ya volvió, la escritura
//      continúa sola: la app se cura sin que el usuario tenga que buscar dónde
//      deslizar.
//   4. Dos escrituras a la vez comparten una sola comprobación.
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/models/publicacion.dart';
import 'package:trabajito/models/usuario.dart';
import 'package:trabajito/services/api/api_client.dart';
import 'package:trabajito/services/api/api_excepciones.dart';
import 'package:trabajito/services/auth_service.dart';
import 'package:trabajito/services/publicacion_service.dart';
import 'package:trabajito/services/sesion_usuario.dart';
import 'package:trabajito/utils/constantes.dart';

import 'ayudas_api.dart';

Usuario usuarioDePrueba() => Usuario(
      uid: '67d11167-16e0-4172-a0ca-b92b0de663f8',
      tipoUsuario: 'trabajador',
      nombres: 'Carlos',
      apellidos: 'Demo',
      correo: 'demo@trabajito.com',
      rol: 'trabajador',
      fechaRegistro: DateTime(2026, 8, 28),
    );

void main() {
  group('ApiClient — la comprobación en su único sitio', () {
    test('una escritura sin sesión confirmada no sale a la red', () async {
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (_) async {
          fail('No debería salir ninguna petición de escritura');
        }),
        sesion: sesionDePrueba(),
      );
      cliente.exigirSesionConfirmada(() async => false);

      await expectLater(
        cliente.crear('/api/trabajos', cuerpo: {'titulo': 'x'}),
        throwsA(isA<SinConexionConfirmada>()),
      );
      expect(espia.peticiones, isEmpty);
    });

    test('el mensaje promete lo único que la app puede prometer: que no se '
        'envió nada', () async {
      const excepcion = SinConexionConfirmada();
      expect(excepcion.mensaje, MensajesError.sinConexionNoSeEscribe);
      expect(excepcion.mensaje, contains('No se ha enviado nada'));
      expect(excepcion.vaLaPenaReintentar, isTrue);
    });

    test('leer sí se permite: la regla es "leer sí, escribir no"', () async {
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (_) async => respuestaJson({'ok': true}, 200)),
        sesion: sesionDePrueba(),
      );
      cliente.exigirSesionConfirmada(() async => false);

      await cliente.obtener('/api/trabajos');

      expect(espia.rutas, ['/api/trabajos']);
    });

    test('los cuatro verbos de escritura quedan bloqueados', () async {
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (_) async {
          fail('No debería salir ninguna petición');
        }),
        sesion: sesionDePrueba(),
      );
      cliente.exigirSesionConfirmada(() async => false);

      for (final operacion in <Future<Object?> Function()>[
        () => cliente.crear('/api/trabajos', cuerpo: const {}),
        () => cliente.reemplazar('/api/usuarios/me', cuerpo: const {}),
        () => cliente.modificar('/api/usuarios/me', cuerpo: const {}),
        () => cliente.eliminar('/api/postulaciones/p1'),
      ]) {
        await expectLater(operacion(), throwsA(isA<SinConexionConfirmada>()));
      }
      expect(espia.peticiones, isEmpty);
    });

    test(
        'si al comprobarlo la conexión ya volvió, la escritura sigue adelante',
        () async {
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (_) async => respuestaJson({'id': 'nuevo'}, 200)),
        sesion: sesionDePrueba(),
      );
      var confirmaciones = 0;
      cliente.exigirSesionConfirmada(() async {
        confirmaciones++;
        return true; // la conexión volvió al intentar confirmarla
      });

      await cliente.crear('/api/trabajos', cuerpo: {'titulo': 'x'});

      expect(confirmaciones, 1);
      expect(espia.rutas, ['/api/trabajos']);
    });

    test('dos escrituras simultáneas comparten una sola comprobación',
        () async {
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (_) async => respuestaJson({'ok': true}, 200)),
        sesion: sesionDePrueba(),
      );
      var confirmaciones = 0;
      cliente.exigirSesionConfirmada(() async {
        confirmaciones++;
        // Confirmar cuesta una petición al servidor; si no se serializara,
        // cada botón pulsado gastaría la suya.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return true;
      });

      await Future.wait([
        cliente.crear('/api/trabajos', cuerpo: const {}),
        cliente.crear('/api/postulaciones', cuerpo: const {}),
      ]);

      expect(confirmaciones, 1);
      expect(espia.peticiones, hasLength(2));
    });

    test('si la propia comprobación revienta, se bloquea igual', () async {
      // Ante la duda no se escribe, y sobre todo: nunca se deja escapar una
      // excepción que las pantallas no sepan traducir.
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (_) async {
          fail('No debería salir ninguna petición');
        }),
        sesion: sesionDePrueba(),
      );
      cliente.exigirSesionConfirmada(() async => throw StateError('boom'));

      await expectLater(
        cliente.crear('/api/trabajos', cuerpo: const {}),
        throwsA(isA<SinConexionConfirmada>()),
      );
    });

    test('sin comprobación instalada, todo pasa (tests y arranques sueltos)',
        () async {
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (_) async => respuestaJson({'ok': true}, 200)),
        sesion: sesionDePrueba(),
      );

      await cliente.crear('/api/trabajos', cuerpo: const {});

      expect(espia.rutas, ['/api/trabajos']);
    });
  });

  group('De punta a punta: publicar sin conexión confirmada', () {
    tearDown(() {
      sesionActual.salir();
      ApiClient.fijarInstancia(null);
    });

    test(
        'publicar con el perfil sin confirmar no manda nada y el usuario recibe '
        'un mensaje claro', () async {
      final espia = EspiaHttp();
      // El servidor está caído: cualquier intento de confirmar la sesión falla.
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (_) async {
          throw const _SinRed();
        }),
        sesion: sesionDePrueba(),
      );

      // Estado real tras arrancar sin conexión con sesión guardada (tarea 023).
      sesionActual.entrar(usuarioDePrueba(), perfilSinConfirmar: true);
      AuthService(cliente: cliente).vigilarEscriturasSinConexion();

      final error = await PublicacionService(cliente: cliente).crearPublicacion(
        publicacionDePrueba(),
      );

      expect(error, MensajesError.sinConexionNoSeEscribe);
      // Lo que de verdad se está comprobando: NO se creó ningún trabajo.
      expect(espia.rutas, isNot(contains('/api/trabajos')));
      // Y el aviso sigue puesto, porque no se pudo confirmar nada.
      expect(sesionActual.value.avisoSinConexion, isTrue);
    });

    test(
        'si la conexión vuelve, la misma acción se ejecuta y el aviso '
        'desaparece', () async {
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (peticion) async {
          if (peticion.url.path == '/api/auth/yo') {
            return respuestaJson(_perfilDelServidor, 200);
          }
          return respuestaJson({'id': 'trabajo-nuevo'}, 200);
        }),
        sesion: sesionDePrueba(),
      );

      sesionActual.entrar(usuarioDePrueba(), perfilSinConfirmar: true);
      AuthService(cliente: cliente).vigilarEscriturasSinConexion();

      final error = await PublicacionService(cliente: cliente)
          .crearPublicacion(publicacionDePrueba());

      expect(error, isNull);
      // Primero se confirmó la sesión y solo entonces salió la escritura.
      expect(espia.rutas, ['/api/auth/yo', '/api/trabajos']);
      expect(sesionActual.value.avisoSinConexion, isFalse);
    });

    test('con la sesión ya confirmada no se gasta ninguna comprobación',
        () async {
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, (_) async => respuestaJson({'id': 'x'}, 200)),
        sesion: sesionDePrueba(),
      );

      sesionActual.entrar(usuarioDePrueba());
      AuthService(cliente: cliente).vigilarEscriturasSinConexion();

      await PublicacionService(cliente: cliente)
          .crearPublicacion(publicacionDePrueba());

      // Ni un `GET /api/auth/yo` de más: el caso normal no puede pagar peaje.
      expect(espia.rutas, ['/api/trabajos']);
    });
  });
}

/// Fallo de red que `ApiClient` traduce a `ErrorDeRed`.
class _SinRed implements Exception {
  const _SinRed();
}

Publicacion publicacionDePrueba() => Publicacion(
      uidEmpleador: 'u',
      autor: 'Carlos Demo',
      categoria: 'Construccion',
      titulo: 'Pintar sala',
      descripcion: 'Dos paredes',
      fechaCreacion: DateTime(2026, 9, 4),
    );

const Map<String, dynamic> _perfilDelServidor = {
  'id': '67d11167-16e0-4172-a0ca-b92b0de663f8',
  'correo': 'demo@trabajito.com',
  'nombres': 'Carlos',
  'apellidos': 'Demo',
  'nombreCompleto': 'Carlos Demo',
  'rol': 'TRABAJADOR',
  'activo': true,
  'registroCompleto': true,
  'creadoEn': '2026-08-28T05:29:52.816178Z',
  'pais': 'Honduras',
  'viveEnHonduras': true,
  'habilidades': <String>[],
  'experiencia': <Object>[],
  'estudios': <Object>[],
};
