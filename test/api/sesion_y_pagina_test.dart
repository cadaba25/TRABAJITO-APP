import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/services/api/api_excepciones.dart';
import 'package:trabajito/services/api/configuracion_api.dart';
import 'package:trabajito/services/api/pagina_api.dart';
import 'package:trabajito/services/api/sesion_api.dart';

void main() {
  group('SesionApi', () {
    // Estructura copiada de POST /api/auth/login contra el servidor real
    // (2026-08-27). Los dos tokens están SUSTITUIDOS por valores inventados
    // de la misma forma: no se commitea un token de verdad, aunque sea de una
    // cuenta de prueba desechable (regla 6 de CLAUDE.md).
    final respuestaReal = <String, dynamic>{
      'token': 'eyJhbGciOiJIUzUxMiJ9.token-de-mentira-para-el-test.firma',
      'refreshToken': 'refresh-de-mentira-43-caracteres-aaaaaaaaaa',
      'tokenType': 'Bearer',
      'expiraEnSegundos': 900,
      'usuario': {
        'id': '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc',
        'correo': 'f018@trabajito.test',
        'rol': 'TRABAJADOR',
        'saldo': 0.00,
      },
    };

    test('lee la respuesta real del backend', () {
      final ahora = DateTime(2026, 8, 27, 12);
      final sesion = SesionApi.desdeJson(respuestaReal, ahora: ahora);

      expect(sesion.token, respuestaReal['token']);
      expect(sesion.refreshToken, respuestaReal['refreshToken']);
      expect(sesion.tipoToken, 'Bearer');
      // 900 s = los 15 minutos de ADR-0010.
      expect(sesion.expiraEn, ahora.add(const Duration(seconds: 900)));
      expect(sesion.usuario['correo'], 'f018@trabajito.test');
      expect(sesion.cabeceraAutorizacion, 'Bearer ${respuestaReal['token']}');
    });

    test('una respuesta sin tokens es un error, no una sesión a medias', () {
      expect(() => SesionApi.desdeJson({'usuario': {}}),
          throwsA(isA<FormatException>()));
      expect(() => SesionApi.desdeJson({'token': 'x'}),
          throwsA(isA<FormatException>()));
    });

    test('caducado() respeta el margen de renovación', () {
      final ahora = DateTime.now();
      final sesion = SesionApi(
        token: 't',
        refreshToken: 'r',
        expiraEn: ahora.add(const Duration(seconds: 20)),
      );

      expect(sesion.caducado(), isFalse);
      expect(sesion.caducado(margen: const Duration(seconds: 30)), isTrue,
          reason: 'con 20 s de vida y 30 s de margen hay que renovar ya');
    });

    test('sobrevive a guardar y volver a leer', () {
      final original = SesionApi.desdeJson(respuestaReal);
      final recuperada = SesionApi.deserializar(original.serializar())!;

      expect(recuperada.token, original.token);
      expect(recuperada.refreshToken, original.refreshToken);
      expect(recuperada.usuario['correo'], original.usuario['correo']);
      // La caducidad se guarda como marca absoluta: al reabrir la app dentro
      // de 20 min el token debe salir caducado, no "recién emitido".
      expect(recuperada.expiraEn.toIso8601String(),
          original.expiraEn.toIso8601String());
    });

    test('lo guardado en un formato viejo o corrupto se descarta sin reventar',
        () {
      expect(SesionApi.deserializar(null), isNull);
      expect(SesionApi.deserializar(''), isNull);
      expect(SesionApi.deserializar('esto no es json'), isNull);
      expect(SesionApi.deserializar('{"token":"x"}'), isNull);
    });

    test('toString no filtra los tokens a los logs', () {
      final sesion = SesionApi.desdeJson(respuestaReal);
      expect(sesion.toString(), isNot(contains(sesion.token)));
      expect(sesion.toString(), isNot(contains(sesion.refreshToken)));
    });
  });

  group('PaginaApi', () {
    // Envoltorio copiado de GET /api/trabajos?page=0&size=1 contra el servidor.
    final paginaReal = <String, dynamic>{
      'content': [
        {'id': 'a', 'titulo': 'Prueba fase 1'},
        {'id': 'b', 'titulo': 'Concurrencia C'},
      ],
      'pageable': {'pageNumber': 0, 'pageSize': 20, 'offset': 0},
      'totalElements': 27,
      'totalPages': 2,
      'last': false,
      'first': true,
      'numberOfElements': 20,
      'size': 20,
      'number': 0,
      'empty': false,
    };

    test('lee el envoltorio de Spring', () {
      final pagina =
          PaginaApi.desdeJson(paginaReal, (e) => e['titulo'] as String);

      expect(pagina.elementos, ['Prueba fase 1', 'Concurrencia C']);
      expect(pagina.totalElementos, 27);
      expect(pagina.totalPaginas, 2);
      expect(pagina.pagina, 0);
      expect(pagina.hayMas, isTrue);
      expect(pagina.paginaSiguiente, 1);
    });

    test('la última página no ofrece siguiente', () {
      final pagina = PaginaApi.desdeJson(
        {...paginaReal, 'last': true, 'first': false, 'number': 1},
        (e) => e['id'] as String,
      );
      expect(pagina.hayMas, isFalse);
      expect(pagina.paginaSiguiente, isNull);
    });

    test('un array pelado se trata como página única', () {
      final pagina = PaginaApi.desdeJson(
        [
          {'id': 'a'},
          {'id': 'b'},
        ],
        (e) => e['id'] as String,
      );

      expect(pagina.elementos, ['a', 'b']);
      expect(pagina.esPrimera && pagina.esUltima, isTrue);
      expect(pagina.hayMas, isFalse);
      expect(pagina.totalElementos, 2);
    });

    test('una página vacía no es un error', () {
      final pagina = PaginaApi.desdeJson(
        {'content': <Object?>[], 'totalElements': 0, 'last': true},
        (e) => e['id'] as String,
      );
      expect(pagina.estaVacia, isTrue);
      expect(pagina.elementos, isEmpty);
    });

    test('si no es ni lista ni página, RespuestaIlegible', () {
      expect(() => PaginaApi.desdeJson({'algo': 1}, (e) => e),
          throwsA(isA<RespuestaIlegible>()));
      expect(() => PaginaApi.desdeJson('texto suelto', (e) => e),
          throwsA(isA<RespuestaIlegible>()));
      expect(() => PaginaApi.desdeJson({'content': 'no es lista'}, (e) => e),
          throwsA(isA<RespuestaIlegible>()));
    });
  });

  group('ConfiguracionApi', () {
    tearDown(() => ConfiguracionApi.fijarUrlBase(null));

    test('normalizar quita las barras finales', () {
      expect(ConfiguracionApi.normalizar('http://x:8080///'), 'http://x:8080');
      expect(ConfiguracionApi.normalizar('  http://x:8080 '), 'http://x:8080');
    });

    test('el override en caliente manda sobre el valor por defecto', () {
      final porDefecto = ConfiguracionApi.urlBase;

      ConfiguracionApi.fijarUrlBase('http://192.168.0.15:8080/');
      expect(ConfiguracionApi.urlBase, 'http://192.168.0.15:8080');
      expect(ConfiguracionApi.urlConfigurada, isTrue);

      ConfiguracionApi.fijarUrlBase(null);
      expect(ConfiguracionApi.urlBase, porDefecto);
    });

    test('el valor por defecto apunta al puerto del backend', () {
      expect(ConfiguracionApi.urlBasePorDefecto, endsWith(':8080'));
      // En el emulador de Android, `localhost` es el propio emulador; el PC se
      // ve en 10.0.2.2. Fuera de Android (tests incluidos) vale localhost.
      expect(ConfiguracionApi.urlBasePorDefecto,
          anyOf(contains('10.0.2.2'), contains('localhost')));
    });
  });

  group('leerRetryAfter', () {
    test('lee los segundos que manda este backend', () {
      expect(leerRetryAfter('900'), const Duration(seconds: 900));
      expect(leerRetryAfter('0'), Duration.zero);
    });

    test('acepta también una fecha HTTP y no se queja de lo demás', () {
      expect(leerRetryAfter(null), isNull);
      expect(leerRetryAfter('   '), isNull);
      expect(leerRetryAfter('mañana'), isNull);
      final futuro = DateTime.now().add(const Duration(seconds: 60));
      expect(leerRetryAfter(futuro.toIso8601String())!.inSeconds,
          closeTo(60, 2));
    });
  });
}
