import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'almacen_sesion.dart';
import 'api_excepciones.dart';
import 'configuracion_api.dart';
import 'pagina_api.dart';
import 'sesion_api.dart';

/// Cliente HTTP único contra el backend Spring Boot (`/api/**`).
///
/// Toda la app habla con el servidor a través de esta clase. Se encarga de:
///
/// - Construir la URL a partir de [ConfiguracionApi] (nada de URLs sueltas).
/// - Poner `Authorization: Bearer <token>` en cada petición autenticada.
/// - Traducir el formato de error del backend (ADR-0008) a las excepciones de
///   `api_excepciones.dart`, con el `message` en español ya listo.
/// - Poner un tiempo límite y distinguir "no hay internet" de "el servidor
///   respondió mal" — Firestore lo daba hecho, HTTP no.
/// - **Renovar el token de acceso sin que se pisen dos renovaciones**, que es
///   lo más delicado de todo esto (ver "Renovación" abajo).
///
/// ## Renovación del token: por qué hay una sola en vuelo
///
/// El token de acceso dura 15 min y el refresh token **rota en cada uso**
/// (ADR-0010). Si dos peticiones caducan a la vez y ambas llaman a
/// `/api/auth/refresh` con el mismo refresh token, la segunda presenta uno ya
/// rotado; el backend lo interpreta como robo y **revoca la familia entera**,
/// dejando al usuario fuera. Verificado contra el servidor real el 2026-08-27:
/// reusar el refresh token anterior invalida también al que lo sustituyó.
///
/// Por eso hay tres candados, y hacen falta los tres:
///
/// 1. **Una sola renovación en vuelo** ([_refrescoEnVuelo]): la primera
///    petición que necesita renovar lanza la llamada; las que lleguen después
///    se cuelgan de ese mismo `Future` en vez de lanzar la suya.
/// 2. **Comparación del refresh token visto** : una petición que se quedó
///    esperando puede despertar cuando la renovación ya terminó. Si mandara el
///    refresh token que ella conocía (el viejo), provocaría exactamente la
///    revocación de familia. Por eso, antes de renovar, se compara el refresh
///    token que traía con el que hay guardado ahora: si no coinciden, alguien
///    ya renovó y se reutiliza su resultado sin tocar la red.
///
/// 3. **La sesión sigue siendo la misma al terminar** (`_esLaSesionActual`):
///    entre que sale el refresco y vuelve, el usuario puede haber cerrado
///    sesión o haber entrado con otra cuenta. Guardar entonces el par recién
///    emitido resucitaría una sesión cerrada —el `logout` del backend revoca
///    solo el token que se le presenta, no la familia— o pisaría la sesión
///    nueva con los datos del usuario anterior. Añadido en la tarea 022 tras
///    reproducirlo.
///
/// El candado 1 sin el 2 no basta: cubre el caso simultáneo, no el de
/// "llegué tarde con el token viejo". Y ninguno de los dos cubre el 3, que no
/// va de dos refrescos pisándose sino de un refresco que sobrevive a la
/// sesión que lo pidió.
class ApiClient {
  ApiClient({
    http.Client? clienteHttp,
    AlmacenSesion? almacen,
    String? urlBase,
    Duration? tiempoLimite,
  })  : _http = clienteHttp ?? http.Client(),
        _almacen = almacen ?? AlmacenSesionSeguro(),
        _urlBase = urlBase == null ? null : ConfiguracionApi.normalizar(urlBase),
        _tiempoLimite = tiempoLimite ?? ConfiguracionApi.tiempoLimite;

  final http.Client _http;
  final AlmacenSesion _almacen;
  final Duration _tiempoLimite;

  /// URL fija para esta instancia. `null` = seguir a [ConfiguracionApi], que
  /// es lo normal en la app; los tests la fijan.
  final String? _urlBase;

  SesionApi? _sesion;
  Future<SesionApi>? _refrescoEnVuelo;
  final StreamController<EventoSesion> _eventos =
      StreamController<EventoSesion>.broadcast();

  // ── Instancia compartida ────────────────────────────────────
  // La app no usa un contenedor de inyección de dependencias; los servicios se
  // instancian directos (ver lib/services/*_service.dart). Se sigue ese estilo
  // en vez de meter get_it/provider solo para esto.
  static ApiClient? _instancia;

  /// Cliente que usará toda la app. La fase 2 lo inyectará en los servicios.
  static ApiClient get instancia => _instancia ??= ApiClient();

