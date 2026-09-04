import '../../utils/constantes.dart';

/// Cuerpo de error estándar del backend (ADR-0008, tarea 009):
///
/// ```json
/// {"timestamp":"...","status":400,"error":"Bad Request",
///  "message":"Datos inválidos","fields":{"correo":"..."}}
/// ```
///
/// `message` **ya viene en español y listo para enseñar al usuario**; no hay
/// que traducirlo ni envolverlo. `fields` solo aparece cuando el fallo es por
/// campo, y sirve para marcar el error dentro del formulario.
class ErrorApi {
  const ErrorApi({
    required this.estado,
    required this.mensaje,
    this.error = '',
    this.campos = const {},
    this.marcaDeTiempo,
  });

  /// Código HTTP (400, 401, 409, 429...).
  final int estado;

  /// Texto listo para mostrar al usuario.
  final String mensaje;

  /// Nombre corto del error según el backend ("Bad Request", "Conflict"...).
  /// Útil para logs; no se enseña al usuario.
  final String error;

  /// Errores por campo del formulario: `{'correo': 'Ingresa un correo válido'}`.
  final Map<String, String> campos;

  final DateTime? marcaDeTiempo;

  /// Lee el cuerpo de error del backend. Tolera que no venga en el formato
  /// esperado (un proxy, un 502 en HTML, un cuerpo vacío): en ese caso deja
  /// [mensaje] vacío y quien llame pondrá uno genérico.
  factory ErrorApi.desdeJson(int estado, Object? cuerpo) {
    if (cuerpo is! Map) {
      return ErrorApi(estado: estado, mensaje: '');
    }
    final campos = <String, String>{};
    final crudos = cuerpo['fields'];
    if (crudos is Map) {
      crudos.forEach((clave, valor) {
        campos['$clave'] = '$valor';
      });
    }
    final marca = cuerpo['timestamp'];
    return ErrorApi(
      estado: estado,
      mensaje: cuerpo['message'] is String ? cuerpo['message'] as String : '',
      error: cuerpo['error'] is String ? cuerpo['error'] as String : '',
      campos: Map.unmodifiable(campos),
      marcaDeTiempo: marca is String ? DateTime.tryParse(marca) : null,
    );
  }

  @override
  String toString() => 'ErrorApi($estado, "$mensaje", campos: $campos)';
}

/// Raíz de todo lo que puede fallar al hablar con el backend.
///
/// Se atrapa esta clase para el caso general y las subclases cuando hay que
/// reaccionar distinto (reautenticar, marcar campos, reintentar más tarde).
/// [mensaje] siempre trae algo mostrable al usuario, en español.
sealed class ExcepcionApi implements Exception {
  const ExcepcionApi(this.mensaje, {this.estado, this.campos = const {}});

  /// Texto en español listo para un `SnackBar` o un cartel de error.
  final String mensaje;

  /// Código HTTP, si lo hubo. `null` cuando ni siquiera hubo respuesta
  /// (sin conexión, tiempo agotado).
  final int? estado;

  /// Errores por campo, para marcarlos en un formulario. Vacío casi siempre.
  final Map<String, String> campos;

  /// `true` si reintentar la misma petición tiene alguna posibilidad de
  /// funcionar (red caída, servidor con un fallo puntual, 429 tras esperar).
  bool get vaLaPenaReintentar => false;

  @override
  String toString() => '$runtimeType($estado): $mensaje';
}

/// No se pudo llegar al servidor: sin internet, DNS que no resuelve, servidor
/// apagado o el tiempo límite se agotó.
///
/// Con Firestore esto no existía como caso a programar (el SDK encolaba las
/// escrituras y servía lecturas de su caché). Con HTTP hay que enseñarlo.
final class ErrorDeRed extends ExcepcionApi {
  const ErrorDeRed({String? mensaje, this.causa})
      : super(mensaje ?? MensajesError.errorConexion);

  /// La excepción original (`SocketException`, `TimeoutException`...), para el log.
  final Object? causa;

  @override
  bool get vaLaPenaReintentar => true;
}

