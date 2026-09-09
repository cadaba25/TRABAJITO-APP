import 'package:http/http.dart' as http;

import 'almacen_sesion.dart';
import 'configuracion_api.dart';
import 'gestor_sesion.dart';
import 'guardia_escrituras.dart';
import 'pagina_api.dart';
import 'sesion_api.dart';
import 'transporte_http.dart';

// `ConfirmadorDeSesion` es el tipo del parámetro de `exigirSesionConfirmada`.
// Se reexporta para que quien importe este archivo lo siga viendo igual que
// antes de partirlo (tarea 027, parte B-1).
export 'guardia_escrituras.dart' show ConfirmadorDeSesion;

/// Cliente HTTP único contra el backend Spring Boot (`/api/**`).
///
/// Toda la app habla con el servidor a través de esta clase. **Es una
/// fachada**: los verbos, las ayudas tipadas y el ciclo de vida de la sesión
/// están aquí; el trabajo lo hacen tres colaboradores, cada uno en su archivo
/// (tarea 027, parte B-1):
///
/// - `transporte_http.dart` — una ida y vuelta: URL, cabeceras, tiempo límite
///   y traducción de los errores de ADR-0008.
/// - `gestor_sesion.dart` — la sesión viva, su almacén, **los tres candados
///   de la renovación** y la petición autenticada con su reintento.
/// - `guardia_escrituras.dart` — ADR-0013: sin conexión confirmada no se
///   escribe.
///
/// **Si vienes buscando la renovación del token, está en
/// `gestor_sesion.dart`**, entera y con su documentación. No se repartió
/// entre archivos a propósito: el `refreshVisto` que captura la petición y el
/// `_renovar` que lo compara son el mismo mecanismo (candado 2).
///
/// ## Sin conexión confirmada no se escribe (ADR-0013)
///
/// Ver [exigirSesionConfirmada]. Es una comprobación aparte de la renovación,
/// con su propio estado, y se hace antes que ella.
class ApiClient {
  factory ApiClient({
    http.Client? clienteHttp,
    AlmacenSesion? almacen,
    String? urlBase,
    Duration? tiempoLimite,
  }) {
    final almacenReal = almacen ?? AlmacenSesionSeguro();
    final transporte = TransporteHttp(
      cliente: clienteHttp,
      urlBase: urlBase,
      tiempoLimite: tiempoLimite,
    );
    final guardia = GuardiaEscrituras();
    return ApiClient._(
      almacen: almacenReal,
      transporte: transporte,
      guardia: guardia,
      gestor: GestorDeSesion(
        almacen: almacenReal,
        transporte: transporte,
        guardia: guardia,
      ),
    );
  }

  ApiClient._({
    required AlmacenSesion almacen,
    required TransporteHttp transporte,
    required GuardiaEscrituras guardia,
    required GestorDeSesion gestor,
  })  : _almacen = almacen,
        _transporte = transporte,
        _guardia = guardia,
        _gestor = gestor;

  /// El mismo objeto que usa [_gestor]. Aquí solo se toca para la **URL
  /// base**: `AlmacenSesion` guarda dos cosas sin relación —la sesión y la
  /// URL— y la URL no es asunto del gestor de sesión.
  final AlmacenSesion _almacen;
  final TransporteHttp _transporte;
  final GuardiaEscrituras _guardia;
  final GestorDeSesion _gestor;

  // ── Instancia compartida ────────────────────────────────────
  // Desde la tarea 027 la app SÍ tiene inyección de dependencias (`provider`,
  // ADR-0014), pero el cliente HTTP se queda con este mecanismo a propósito y
  // NO se registra también como proveedor: unos 60 tests de la capa HTTP lo
  // sustituyen con `fijarInstancia`, y tener dos formas de reemplazar lo mismo
  // es peor que tener una. Lo que se inyecta con `provider` son los servicios;
  // ellos ya reciben este cliente por su constructor.
  static ApiClient? _instancia;

  /// Cliente que usará toda la app. La fase 2 lo inyectará en los servicios.
  static ApiClient get instancia => _instancia ??= ApiClient();

  /// Reemplaza la instancia compartida (tests, o un arranque con configuración
  /// distinta). Pasar `null` la borra para que se vuelva a crear.
  static void fijarInstancia(ApiClient? cliente) => _instancia = cliente;

  // ── Estado de la sesión ─────────────────────────────

  /// Sesión actual, o `null` si nadie ha iniciado sesión.
  SesionApi? get sesion => _gestor.sesion;

  bool get haySesion => _gestor.haySesion;