  /// Reemplaza la instancia compartida (tests, o un arranque con configuración
  /// distinta). Pasar `null` la borra para que se vuelva a crear.
  static void fijarInstancia(ApiClient? cliente) => _instancia = cliente;

  // ── Estado de la sesión ─────────────────────────────────────

  /// Sesión actual, o `null` si nadie ha iniciado sesión.
  SesionApi? get sesion => _sesion;

  bool get haySesion => _sesion != null;

  /// El `usuario` que vino con la sesión, en crudo. `Usuario.desdeJson` lo
  /// convierte al modelo de la app.
  Map<String, dynamic> get usuarioDeLaSesion => _sesion?.usuario ?? const {};

  /// Avisos de inicio / renovación / fin de sesión, para que la app pueda
  /// volver al login cuando la sesión muere sola.
  Stream<EventoSesion> get eventosSesion => _eventos.stream;

  /// URL base efectiva de este cliente.
  String get urlBase => _urlBase ?? ConfiguracionApi.urlBase;

  /// Carga lo persistido en el dispositivo: primero la URL elegida a mano (si
  /// la hay) y después la sesión. Llamar una vez al arrancar la app, antes de
  /// decidir si se muestra el login.
  Future<void> iniciar() async {
    if (_urlBase == null) {
      ConfiguracionApi.fijarUrlBase(await _almacen.leerUrlBase());
    }
    _sesion = await _almacen.leerSesion();
  }

  /// Guarda la sesión que devolvió el login o el registro. Lo llamará
  /// `auth_service` cuando se migre (fase 2).
  Future<void> guardarSesion(SesionApi sesion) =>
      _guardarSesion(sesion, EventoSesion.iniciada);

  /// Cierra sesión de verdad: revoca el refresh token en el servidor y borra
  /// lo guardado en el dispositivo.
  ///
  /// Si el servidor no responde, **igualmente se borra en local**: el usuario
  /// pidió salir y debe salir. El refresh token quedaría vivo en el servidor
  /// hasta caducar; es el mal menor frente a dejarlo dentro de la app.
  Future<void> cerrarSesion() async {
    final actual = _sesion;
    if (actual != null) {
      try {
        await _enviar(
          metodo: 'POST',
          ruta: RutasApi.logout,
          cuerpo: {'refreshToken': actual.refreshToken},
          autenticada: false,
        );
      } on ExcepcionApi {
        // Da igual por qué falló: la sesión local se va de todas formas.
      }
    }
    await _terminarSesion();
  }

  /// Cambia el servidor al que apunta la app y lo recuerda en el dispositivo.
  /// Cierra la sesión actual: los tokens de un servidor no valen en otro.
  Future<void> cambiarUrlBase(String? url) async {
    await _almacen.guardarUrlBase(url);
    ConfiguracionApi.fijarUrlBase(url);
    await _terminarSesion();
  }

  /// Cierra el cliente HTTP y el stream de eventos.
  void cerrar() {
    _http.close();
    _eventos.close();
  }

  // ── Verbos ──────────────────────────────────────────────────

  Future<Object?> obtener(
    String ruta, {
    Map<String, Object?>? consulta,
    bool autenticada = true,
  }) =>
      _peticionConReintento(
          metodo: 'GET',
          ruta: ruta,
          consulta: consulta,
          autenticada: autenticada);

  Future<Object?> crear(
    String ruta, {
    Object? cuerpo,
    Map<String, Object?>? consulta,
    bool autenticada = true,
    bool esLogin = false,
  }) =>
      _peticionConReintento(
        metodo: 'POST',
        ruta: ruta,
        cuerpo: cuerpo,
        consulta: consulta,
        autenticada: autenticada,
        esLogin: esLogin,
      );

  Future<Object?> reemplazar(
    String ruta, {
    Object? cuerpo,
    bool autenticada = true,
  }) =>
      _peticionConReintento(
          metodo: 'PUT', ruta: ruta, cuerpo: cuerpo, autenticada: autenticada);

  Future<Object?> modificar(
    String ruta, {
    Object? cuerpo,
    bool autenticada = true,
  }) =>
      _peticionConReintento(
          metodo: 'PATCH', ruta: ruta, cuerpo: cuerpo, autenticada: autenticada);

