import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trabajito/services/api/almacen_sesion.dart';
import 'package:trabajito/services/api/api_client.dart';
import 'package:trabajito/services/api/sesion_api.dart';

/// URL de mentira: nunca se abre un socket, `MockClient` responde en memoria.
const String urlBaseDePrueba = 'http://servidor.de.prueba:8080';

/// Registro de lo que se pidió, para poder afirmar sobre las cabeceras, el
/// cuerpo y —sobre todo— **cuántas veces** se llamó a `/api/auth/refresh`.
class EspiaHttp {
  final List<http.Request> peticiones = [];

  int llamadasA(String ruta) =>
      peticiones.where((p) => p.url.path == ruta).length;

  http.Request ultimaA(String ruta) =>
      peticiones.lastWhere((p) => p.url.path == ruta);

  List<String> get rutas => peticiones.map((p) => p.url.path).toList();
}

/// Construye un `MockClient` que anota cada petición en [espia] antes de
/// delegar en [responder].
MockClient clienteFalso(
  EspiaHttp espia,
  Future<http.Response> Function(http.Request peticion) responder,
) {
  return MockClient((peticion) async {
    espia.peticiones.add(peticion);
    return responder(peticion);
  });
}

/// Respuesta JSON codificada en UTF-8 sin `charset` en el `Content-Type`,
/// que es exactamente como responde Spring Boot. Importa: si se usara
/// `http.Response(String, ...)` el paquete `http` la codificaría en latin-1 y
/// el test no probaría el mismo camino que la app.
http.Response respuestaJson(
  Object? cuerpo,
  int estado, {
  Map<String, String> cabeceras = const {},
}) {
  return http.Response.bytes(
    cuerpo == null ? const <int>[] : utf8.encode(jsonEncode(cuerpo)),
    estado,
    headers: {'content-type': 'application/json', ...cabeceras},
  );
}

/// Error con el formato estándar del backend (ADR-0008).
http.Response respuestaError(
  int estado,
  String mensaje, {
  Map<String, String>? campos,
  Map<String, String> cabeceras = const {},
}) {
  return respuestaJson(
    {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'status': estado,
      'error': 'Error',
      'message': mensaje,
      if (campos != null) 'fields': campos,
    },
    estado,
    cabeceras: cabeceras,
  );
}

/// Cuerpo de `/api/auth/login|registro|refresh` con la forma real verificada
/// contra el servidor el 2026-08-27.
Map<String, dynamic> cuerpoSesion({
  required String token,
  required String refreshToken,
  int expiraEnSegundos = 900,
  String correo = 'prueba@trabajito.test',
}) =>
    {
      'token': token,
      'refreshToken': refreshToken,
      'tokenType': 'Bearer',
      'expiraEnSegundos': expiraEnSegundos,
      'usuario': {
        'id': '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc',
        'correo': correo,
        'nombres': 'Fase',
        'apellidos': 'Uno',
        'nombreCompleto': 'Fase Uno',
        'rol': 'TRABAJADOR',
      },
    };

SesionApi sesionDePrueba({
  String token = 'token-0',
  String refreshToken = 'refresh-0',
  Duration vida = const Duration(minutes: 15),
}) =>
    SesionApi(
      token: token,
      refreshToken: refreshToken,
      expiraEn: DateTime.now().add(vida),
      usuario: const {'correo': 'prueba@trabajito.test'},
    );

/// Cliente listo para probar, con almacén en memoria y sesión opcional.
Future<(ApiClient, AlmacenSesionEnMemoria)> clienteConSesion(
  MockClient http, {
  SesionApi? sesion,
}) async {
  final almacen = AlmacenSesionEnMemoria();
  final cliente = ApiClient(
    clienteHttp: http,
    almacen: almacen,
    urlBase: urlBaseDePrueba,
    tiempoLimite: const Duration(seconds: 5),
  );
  if (sesion != null) await cliente.guardarSesion(sesion);
  return (cliente, almacen);
}