  /// El `usuario` que vino con la sesión, en crudo. `Usuario.desdeJson` lo
  /// convierte al modelo de la app.
  Map<String, dynamic> get usuarioDeLaSesion => _gestor.usuarioDeLaSesion;

  /// Avisos de inicio / renovación / fin de sesión, para que la app pueda
  /// volver al login cuando la sesión muere sola.
  Stream<EventoSesion> get eventosSesion => _gestor.eventosSesion;

  /// URL base efectiva de este cliente.
  String get urlBase => _transporte.urlBase;

  /// Carga lo persistido en el dispositivo: primero la URL elegida a mano (si
  /// la hay) y después la sesión. Llamar una vez al arrancar la app, antes de
  /// decidir si se muestra el login.
  Future<void> iniciar() async {
    if (!_transporte.urlBaseFijada) {
      ConfiguracionApi.fijarUrlBase(await _almacen.leerUrlBase());
    }
    await _gestor.cargar();
  }

  /// Guarda la sesión que devolvió el login o el registro.
  Future<void> guardarSesion(SesionApi sesion) => _gestor.guardarSesion(sesion);

  /// Cierra sesión de verdad: revoca el refresh token en el servidor y borra
  /// lo guardado en el dispositivo. Ver [GestorDeSesion.cerrarSesion].
  Future<void> cerrarSesion() => _gestor.cerrarSesion();

  /// Cambia el servidor al que apunta la app y lo recuerda en el dispositivo.
  /// Cierra la sesión actual: los tokens de un servidor no valen en otro.
  Future<void> cambiarUrlBase(String? url) async {
    await _almacen.guardarUrlBase(url);
    ConfiguracionApi.fijarUrlBase(url);
    await _gestor.terminar();
  }

  /// Cierra el cliente HTTP y el stream de eventos.
  void cerrar() {
    _transporte.cerrar();
    _gestor.cerrarEventos();
  }

  // ── ADR-0013: sin conexión confirmada no se escribe ─────────

  /// Instala la comprobación de ADR-0013 en **este único sitio**. Qué se
  /// bloquea y qué no, con el porqué, en [GuardiaEscrituras.instalar].
  ///
  /// Pasar `null` la desinstala (los tests que no la ejercitan).
  void exigirSesionConfirmada(ConfirmadorDeSesion? confirmador) =>
      _guardia.instalar(confirmador);

  // ── Verbos ──────────────────────────────────────────

  Future<Object?> obtener(
    String ruta, {
    Map<String, Object?>? consulta,
    bool autenticada = true,
  }) =>
      _gestor.peticionConReintento(
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
      _gestor.peticionConReintento(
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
      _gestor.peticionConReintento(
          metodo: 'PUT', ruta: ruta, cuerpo: cuerpo, autenticada: autenticada);

  Future<Object?> modificar(
    String ruta, {
    Object? cuerpo,
    bool autenticada = true,
  }) =>
      _gestor.peticionConReintento(
          metodo: 'PATCH', ruta: ruta, cuerpo: cuerpo, autenticada: autenticada);

  Future<Object?> eliminar(
    String ruta, {
    Object? cuerpo,
    bool autenticada = true,
  }) =>
      _gestor.peticionConReintento(
          metodo: 'DELETE',
          ruta: ruta,
          cuerpo: cuerpo,
          autenticada: autenticada);

  // ── Ayudas tipadas ──────────────────────────────

  /// GET que devuelve un objeto JSON. Lanza [RespuestaIlegible] si llega otra
  /// cosa (una lista, `null`, HTML de un portal cautivo...).
  Future<Map<String, dynamic>> obtenerObjeto(
    String ruta, {
    Map<String, Object?>? consulta,
    bool autenticada = true,
  }) async =>
      comoObjeto(await obtener(ruta, consulta: consulta, autenticada: autenticada));


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
  /// Comprueba que lo recibido es un objeto JSON y lo devuelve tipado. El
  /// cuerpo vive en `transporte_http.dart`; este reenvío se queda porque
  /// `ApiClient.comoObjeto` se usa en tres sitios de la app.
  static Map<String, dynamic> comoObjeto(Object? json) => comoObjetoJson(json);

  /// Une URL base, ruta y parámetros. Público para poder probarlo suelto. El
  /// cuerpo vive en `transporte_http.dart`; este reenvío se queda porque
  /// `ApiClient.construirUri` lo usan los tests.
  static Uri construirUri(
    String urlBase,
    String ruta, [
    Map<String, Object?>? consulta,
  ]) =>
      TransporteHttp.construirUri(urlBase, ruta, consulta);
}