  Future<Object?> eliminar(
    String ruta, {
    Object? cuerpo,
    bool autenticada = true,
  }) =>
      _peticionConReintento(
          metodo: 'DELETE',
          ruta: ruta,
          cuerpo: cuerpo,
          autenticada: autenticada);

  // ── Ayudas tipadas ──────────────────────────────────────────

  /// GET que devuelve un objeto JSON. Lanza [RespuestaIlegible] si llega otra
  /// cosa (una lista, `null`, HTML de un portal cautivo...).
  Future<Map<String, dynamic>> obtenerObjeto(
    String ruta, {
    Map<String, Object?>? consulta,
    bool autenticada = true,
  }) async =>
      comoObjeto(await obtener(ruta, consulta: consulta, autenticada: autenticada));

  /// GET que devuelve una página de Spring o un array pelado, ya convertido a
  /// modelos con [mapear].
  Future<PaginaApi<T>> obtenerPagina<T>(
    String ruta,
    T Function(Map<String, dynamic> elemento) mapear, {
    int? pagina,
    int? tamano,
    Map<String, Object?>? consulta,
    bool autenticada = true,
  }) async {
    final parametros = <String, Object?>{
      if (pagina case final int p) 'page': p,
      if (tamano case final int t) 'size': t,
      ...?consulta,
    };
    final json = await obtener(
      ruta,
      consulta: parametros.isEmpty ? null : parametros,
      autenticada: autenticada,
    );
    return PaginaApi.desdeJson<T>(json, mapear);
  }

  /// Comprueba que lo recibido es un objeto JSON y lo devuelve tipado.
  static Map<String, dynamic> comoObjeto(Object? json) {
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return Map<String, dynamic>.from(json);
    throw RespuestaIlegible(
        detalle: 'Se esperaba un objeto JSON; llegó ${json.runtimeType}');
  }

  // ── Sesión (interno) ────────────────────────────────────────

  Future<void> _guardarSesion(SesionApi sesion, EventoSesion evento) async {
    _sesion = sesion;
    await _almacen.guardarSesion(sesion);
    _emitir(evento);
  }

  Future<void> _terminarSesion() async {
    final habia = _sesion != null;
    _sesion = null;
    _refrescoEnVuelo = null;
    await _almacen.borrarSesion();
    if (habia) _emitir(EventoSesion.terminada);
  }

  void _emitir(EventoSesion evento) {
    if (!_eventos.isClosed) _eventos.add(evento);
  }

  /// Punto único de renovación. Ver la explicación de los dos candados en la
  /// documentación de la clase.
  ///
  /// [refreshVisto] es el refresh token que tenía la petición que pide
  /// renovar. Sirve para detectar que alguien ya renovó por nosotros.
  Future<SesionApi> _renovar(String refreshVisto) {
    final actual = _sesion;
    if (actual == null) {
      return Future<SesionApi>.error(const SesionInvalida());
    }

    // Candado 2: alguien renovó mientras esperábamos. Mandar el refresh viejo
    // aquí sería justo lo que el backend considera reutilización y castiga
    // revocando la familia entera. Nos quedamos con la sesión ya renovada.
    if (actual.refreshToken != refreshVisto) {
      return Future<SesionApi>.value(actual);
    }

    // Candado 1: ya hay una renovación en marcha; esperamos a esa.
    final enVuelo = _refrescoEnVuelo;
    if (enVuelo != null) return enVuelo;

    // Nos toca lanzarla. Entre la comprobación de arriba y esta asignación no
    // hay ningún `await`, así que ninguna otra petición puede colarse en medio
    // (un isolate de Dart ejecuta un solo hilo de microtareas).
    final futuro = _ejecutarRenovacion(actual);
    _refrescoEnVuelo = futuro;
    futuro.whenComplete(() {
      // Solo lo limpia si sigue siendo el nuestro, no vaya a borrar una
      // renovación posterior.
      if (identical(_refrescoEnVuelo, futuro)) _refrescoEnVuelo = null;
    }).ignore();
    return futuro;
  }