/// Backend de mentira que se comporta **como el real** en lo que importa aquí:
/// el refresh token rota en cada uso y, si se presenta uno ya rotado, se
/// revoca **toda la familia** y el usuario queda fuera.
///
/// No es una suposición: se comprobó contra el servidor el 2026-08-27.
/// Reutilizar el refresh token anterior devolvió 401 y dejó inservible también
/// al que lo había sustituido.
///
/// Sirve para probar la serialización del refresco sin tener que tocar el
/// código de producción: si `ApiClient` dejara escapar dos refrescos con el
/// mismo token, este backend falso lo castigaría igual que el de verdad y el
/// test se pondría rojo.
class BackendFalsoConRotacion {
  BackendFalsoConRotacion({
    this.tokenInicial = 'token-0',
    this.refreshInicial = 'refresh-0',
    this.retrasoDelRefresh = const Duration(milliseconds: 40),
    this.vidaDelAccessEnSegundos = 900,
  })  : _tokenVivo = tokenInicial,
        _refreshVivo = refreshInicial;

  final String tokenInicial;
  final String refreshInicial;
  final Duration retrasoDelRefresh;
  final int vidaDelAccessEnSegundos;

  String? _tokenVivo;
  String? _refreshVivo;
  final Set<String> _refreshYaUsados = {};
  int _generacion = 0;

  /// Cuántas veces se llamó a `/api/auth/refresh`.
  int refrescos = 0;

  /// `true` si el backend detectó reutilización y revocó la familia entera.
  bool familiaRevocada = false;

  /// Retrasos artificiales por ruta, para forzar solapamientos concretos.
  final Map<String, Duration> retrasosPorRuta = {};

  Future<http.Response> responder(http.Request peticion) async {
    final ruta = peticion.url.path;

    if (ruta == RutasApiPrueba.refresh) {
      refrescos++;
      final cuerpo = jsonDecode(utf8.decode(peticion.bodyBytes)) as Map;
      final presentado = '${cuerpo['refreshToken']}';
      await Future<void>.delayed(retrasoDelRefresh);

      if (_refreshYaUsados.contains(presentado)) {
        // Reutilización: el backend real lo trata como robo.
        familiaRevocada = true;
        _tokenVivo = null;
        _refreshVivo = null;
        return respuestaError(
            401, 'Sesión inválida o expirada. Inicia sesión de nuevo.');
      }
      if (familiaRevocada || presentado != _refreshVivo) {
        return respuestaError(
            401, 'Sesión inválida o expirada. Inicia sesión de nuevo.');
      }

      _refreshYaUsados.add(presentado);
      _generacion++;
      _tokenVivo = 'token-$_generacion';
      _refreshVivo = 'refresh-$_generacion';
      return respuestaJson(
        cuerpoSesion(
          token: _tokenVivo!,
          refreshToken: _refreshVivo!,
          expiraEnSegundos: vidaDelAccessEnSegundos,
        ),
        200,
      );
    }

    final retraso = retrasosPorRuta[ruta];
    if (retraso != null) await Future<void>.delayed(retraso);

    final autorizacion = autorizacionDe(peticion);
    if (_tokenVivo == null || autorizacion != 'Bearer $_tokenVivo') {
      return respuestaError(401, 'No autenticado');
    }
    return respuestaJson({'ruta': ruta}, 200);
  }

  /// Deja el access token caducado en el servidor sin tocar el refresh, como
  /// cuando pasan los 15 minutos.
  void caducarAccessToken() => _tokenVivo = '$_tokenVivo-caducado';
}

/// Copia local de las rutas para no importar `lib/` en las ayudas.
abstract final class RutasApiPrueba {
  static const String refresh = '/api/auth/refresh';
}

/// Lee el `Authorization` de una petición registrada.
String? autorizacionDe(http.Request peticion) =>
    peticion.headers.entries
        .where((e) => e.key.toLowerCase() == 'authorization')
        .map((e) => e.value)
        .firstOrNull;
