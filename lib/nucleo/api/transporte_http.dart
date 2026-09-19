import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_excepciones.dart';
import 'configuracion_api.dart';

/// Una sola ida y vuelta HTTP contra el backend. **No sabe nada de sesion**:
/// ni la guarda, ni la renueva, ni decide si hay que reintentar.
///
/// Se encarga de:
///
/// - Construir la URL a partir de [ConfiguracionApi] (nada de URLs sueltas).
/// - Poner las cabeceras, incluida `Authorization` si le dan un token ya
///   hecho: cual es lo decide `GestorDeSesion`, no este archivo.
/// - Poner un tiempo limite y distinguir "no hay internet" de "el servidor
///   respondio mal" - Firestore lo daba hecho, HTTP no.
/// - Traducir el formato de error del backend (ADR-0008) a las excepciones de
///   `api_excepciones.dart`, con el `message` en espanol ya listo.
///
/// Salio de `api_client.dart` en la tarea 027 (parte B-1) sin cambiar una
/// linea de su cuerpo: era la mitad del archivo que no tocaba ni la sesion ni
/// los candados de la renovacion, asi que se puede leer y probar suelta.
class TransporteHttp {
  TransporteHttp({
    http.Client? cliente,
    String? urlBase,
    Duration? tiempoLimite,
  })  : _http = cliente ?? http.Client(),
        _urlBaseFija =
            urlBase == null ? null : ConfiguracionApi.normalizar(urlBase),
        _tiempoLimite = tiempoLimite ?? ConfiguracionApi.tiempoLimite;

  final http.Client _http;
  final Duration _tiempoLimite;

  /// URL fija para esta instancia. `null` = seguir a [ConfiguracionApi], que
  /// es lo normal en la app; los tests la fijan.
  final String? _urlBaseFija;

  /// `true` si esta instancia lleva URL propia. Cuando es `false`, el cliente
  /// tiene que leer al arrancar la que el usuario eligiera en el dispositivo.
  bool get urlBaseFijada => _urlBaseFija != null;

  /// URL base efectiva de este transporte.
  String get urlBase => _urlBaseFija ?? ConfiguracionApi.urlBase;

  /// Una sola ida y vuelta, sin lógica de sesión.
  Future<Object?> enviar({
    required String metodo,
    required String ruta,
    Map<String, Object?>? consulta,
    Object? cuerpo,
    required bool autenticada,
    String? token,
    bool esLogin = false,
  }) async {
    final uri = construirUri(urlBase, ruta, consulta);

    final cabeceras = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      if (cuerpo != null)
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      if (autenticada && token != null) HttpHeaders.authorizationHeader: token,
    };

    final peticion = http.Request(metodo, uri)..headers.addAll(cabeceras);
    if (cuerpo != null) {
      // `bodyBytes` con UTF-8 explícito: los textos llevan tildes y ñ.
      peticion.bodyBytes = utf8.encode(jsonEncode(cuerpo));
    }

    final http.Response respuesta;
    try {
      final flujo = await _http.send(peticion).timeout(_tiempoLimite);
      respuesta = await http.Response.fromStream(flujo).timeout(_tiempoLimite);
    } on TimeoutException catch (e) {
      throw ErrorDeRed(
        mensaje: 'El servidor tardó demasiado en responder. '
            'Revisa tu conexión e inténtalo de nuevo.',
        causa: e,
      );
    } on SocketException catch (e) {
      throw ErrorDeRed(causa: e);
    } on HandshakeException catch (e) {
      throw ErrorDeRed(causa: e);
    } on http.ClientException catch (e) {
      throw ErrorDeRed(causa: e);
    }

    return _interpretar(respuesta, esLogin: esLogin);
  }

  Object? _interpretar(http.Response respuesta, {required bool esLogin}) {
    final estado = respuesta.statusCode;

    // `respuesta.body` decide el charset por la cabecera `Content-Type`, y
    // Spring manda `application/json` **sin** `charset`. En ese caso `http`
    // cae a latin-1 y "Sesión inválida" llega como "SesiÃ³n invÃ¡lida". Se
    // decodifica a mano en UTF-8, que es lo que manda el backend de verdad.
    final texto = respuesta.bodyBytes.isEmpty
        ? ''
        : utf8.decode(respuesta.bodyBytes, allowMalformed: true);

    Object? json;
    if (texto.trim().isNotEmpty) {
      try {
        json = jsonDecode(texto);
      } on FormatException {
        // 2xx con basura es ilegible; en un error, el cuerpo no importa tanto
        // (se usará el mensaje por defecto de cada excepción).
        if (estado >= 200 && estado < 300) {
          throw RespuestaIlegible(
              estado: estado,
              detalle: 'Cuerpo que no es JSON: '
                  '${texto.substring(0, texto.length.clamp(0, 120))}');
        }
      }
    }

    if (estado >= 200 && estado < 300) return json;

    throw excepcionDesdeRespuesta(
      estado,
      json,
      reintentarDespuesDe: _cabecera(respuesta, 'retry-after'),
      enLogin: esLogin,
    );
  }

  static String? _cabecera(http.Response respuesta, String nombre) {
    // `http` normaliza los nombres de cabecera a minúsculas.
    return respuesta.headers[nombre.toLowerCase()];
  }

  /// Une URL base, ruta y parámetros. Público para poder probarlo suelto.
  ///
  /// Los valores de la consulta se pasan a texto porque `Uri` solo admite
  /// `String` (o listas de `String`); un `int` sin convertir revienta.
  static Uri construirUri(
    String urlBase,
    String ruta, [
    Map<String, Object?>? consulta,
  ]) {
    final rutaLimpia = ruta.startsWith('/') ? ruta : '/$ruta';
    final uri = Uri.parse('${ConfiguracionApi.normalizar(urlBase)}$rutaLimpia');
    if (consulta == null || consulta.isEmpty) return uri;
    final parametros = <String, String>{};
    consulta.forEach((clave, valor) {
      if (valor == null) return;
      parametros[clave] = '$valor';
    });
    if (parametros.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...parametros,
    });
  }

  /// Cierra el cliente HTTP subyacente.
  void cerrar() => _http.close();
}

/// Comprueba que lo recibido es un objeto JSON y lo devuelve tipado.
Map<String, dynamic> comoObjetoJson(Object? json) {
  if (json is Map<String, dynamic>) return json;
  if (json is Map) return Map<String, dynamic>.from(json);
  throw RespuestaIlegible(
      detalle: 'Se esperaba un objeto JSON; llegó ${json.runtimeType}');
}