/// No hay **sesión confirmada** y se intentó una acción que crea o modifica
/// datos (ADR-0013).
///
/// Ojo a la diferencia con [ErrorDeRed]: aquí la petición **ni siquiera
/// sale**. Lo que hay que decirle al usuario no es "no se pudo enviar", sino
/// "no se ha enviado nada", que es una promesa más fuerte y la única que la
/// app puede sostener.
///
/// **Por qué existe.** Firestore encolaba las escrituras sin conexión y las
/// sincronizaba después, así que publicar sin señal "funcionaba" de una forma
/// que el usuario no veía. Contra HTTP ese encolado no existe: la petición
/// simplemente falla. La decisión del dueño (ADR-0013) es que sin conexión
/// confirmada no se ejecute ninguna acción de escritura y que se diga claro.
/// La comprobación vive en **un solo sitio**:
/// `ApiClient.exigirSesionConfirmada`.
final class SinConexionConfirmada extends ExcepcionApi {
  const SinConexionConfirmada([String? mensaje])
      : super(mensaje ?? MensajesError.sinConexionNoSeEscribe);

  /// Reintentar cuando vuelva la conexión sí sirve.
  @override
  bool get vaLaPenaReintentar => true;
}

/// 400: el servidor rechazó los datos enviados. [campos] dice qué campo falla.
final class ErrorDeValidacion extends ExcepcionApi {
  const ErrorDeValidacion(super.mensaje, {super.estado, super.campos});
}

/// 401: no hay sesión válida. La app debe volver al login.
///
/// Se emite cuando el refresh token también ha caducado, ha sido revocado o
/// se detectó su reutilización (el backend revoca la familia entera, ADR-0010).
final class SesionInvalida extends ExcepcionApi {
  const SesionInvalida([String? mensaje])
      : super(mensaje ?? 'Tu sesión expiró. Inicia sesión de nuevo.',
            estado: 401);
}

/// 401 en el login: correo o contraseña incorrectos (o cuenta suspendida — el
/// backend no distingue a propósito, ADR-0008).
final class CredencialesInvalidas extends ExcepcionApi {
  const CredencialesInvalidas([String? mensaje])
      : super(mensaje ?? MensajesError.credencialesInvalidas, estado: 401);
}

/// 403: hay sesión, pero esta cuenta no puede hacer eso. Reintentar no sirve.
final class SinPermiso extends ExcepcionApi {
  const SinPermiso([String? mensaje])
      : super(mensaje ?? 'No tienes permiso para hacer esto.', estado: 403);
}

/// 404: el recurso no existe (o ya no existe).
final class NoEncontrado extends ExcepcionApi {
  const NoEncontrado([String? mensaje])
      : super(mensaje ?? 'No encontramos lo que buscabas.', estado: 404);
}

/// 409: la operación choca con el estado actual (cancelar un trabajo ya
/// entregado, correo duplicado...). El `message` del backend explica cuál.
final class ConflictoDeEstado extends ExcepcionApi {
  const ConflictoDeEstado(super.mensaje) : super(estado: 409);
}

/// 429: demasiados intentos. El backend manda `Retry-After` en segundos.
///
/// Ocurre sobre todo en el login (freno de fuerza bruta por IP y por cuenta,
/// ADR-0010). Hay que enseñar cuánto falta, no un error genérico.
final class DemasiadosIntentos extends ExcepcionApi {
  const DemasiadosIntentos(super.mensaje, {this.reintentarEn})
      : super(estado: 429);

  /// Lo que dice la cabecera `Retry-After`. `null` si no vino.
  final Duration? reintentarEn;

  @override
  bool get vaLaPenaReintentar => true;

  /// "15 minutos" / "45 segundos", para completar el mensaje en la UI.
  String? get esperaLegible {
    final espera = reintentarEn;
    if (espera == null) return null;
    if (espera.inMinutes >= 1) {
      final m = espera.inMinutes;
      return m == 1 ? '1 minuto' : '$m minutos';
    }
    final s = espera.inSeconds < 1 ? 1 : espera.inSeconds;
    return s == 1 ? '1 segundo' : '$s segundos';
  }
}

