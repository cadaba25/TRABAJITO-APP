import 'dart:async';

import 'almacen_sesion.dart';
import 'api_excepciones.dart';
import 'configuracion_api.dart';
import 'guardia_escrituras.dart';
import 'sesion_api.dart';
import 'transporte_http.dart';

/// La sesion viva del cliente: que tokens hay, donde se guardan, como se
/// renuevan y como sale una peticion autenticada.
///
/// **Este es el archivo delicado del cliente HTTP.** Aqui estan los tres
/// candados de la renovacion de token y el fallo real que arreglo la tarea
/// 022 (una renovacion en vuelo revivia una sesion cerrada). Salio de
/// `api_client.dart` en la tarea 027 (parte B-1) **con su cuerpo intacto**:
/// se movio entero, con su documentacion, porque separar el `refreshVisto`
/// que captura la peticion del `_renovar` que lo compara (candado 2) haria
/// invisible el mecanismo.
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
///    emitido dejaría en el dispositivo una sesión que el usuario ya cerró, o
///    pisaría la sesión nueva con los datos del usuario anterior. Añadido en
///    la tarea 022 tras reproducirlo. **Sigue haciendo falta** aunque desde la
///    tarea 024 el `logout` del backend revoque la familia entera (ADR-0012):
///    el servidor rechazará esos tokens, pero sin este candado la app
///    arrancaría creyendo que tiene sesión y solo se enteraría al primer 401 —
///    y el caso de "aquí ya hay otra sesión" el servidor ni siquiera puede
///    verlo.
///
/// El candado 1 sin el 2 no basta: cubre el caso simultáneo, no el de
/// "llegué tarde con el token viejo". Y ninguno de los dos cubre el 3, que no
/// va de dos refrescos pisándose sino de un refresco que sobrevive a la
/// sesión que lo pidió.
class GestorDeSesion {
  GestorDeSesion({
    required AlmacenSesion almacen,
    required TransporteHttp transporte,
    required GuardiaEscrituras guardia,
  })  : _almacen = almacen,
        _transporte = transporte,
        _guardia = guardia;

  final AlmacenSesion _almacen;
  final TransporteHttp _transporte;

  /// ADR-0013. Se consulta antes de cada escritura; ver [GuardiaEscrituras].
  final GuardiaEscrituras _guardia;

  SesionApi? _sesion;
  Future<SesionApi>? _refrescoEnVuelo;
  final StreamController<EventoSesion> _eventos =
      StreamController<EventoSesion>.broadcast();

  // ── Estado de la sesión ─────────────────────────────

  /// Sesión actual, o `null` si nadie ha iniciado sesión.
  SesionApi? get sesion => _sesion;

  bool get haySesion => _sesion != null;

  /// El `usuario` que vino con la sesión, en crudo. `Usuario.desdeJson` lo
  /// convierte al modelo de la app.
  Map<String, dynamic> get usuarioDeLaSesion => _sesion?.usuario ?? const {};

  /// Avisos de inicio / renovación / fin de sesión, para que la app pueda
  /// volver al login cuando la sesión muere sola.
  Stream<EventoSesion> get eventosSesion => _eventos.stream;

  /// Carga la sesión persistida en el dispositivo. Llamar una vez al arrancar
  /// la app, antes de decidir si se muestra el login.
  Future<void> cargar() async {
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
        await _transporte.enviar(
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

  /// Borra la sesión en local **sin avisar al servidor**. Lo usa el cambio de
  /// URL base: los tokens de un servidor no valen en otro.
  Future<void> terminar() => _terminarSesion();

  /// Cierra el stream de eventos.
  void cerrarEventos() => _eventos.close();

  // ── Peticiones autenticadas ─────────────────────────

  /// Envía la petición y, si el token había muerto, renueva **una vez** y
  /// reintenta. Nunca hay un segundo reintento: si el token nuevo también da
  /// 401, el problema no es el token.
  Future<Object?> peticionConReintento({
    required String metodo,
    required String ruta,
    Map<String, Object?>? consulta,
    Object? cuerpo,
    bool autenticada = true,
    bool esLogin = false,
  }) async {
    if (!autenticada) {
      return _transporte.enviar(
        metodo: metodo,
        ruta: ruta,
        consulta: consulta,
        cuerpo: cuerpo,
        autenticada: false,
        esLogin: esLogin,
      );
    }

    // ADR-0013. Va antes que todo lo demás: si no se puede escribir, no tiene
    // sentido gastar una renovación de token para acabar fallando igual.
    if (metodo != 'GET') await _guardia.exigir();

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
      return await _transporte.enviar(
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
      return _transporte.enviar(
        metodo: metodo,
        ruta: ruta,
        consulta: consulta,
        cuerpo: cuerpo,
        autenticada: true,
        token: renovada.cabeceraAutorizacion,
      );
    }
  }

  // ── Sesión (interno) ────────────────────────────────

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
      json = await _transporte.enviar(
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
      nueva = caducada.conTokensDe(SesionApi.desdeJson(comoObjetoJson(json)));
    } on FormatException catch (e) {
      throw RespuestaIlegible(detalle: 'Refresh sin tokens: ${e.message}');
    }

    // Candado 3: la sesión que se estaba renovando puede haber dejado de ser
    // la de la app mientras la petición viajaba. Dos casos reales:
    //
    // - El usuario pulsó "cerrar sesión". Guardar aquí el par recién emitido
    //   dejaría en el dispositivo tokens de una sesión que el usuario ya
    //   cerró. Cuando se reprodujo (2026-08-29, tarea 022) era peor: el
    //   `logout` del backend revocaba **solo el token presentado**, así que
    //   ese par seguía VIVO en el servidor y al siguiente arranque la app
    //   entraba sola. Desde la tarea 024 (ADR-0012) el `logout` revoca la
    //   familia entera y el servidor ya los rechaza, pero este candado se
    //   queda: sin él la app arrancaría creyendo que tiene sesión y solo se
    //   enteraría al primer 401.
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
}