  Future<SesionApi> _ejecutarRenovacion(SesionApi caducada) async {
    final Object? json;
    try {
      json = await _enviar(
        metodo: 'POST',
        ruta: RutasApi.refresh,
        cuerpo: {'refreshToken': caducada.refreshToken},
        autenticada: false,
      );
    } on SesionInvalida {
      // El backend dijo 401: el refresh caducó, se revocó o se detectó
      // reutilización. No hay nada que salvar... salvo que entre medias haya
      // empezado OTRA sesión (el usuario cerró la suya y volvió a entrar):
      // esa no tiene la culpa de que un refresco viejo llegara tarde.
      if (_esLaSesionActual(caducada)) await _terminarSesion();
      rethrow;
    }
    // Ojo: un fallo de red NO se traga la sesión. El refresh token sigue
    // siendo válido y el usuario podrá seguir cuando vuelva la conexión.

    final SesionApi nueva;
    try {
      nueva = caducada.conTokensDe(SesionApi.desdeJson(comoObjeto(json)));
    } on FormatException catch (e) {
      throw RespuestaIlegible(detalle: 'Refresh sin tokens: ${e.message}');
    }

    // Candado 3: la sesión que se estaba renovando puede haber dejado de ser
    // la de la app mientras la petición viajaba. Dos casos reales:
    //
    // - El usuario pulsó "cerrar sesión". `POST /api/auth/logout` revoca
    //   **solo el refresh token que se le presenta**, no la familia entera
    //   (ver `RefreshTokenService.revocar` en el backend), así que el par que
    //   acaba de emitir este refresco sigue vivo en el servidor. Guardarlo
    //   dejaría en el dispositivo una sesión utilizable DESPUÉS de haber
    //   salido, y al siguiente arranque la app entraría sola.
    //   Reproducido el 2026-08-29 (tarea 022).
    // - Se inició otra sesión (login o registro). Guardar aquí la pisaría con
    //   los tokens y el perfil del usuario anterior.
    //
    // En ambos casos lo correcto es tirar los tokens nuevos y responder que
    // no hay sesión: quien esperaba esta renovación ya no debe continuar.
    if (!_esLaSesionActual(caducada)) throw const SesionInvalida();

    await _guardarSesion(nueva, EventoSesion.renovada);
    return nueva;
  }

  /// ¿La sesión que se estaba renovando sigue siendo la de la app?
  ///
  /// Se compara el refresh token en vez de la identidad del objeto porque la
  /// sesión se reconstruye al leerla del almacén; el refresh token es único
  /// por rotación, así que hace de huella.
  bool _esLaSesionActual(SesionApi sesion) {
    final actual = _sesion;
    return actual != null && actual.refreshToken == sesion.refreshToken;
  }

  // ── Peticiones (interno) ────────────────────────────────────

  /// Envía la petición y, si el token había muerto, renueva **una vez** y
  /// reintenta. Nunca hay un segundo reintento: si el token nuevo también da
  /// 401, el problema no es el token.
  Future<Object?> _peticionConReintento({
    required String metodo,
    required String ruta,
    Map<String, Object?>? consulta,
    Object? cuerpo,
    bool autenticada = true,
    bool esLogin = false,
  }) async {
    if (!autenticada) {
      return _enviar(
        metodo: metodo,
        ruta: ruta,
        consulta: consulta,
        cuerpo: cuerpo,
        autenticada: false,
        esLogin: esLogin,
      );
    }

    var actual = _sesion;
    if (actual == null) throw const SesionInvalida();

    // Renovación por adelantado: si el token ya caducó (con margen), no tiene
    // sentido gastar una petición para que el servidor devuelva un 401 seguro.
    if (actual.caducado(margen: ConfiguracionApi.margenRenovacion)) {
      actual = await _renovar(actual.refreshToken);
    }

    // El refresh token con el que salimos: si al volver hay que renovar, este
    // es el "visto" que permite detectar que otro ya renovó.
    final refreshVisto = actual.refreshToken;

    try {
      return await _enviar(
        metodo: metodo,
        ruta: ruta,
        consulta: consulta,
        cuerpo: cuerpo,
        autenticada: true,
        token: actual.cabeceraAutorizacion,
      );
    } on SesionInvalida {
      // El token murió antes de lo que decía `expiraEnSegundos` (reloj del
      // dispositivo desfasado, o el servidor lo invalidó). Renovamos y damos
      // exactamente una segunda oportunidad.
      final renovada = await _renovar(refreshVisto);
      return _enviar(
        metodo: metodo,
        ruta: ruta,
        consulta: consulta,
        cuerpo: cuerpo,
        autenticada: true,
        token: renovada.cabeceraAutorizacion,
      );
    }
  }

  /// Una sola ida y vuelta, sin lógica de sesión.
  Future<Object?> _enviar({
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
}