/// 5xx: el fallo es del servidor. El backend nunca manda el detalle en el
/// cuerpo (va a su log), así que aquí el mensaje es genérico a propósito.
final class ErrorDelServidor extends ExcepcionApi {
  const ErrorDelServidor({int? estado, String? mensaje})
      : super(mensaje ?? MensajesError.errorGeneral, estado: estado ?? 500);

  @override
  bool get vaLaPenaReintentar => true;
}

/// El servidor respondió, pero con algo que no se puede interpretar: JSON
/// malformado, o un objeto donde se esperaba una lista.
///
/// Casi siempre significa que la app apunta a algo que no es el backend (un
/// portal cautivo de WiFi, un proxy, la URL base mal puesta).
final class RespuestaIlegible extends ExcepcionApi {
  const RespuestaIlegible({super.estado, this.detalle})
      : super('Recibimos una respuesta que no entendimos. '
            'Revisa tu conexión e inténtalo de nuevo.');

  /// Qué se esperaba y qué llegó. Para el log, no para el usuario.
  final String? detalle;

  @override
  String toString() => 'RespuestaIlegible($estado): $mensaje [$detalle]';
}

/// Cualquier otro código HTTP no contemplado arriba (405, 415, 413...).
final class ErrorHttp extends ExcepcionApi {
  const ErrorHttp(super.mensaje, {super.estado, super.campos});
}

/// Traduce una respuesta de error del backend a la excepción que le toca.
///
/// [enLogin] cambia el significado del 401: en `/api/auth/login` es
/// "credenciales incorrectas" (el usuario debe corregir lo que escribió), y en
/// cualquier otra ruta es "la sesión ya no vale" (hay que reautenticar).
ExcepcionApi excepcionDesdeRespuesta(
  int estado,
  Object? cuerpo, {
  String? reintentarDespuesDe,
  bool enLogin = false,
}) {
  final error = ErrorApi.desdeJson(estado, cuerpo);
  final mensaje = error.mensaje;

  switch (estado) {
    case 400:
      return ErrorDeValidacion(
        mensaje.isEmpty ? 'Revisa los datos e inténtalo de nuevo.' : mensaje,
        estado: estado,
        campos: error.campos,
      );
    case 401:
      if (enLogin) {
        return CredencialesInvalidas(mensaje.isEmpty ? null : mensaje);
      }
      return SesionInvalida(mensaje.isEmpty ? null : mensaje);
    case 403:
      return SinPermiso(mensaje.isEmpty ? null : mensaje);
    case 404:
      return NoEncontrado(mensaje.isEmpty ? null : mensaje);
    case 409:
      return ConflictoDeEstado(
          mensaje.isEmpty ? 'Esa acción ya no es posible.' : mensaje);
    case 429:
      return DemasiadosIntentos(
        mensaje.isEmpty
            ? 'Demasiados intentos. Espera un momento e inténtalo de nuevo.'
            : mensaje,
        reintentarEn: leerRetryAfter(reintentarDespuesDe),
      );
  }

  if (estado >= 500) {
    return ErrorDelServidor(
        estado: estado, mensaje: mensaje.isEmpty ? null : mensaje);
  }
  return ErrorHttp(
    mensaje.isEmpty ? MensajesError.errorGeneral : mensaje,
    estado: estado,
    campos: error.campos,
  );
}

/// `Retry-After` puede venir en segundos (lo que manda este backend: se
/// verificó `Retry-After: 900`) o como fecha HTTP. Se soportan los dos; si no
/// se entiende, se devuelve `null`.
Duration? leerRetryAfter(String? cabecera) {
  if (cabecera == null || cabecera.trim().isEmpty) return null;
  final valor = cabecera.trim();
  final segundos = int.tryParse(valor);
  if (segundos != null) return Duration(seconds: segundos < 0 ? 0 : segundos);
  final fecha = DateTime.tryParse(valor);
  if (fecha == null) return null;
  final falta = fecha.difference(DateTime.now());
  return falta.isNegative ? Duration.zero : falta;
}
