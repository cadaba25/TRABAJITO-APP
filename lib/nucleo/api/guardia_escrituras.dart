import 'dart:async';

import 'api_excepciones.dart';

/// ADR-0013: **sin conexion confirmada no se ejecuta ninguna accion que cree
/// o modifique datos**.
///
/// Vive en una clase propia, con su propio estado, y `ApiClient` la consulta
/// antes de cada peticion autenticada que no sea `GET`. Es un mecanismo
/// aparte de la renovacion de token (`GestorDeSesion`): no comparten estado
/// ni se pisan, y esta corre primero.
///
/// El motivo de que exista es la frase que lee el usuario: **"No se ha
/// enviado nada"**. Firestore encolaba las escrituras y las sincronizaba
/// despues; contra HTTP no se guarda nada, y decir lo contrario seria mentir.
class GuardiaEscrituras {
  ConfirmadorDeSesion? _confirmador;
  Future<bool>? _confirmacionEnVuelo;

  /// Instala la comprobación de ADR-0013 en **este único sitio**.
  ///
  /// Antes de cada petición autenticada que no sea `GET` —o sea, de cada
  /// acción que crea o modifica datos— se llama a [confirmador]:
  ///
  /// - `true`  → hay sesión confirmada, la petición sale.
  /// - `false` → se lanza [SinConexionConfirmada] **sin tocar la red**, y el
  ///   usuario recibe un mensaje claro en vez de un botón girando.
  ///
  /// Quien lo instala es `AuthService.vigilarEscriturasSinConexion()`, que
  /// además aprovecha la llamada para **intentar confirmar la sesión**: si la
  /// conexión ya volvió, el usuario no tiene que hacer nada especial para que
  /// la app vuelva a dejarle escribir.
  ///
  /// **Por qué aquí y no en cada pantalla.** Porque son nueve pantallas y
  /// veintitantas acciones; si cada una lo comprobara por su cuenta, alguna se
  /// olvidaría, y justo esa sería la que mienta al usuario. Aquí no hay forma
  /// de saltárselo: toda escritura de la app pasa por este método.
  ///
  /// Lo que **no** se bloquea, a propósito:
  /// - Las lecturas (`GET`): ADR-0013 dice "leer sí, escribir no".
  /// - `login`, `registro` y `refresh`, que son `autenticada: false` o van por
  ///   `TransporteHttp.enviar` directamente. Bloquearlas sería impedir salir
  ///   del agujero.
  /// - `logout`, por lo mismo: el usuario tiene derecho a salir siempre.
  ///
  /// Pasar `null` la desinstala (los tests que no la ejercitan).
  void instalar(ConfirmadorDeSesion? confirmador) {
    _confirmador = confirmador;
    _confirmacionEnVuelo = null;
  }

  /// Deja pasar la escritura solo si hay sesión confirmada.
  ///
  /// Si varias acciones caen aquí a la vez (dos toques rápidos, una pantalla
  /// que guarda dos cosas seguidas), comparten una sola comprobación en vuelo:
  /// confirmar la sesión cuesta una petición y no tiene sentido repetirla.
  /// Es el mismo criterio que el candado 1 de la renovación, pero es un
  /// mecanismo aparte: no comparten estado ni se pisan.
  Future<void> exigir() async {
    final confirmador = _confirmador;
    if (confirmador == null) return; // nadie instaló la comprobación

    var enVuelo = _confirmacionEnVuelo;
    if (enVuelo == null) {
      enVuelo = confirmador();
      _confirmacionEnVuelo = enVuelo;
      final lanzada = enVuelo;
      lanzada.whenComplete(() {
        if (identical(_confirmacionEnVuelo, lanzada)) {
          _confirmacionEnVuelo = null;
        }
      }).ignore();
    }

    bool confirmada;
    try {
      confirmada = await enVuelo;
    } catch (_) {
      // Si la propia comprobación revienta, se trata como "no confirmada":
      // ante la duda, no se escribe. Nunca debe tumbar la operación con una
      // excepción que la pantalla no sepa traducir.
      confirmada = false;
    }
    if (!confirmada) throw const SinConexionConfirmada();
  }
}

/// Responde si la app puede ejecutar ahora una acción que crea o modifica
/// datos (ADR-0013).
///
/// Devuelve `true` si hay **sesión confirmada** contra el servidor. Puede
/// tardar: la implementación real aprovecha para reintentar la confirmación,
/// así que si la conexión ya volvió, la acción sigue adelante sola. Nunca
/// debe lanzar; si algo falla, que devuelva `false`.
typedef ConfirmadorDeSesion = Future<bool> Function();
