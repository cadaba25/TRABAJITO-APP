import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trabajito/services/api/almacen_sesion.dart';
import 'package:trabajito/services/api/api_client.dart';
import 'package:trabajito/services/api/api_excepciones.dart';
import 'package:trabajito/services/api/configuracion_api.dart';
import 'package:trabajito/services/api/sesion_api.dart';

import 'ayudas_api.dart';

void main() {
  group('ApiClient — cabeceras y cuerpo', () {
    test('adjunta Authorization: Bearer en las peticiones autenticadas',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (_) async => respuestaJson({'ok': true}, 200));
      final (cliente, _) =
          await clienteConSesion(mock, sesion: sesionDePrueba(token: 'abc123'));

      await cliente.obtener('/api/trabajos/mios');

      expect(autorizacionDe(espia.peticiones.single), 'Bearer abc123');
    });

    test('NO adjunta Authorization cuando la petición es pública', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(
          espia, (_) async => respuestaJson(cuerpoSesion(token: 't', refreshToken: 'r'), 200));
      final (cliente, _) = await clienteConSesion(mock);

      await cliente.crear(RutasApi.login,
          cuerpo: {'correo': 'a@b.c', 'password': 'x'},
          autenticada: false,
          esLogin: true);

      expect(autorizacionDe(espia.peticiones.single), isNull);
    });

    test('sin sesión, una petición autenticada falla antes de salir a la red',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (_) async => respuestaJson({}, 200));
      final (cliente, _) = await clienteConSesion(mock);

      await expectLater(
          cliente.obtener('/api/trabajos'), throwsA(isA<SesionInvalida>()));
      expect(espia.peticiones, isEmpty,
          reason: 'no tiene sentido gastar una petición que dará 401 seguro');
    });

    test('el cuerpo viaja como JSON en UTF-8', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (_) async => respuestaJson({'ok': true}, 200));
      final (cliente, _) = await clienteConSesion(mock, sesion: sesionDePrueba());

      await cliente.crear('/api/trabajos',
          cuerpo: {'titulo': 'Reparación de cañería en Tegucigalpa'});

      final enviada = espia.peticiones.single;
      expect(enviada.headers['content-type'], contains('application/json'));
      expect(
        jsonDecode(utf8.decode(enviada.bodyBytes)),
        {'titulo': 'Reparación de cañería en Tegucigalpa'},
      );
    });

    test('los parámetros de consulta se convierten a texto', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (_) async => respuestaJson({'content': []}, 200));
      final (cliente, _) = await clienteConSesion(mock, sesion: sesionDePrueba());

      await cliente.obtener('/api/trabajos',
          consulta: {'page': 2, 'size': 20, 'activo': true, 'vacio': null});

      final uri = espia.peticiones.single.url;
      expect(uri.queryParameters, {'page': '2', 'size': '20', 'activo': 'true'});
    });
  });

  group('ApiClient — traducción de errores del backend (ADR-0008)', () {
    test('400 con fields → ErrorDeValidacion con los campos marcables',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(
        espia,
        (_) async => respuestaError(400, 'Datos inválidos', campos: {
          'password': 'La contraseña debe tener al menos 10 caracteres',
          'correo': 'must be a well-formed email address',
        }),
      );
      final (cliente, _) = await clienteConSesion(mock, sesion: sesionDePrueba());

      final error = await cliente
          .crear('/api/trabajos', cuerpo: {})
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<ErrorDeValidacion>());
      final validacion = error! as ErrorDeValidacion;
      expect(validacion.mensaje, 'Datos inválidos');
      expect(validacion.campos['password'],
          'La contraseña debe tener al menos 10 caracteres');
      expect(validacion.campos, contains('correo'));
    });

    test('el mensaje llega con las tildes intactas aunque falte el charset',
        () async {
      // Spring manda `Content-Type: application/json` sin `charset`. Si el
      // cliente no forzara UTF-8, aquí saldría "SesiÃ³n invÃ¡lida".
      final espia = EspiaHttp();
      final mock = clienteFalso(espia,
          (_) async => respuestaError(409, 'La sesión ya está cerrada, ñandú'));
      final (cliente, _) = await clienteConSesion(mock, sesion: sesionDePrueba());

      final error = await cliente
          .crear('/api/trabajos/1/cancelar')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<ConflictoDeEstado>());
      expect((error! as ConflictoDeEstado).mensaje,
          'La sesión ya está cerrada, ñandú');
    });

    test('401 en el login → CredencialesInvalidas, no SesionInvalida', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia,
          (_) async => respuestaError(401, 'Correo o contraseña incorrectos'));
      final (cliente, _) = await clienteConSesion(mock);

      final error = await cliente
          .crear(RutasApi.login,
              cuerpo: {'correo': 'a@b.c', 'password': 'mala'},
              autenticada: false,
              esLogin: true)
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<CredencialesInvalidas>());
      expect((error! as ExcepcionApi).mensaje, 'Correo o contraseña incorrectos');
    });

    test('429 con Retry-After → DemasiadosIntentos con la espera legible',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(
        espia,
        (_) async => respuestaError(
          429,
          'Demasiados intentos fallidos para esta cuenta. '
              'Espera unos minutos e inténtalo de nuevo.',
          cabeceras: {'retry-after': '900'},
        ),
      );
      final (cliente, _) = await clienteConSesion(mock);

      final error = await cliente
          .crear(RutasApi.login,
              cuerpo: {'correo': 'a@b.c', 'password': 'x'},
              autenticada: false,
              esLogin: true)
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<DemasiadosIntentos>());
      final freno = error! as DemasiadosIntentos;
      expect(freno.reintentarEn, const Duration(seconds: 900));
      expect(freno.esperaLegible, '15 minutos');
      expect(freno.vaLaPenaReintentar, isTrue);
    });

    test('403 → SinPermiso; 404 → NoEncontrado; 500 → ErrorDelServidor',
        () async {
      Future<Object?> pedir(int estado, String mensaje) async {
        final espia = EspiaHttp();
        final mock =
            clienteFalso(espia, (_) async => respuestaError(estado, mensaje));
        final (cliente, _) =
            await clienteConSesion(mock, sesion: sesionDePrueba());
        return cliente
            .obtener('/api/algo')
            .then<Object?>((_) => null, onError: (Object e) => e);
      }

      expect(await pedir(403, 'No puedes ver esto'), isA<SinPermiso>());
      expect(await pedir(404, 'No existe'), isA<NoEncontrado>());
      expect(await pedir(500, 'Error interno del servidor'),
          isA<ErrorDelServidor>());
    });

    test('un 5xx sin cuerpo JSON no revienta: da ErrorDelServidor genérico',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(
        espia,
        (_) async => http.Response('<html>502 Bad Gateway</html>', 502,
            headers: {'content-type': 'text/html'}),
      );
      final (cliente, _) = await clienteConSesion(mock, sesion: sesionDePrueba());

      final error = await cliente
          .obtener('/api/algo')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<ErrorDelServidor>());
      expect((error! as ExcepcionApi).estado, 502);
    });

    test('204 sin cuerpo devuelve null en vez de fallar', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (_) async => http.Response('', 204));
      final (cliente, _) = await clienteConSesion(mock, sesion: sesionDePrueba());

      expect(await cliente.eliminar('/api/postulaciones/1'), isNull);
    });

    test('un 200 que no es JSON da RespuestaIlegible (apuntamos a otra cosa)',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(
          espia, (_) async => http.Response('inicia sesión en el wifi', 200));
      final (cliente, _) = await clienteConSesion(mock, sesion: sesionDePrueba());

      await expectLater(
          cliente.obtener('/api/algo'), throwsA(isA<RespuestaIlegible>()));
    });

    test('sin conexión → ErrorDeRed, que sí invita a reintentar', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (_) async {
        throw http.ClientException('Connection refused');
      });
      final (cliente, _) = await clienteConSesion(mock, sesion: sesionDePrueba());

      final error = await cliente
          .obtener('/api/algo')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<ErrorDeRed>());
      expect((error! as ErrorDeRed).vaLaPenaReintentar, isTrue);
    });

    test('si el servidor no contesta a tiempo → ErrorDeRed', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return respuestaJson({'ok': true}, 200);
      });
      final impaciente = ApiClient(
        clienteHttp: mock,
        almacen: AlmacenSesionEnMemoria(),
        urlBase: urlBaseDePrueba,
        tiempoLimite: const Duration(milliseconds: 20),
      );
      await impaciente.guardarSesion(sesionDePrueba());

      await expectLater(
          impaciente.obtener('/api/algo'), throwsA(isA<ErrorDeRed>()));
    });
  });

  group('ApiClient — renovación del token', () {
    test('renueva por adelantado si el token ya caducó, sin gastar un 401',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          return respuestaJson(
              cuerpoSesion(token: 'token-1', refreshToken: 'refresh-1'), 200);
        }
        return respuestaJson({'ok': true}, 200);
      });
      final (cliente, almacen) = await clienteConSesion(
        mock,
        // Token ya vencido: `caducado()` es cierto desde el primer momento.
        sesion: sesionDePrueba(vida: const Duration(seconds: -1)),
      );

      await cliente.obtener('/api/trabajos');

      expect(espia.rutas, [RutasApi.refresh, '/api/trabajos'],
          reason: 'primero renueva, después pide');
      expect(autorizacionDe(espia.ultimaA('/api/trabajos')), 'Bearer token-1');
      expect((await almacen.leerSesion())!.refreshToken, 'refresh-1',
          reason: 'el par nuevo queda guardado en el dispositivo');
    });

    test('usa el margen: renueva aunque falten pocos segundos para caducar',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          return respuestaJson(
              cuerpoSesion(token: 'token-1', refreshToken: 'refresh-1'), 200);
        }
        return respuestaJson({'ok': true}, 200);
      });
      // Caduca dentro del margen de renovación (30 s).
      final (cliente, _) = await clienteConSesion(mock,
          sesion: sesionDePrueba(
              vida: ConfiguracionApi.margenRenovacion -
                  const Duration(seconds: 5)));

      await cliente.obtener('/api/trabajos');

      expect(espia.llamadasA(RutasApi.refresh), 1);
    });

    test('un 401 inesperado renueva y reintenta exactamente una vez', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          return respuestaJson(
              cuerpoSesion(token: 'token-1', refreshToken: 'refresh-1'), 200);
        }
        return autorizacionDe(peticion) == 'Bearer token-1'
            ? respuestaJson({'ok': true}, 200)
            : respuestaError(401, 'No autenticado');
      });
      final (cliente, _) =
          await clienteConSesion(mock, sesion: sesionDePrueba());

      final respuesta = await cliente.obtener('/api/trabajos');

      expect(respuesta, {'ok': true});
      expect(espia.rutas,
          ['/api/trabajos', RutasApi.refresh, '/api/trabajos']);
    });

    test('si tras renovar sigue dando 401, no entra en bucle', () async {
      final espia = EspiaHttp();
      var refrescos = 0;
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          refrescos++;
          return respuestaJson(
              cuerpoSesion(
                  token: 'token-$refrescos', refreshToken: 'refresh-$refrescos'),
              200);
        }
        return respuestaError(401, 'No autenticado');
      });
      final (cliente, _) =
          await clienteConSesion(mock, sesion: sesionDePrueba());

      await expectLater(
          cliente.obtener('/api/trabajos'), throwsA(isA<SesionInvalida>()));
      expect(refrescos, 1, reason: 'un solo reintento, nunca un bucle');
    });

    test('si el refresh da 401, se borra la sesión y se avisa', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          return respuestaError(
              401, 'Sesión inválida o expirada. Inicia sesión de nuevo.');
        }
        return respuestaError(401, 'No autenticado');
      });
      final (cliente, almacen) =
          await clienteConSesion(mock, sesion: sesionDePrueba());

      final eventos = <EventoSesion>[];
      cliente.eventosSesion.listen(eventos.add);

      await expectLater(
          cliente.obtener('/api/trabajos'), throwsA(isA<SesionInvalida>()));
      await Future<void>.delayed(Duration.zero);

      expect(cliente.haySesion, isFalse);
      expect(await almacen.leerSesion(), isNull);
      expect(eventos, contains(EventoSesion.terminada));
    });

    test('si el refresh falla por red, la sesión NO se tira a la basura',
        () async {
      // Es importante: un túnel que se cae no debe expulsar al usuario. El
      // refresh token sigue siendo válido en el servidor.
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          throw http.ClientException('Network is unreachable');
        }
        return respuestaError(401, 'No autenticado');
      });
      final (cliente, almacen) =
          await clienteConSesion(mock, sesion: sesionDePrueba());

      await expectLater(
          cliente.obtener('/api/trabajos'), throwsA(isA<ErrorDeRed>()));

      expect(cliente.haySesion, isTrue);
      expect((await almacen.leerSesion())!.refreshToken, 'refresh-0');
    });
  });

  group('ApiClient — una sola renovación en vuelo (ADR-0010)', () {
    // El backend revoca TODA la familia de refresh tokens si se presenta uno
    // ya rotado. Verificado contra el servidor real el 2026-08-27: reusar el
    // token anterior invalidó también al que lo había sustituido. Si el
    // cliente permitiera dos refrescos a la vez, expulsaría usuarios al azar.

    test('5 peticiones que caducan a la vez producen UN solo refresh',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          // Un refresh lento es lo que hace que se solapen las demás.
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return respuestaJson(
              cuerpoSesion(token: 'token-1', refreshToken: 'refresh-1'), 200);
        }
        return autorizacionDe(peticion) == 'Bearer token-1'
            ? respuestaJson({'ruta': peticion.url.path}, 200)
            : respuestaError(401, 'No autenticado');
      });
      final (cliente, almacen) =
          await clienteConSesion(mock, sesion: sesionDePrueba());

      final respuestas = await Future.wait([
        cliente.obtener('/api/trabajos'),
        cliente.obtener('/api/postulaciones/mias'),
        cliente.obtener('/api/chats'),
        cliente.obtener('/api/cartera/movimientos'),
        cliente.obtener('/api/notificaciones/no-leidas'),
      ]);

      expect(espia.llamadasA(RutasApi.refresh), 1,
          reason: 'dos refrescos a la vez revocarían la familia entera');
      expect(respuestas, hasLength(5));
      // Todas se reintentaron con el token nuevo y salieron adelante.
      for (final respuesta in respuestas) {
        expect((respuesta! as Map)['ruta'], isNotNull);
      }
      expect((await almacen.leerSesion())!.token, 'token-1');
    });

    test(
        'una petición que despierta tarde NO refresca con el token viejo '
        '(es lo que revocaría la familia)', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          // Termina rápido, mucho antes de que la petición lenta reciba su 401.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return respuestaJson(
              cuerpoSesion(token: 'token-1', refreshToken: 'refresh-1'), 200);
        }
        if (peticion.url.path == '/api/lento') {
          // Su 401 llega cuando la renovación ya terminó y ya no hay ninguna
          // "en vuelo": el único candado que la salva es comparar el refresh
          // token que ella vio con el que hay guardado ahora.
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        return autorizacionDe(peticion) == 'Bearer token-1'
            ? respuestaJson({'ruta': peticion.url.path}, 200)
            : respuestaError(401, 'No autenticado');
      });
      final (cliente, _) =
          await clienteConSesion(mock, sesion: sesionDePrueba());

      final resultados = await Future.wait([
        cliente.obtener('/api/rapido'),
        cliente.obtener('/api/lento'),
      ]);

      expect(espia.llamadasA(RutasApi.refresh), 1,
          reason: 'la petición lenta debe reutilizar la sesión ya renovada');
      expect((resultados[1]! as Map)['ruta'], '/api/lento');
      // El refresh que llegó al servidor fue el original, una sola vez.
      final cuerpoRefresh = jsonDecode(
          utf8.decode(espia.ultimaA(RutasApi.refresh).bodyBytes)) as Map;
      expect(cuerpoRefresh['refreshToken'], 'refresh-0');
    });

    test('la sesión se guarda una sola vez aunque cinco peticiones esperen',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return respuestaJson(
              cuerpoSesion(token: 'token-1', refreshToken: 'refresh-1'), 200);
        }
        return autorizacionDe(peticion) == 'Bearer token-1'
            ? respuestaJson({'ok': true}, 200)
            : respuestaError(401, 'No autenticado');
      });
      final (cliente, almacen) =
          await clienteConSesion(mock, sesion: sesionDePrueba());
      final escriturasIniciales = almacen.escrituras;

      await Future.wait(List.generate(5, (i) => cliente.obtener('/api/x$i')));

      expect(almacen.escrituras - escriturasIniciales, 1);
    });

    test('tras renovar, la siguiente caducidad sí lanza un refresh nuevo',
        () async {
      final espia = EspiaHttp();
      var refrescos = 0;
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          refrescos++;
          return respuestaJson(
              cuerpoSesion(
                token: 'token-$refrescos',
                refreshToken: 'refresh-$refrescos',
                // Vidas de 0 s: cada petición vuelve a encontrar el token
                // caducado y tiene que renovar otra vez.
                expiraEnSegundos: 0,
              ),
              200);
        }
        return respuestaJson({'ok': true}, 200);
      });
      final (cliente, _) = await clienteConSesion(mock,
          sesion: sesionDePrueba(vida: const Duration(seconds: -1)));

      await cliente.obtener('/api/a');
      await cliente.obtener('/api/b');

      expect(refrescos, 2,
          reason: 'el candado solo agrupa las simultáneas, no bloquea para siempre');
    });
  });

  group('ApiClient contra un backend que castiga la reutilización', () {
    // Estos tres tests usan un servidor de mentira que rota el refresh token y
    // **revoca la familia entera** si recibe uno ya usado, igual que el real.
    // No hace falta desactivar nada del cliente para saber si los candados
    // funcionan: si fallaran, este backend expulsaría al usuario y los
    // `expect` de abajo se pondrían rojos.

    test('diez peticiones simultáneas caducadas no expulsan al usuario',
        () async {
      final backend = BackendFalsoConRotacion();
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, backend.responder),
        sesion: sesionDePrueba(vida: const Duration(seconds: -1)),
      );

      final respuestas = await Future.wait(
          List.generate(10, (i) => cliente.obtener('/api/recurso$i')));

      expect(backend.familiaRevocada, isFalse,
          reason: 'dos refrescos con el mismo token habrían revocado la familia');
      expect(backend.refrescos, 1);
      expect(cliente.haySesion, isTrue);
      expect(respuestas.map((r) => (r! as Map)['ruta']),
          List.generate(10, (i) => '/api/recurso$i'));
    });

    test('una petición lenta que despierta tras la renovación tampoco',
        () async {
      final backend = BackendFalsoConRotacion(
        retrasoDelRefresh: const Duration(milliseconds: 10),
      )..retrasosPorRuta['/api/lento'] = const Duration(milliseconds: 120);
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, backend.responder),
        sesion: sesionDePrueba(),
      );
      backend.caducarAccessToken();

      final resultados = await Future.wait([
        cliente.obtener('/api/rapido'),
        cliente.obtener('/api/lento'),
      ]);

      expect(backend.familiaRevocada, isFalse);
      expect(backend.refrescos, 1);
      expect((resultados[1]! as Map)['ruta'], '/api/lento');
      expect(cliente.haySesion, isTrue);
    });

    test('varias rondas seguidas siguen sin reutilizar ningún token', () async {
      // El access token dura 0 s: cada ronda obliga a renovar de nuevo. Lo que
      // no debe pasar nunca es presentar dos veces el mismo refresh.
      final backend = BackendFalsoConRotacion(
        retrasoDelRefresh: const Duration(milliseconds: 5),
        vidaDelAccessEnSegundos: 0,
      );
      final espia = EspiaHttp();
      final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, backend.responder),
        sesion: sesionDePrueba(vida: const Duration(seconds: -1)),
      );

      for (var ronda = 0; ronda < 3; ronda++) {
        await Future.wait(
            List.generate(4, (i) => cliente.obtener('/api/r$ronda-$i')));
      }

      expect(backend.familiaRevocada, isFalse);
      expect(backend.refrescos, 3, reason: 'una renovación por ronda');
      expect(cliente.haySesion, isTrue);
    });
  });

  group('ApiClient — cierre de sesión', () {
    test('revoca el refresh token en el servidor y limpia el dispositivo',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (_) async => http.Response('', 204));
      final (cliente, almacen) =
          await clienteConSesion(mock, sesion: sesionDePrueba());

      await cliente.cerrarSesion();

      final enviada = espia.ultimaA(RutasApi.logout);
      expect(jsonDecode(utf8.decode(enviada.bodyBytes)),
          {'refreshToken': 'refresh-0'});
      expect(cliente.haySesion, isFalse);
      expect(await almacen.leerSesion(), isNull);
    });

    test('si el servidor no responde, la sesión local se borra igual',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (_) async {
        throw http.ClientException('Network is unreachable');
      });
      final (cliente, almacen) =
          await clienteConSesion(mock, sesion: sesionDePrueba());

      await cliente.cerrarSesion();

      expect(cliente.haySesion, isFalse);
      expect(await almacen.leerSesion(), isNull);
    });
  });

  group('ApiClient.construirUri', () {
    test('une base y ruta sin duplicar la barra', () {
      expect(ApiClient.construirUri('http://x:8080/', '/api/trabajos').toString(),
          'http://x:8080/api/trabajos');
      expect(ApiClient.construirUri('http://x:8080', 'api/trabajos').toString(),
          'http://x:8080/api/trabajos');
    });

    test('respeta los parámetros que ya trae la ruta', () {
      final uri = ApiClient.construirUri(
          'http://x:8080', '/api/trabajos?ciudad=Tegucigalpa', {'page': 1});
      expect(uri.queryParameters, {'ciudad': 'Tegucigalpa', 'page': '1'});
    });
  });
}
