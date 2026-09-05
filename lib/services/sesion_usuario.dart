import 'package:flutter/foundation.dart';

import '../models/usuario.dart';

/// En qué punto está la sesión del usuario.
///
/// Sustituye a lo que antes decía `FirebaseAuth.authStateChanges()`: un
/// `Stream<User?>` con tres estados implícitos (sin emitir todavía / emitió
/// `null` / emitió un usuario). Aquí son explícitos, porque la diferencia
/// entre "aún no sé" y "no hay sesión" decide si la app enseña la pantalla de
/// carga o el login, y confundirlas hace parpadear el login en cada arranque.
enum FaseSesion {
  /// Todavía no se sabe: la app está leyendo el almacén seguro del
  /// dispositivo y, si había sesión, comprobándola contra el servidor.
  comprobando,

  /// No hay sesión: toca login.
  sinSesion,

  /// Hay sesión y [EstadoSesion.usuario] está relleno.
  conSesion,
}

/// Foto fija del estado de la sesión.
@immutable
class EstadoSesion {
  const EstadoSesion._(this.fase, this.usuario, this.avisoSinConexion);

  const EstadoSesion.comprobando()
      : this._(FaseSesion.comprobando, null, false);

  const EstadoSesion.sinSesion() : this._(FaseSesion.sinSesion, null, false);

  /// [perfilSinConfirmar] marca la sesión que se restauró del dispositivo pero
  /// **no se pudo confirmar contra el servidor** porque no había conexión. El
  /// usuario entra igual (echarlo por un corte de red sería peor), pero la app
  /// sabe que ese perfil puede estar viejo.
  const EstadoSesion.conSesion(Usuario usuario,
      {bool perfilSinConfirmar = false})
      : this._(FaseSesion.conSesion, usuario, perfilSinConfirmar);

  final FaseSesion fase;

  /// El usuario de la sesión, o `null` si no hay ninguna.
  final Usuario? usuario;

  /// `true` si el perfil viene del almacén del dispositivo y no se pudo
  /// refrescar contra el servidor.
  final bool avisoSinConexion;

  bool get hay => fase == FaseSesion.conSesion && usuario != null;

  @override
  // El parametro se llama `other` y no `otro` porque asi se llama en
  // `Object`, y el analizador avisa si no coincide. Es la unica excepcion a
  // la convencion en espanol del proyecto.
  bool operator ==(Object other) =>
      other is EstadoSesion &&
      other.fase == fase &&
      other.avisoSinConexion == avisoSinConexion &&
      // `Usuario` no implementa `==`; comparar la identidad basta, porque cada
      // respuesta del servidor crea una instancia nueva.
      identical(other.usuario, usuario);

  @override
  int get hashCode => Object.hash(fase, usuario, avisoSinConexion);

  @override
  String toString() => 'EstadoSesion($fase, ${usuario?.correo ?? '-'})';
}

/// Estado de sesión de la app, en memoria y observable.
///
/// **Por qué esto y no un `Stream`.** Firestore daba `streamUsuarioActual()`
/// gratis: un documento en vivo que se actualizaba solo. Contra HTTP eso no
/// existe, y emularlo con sondeo sería gastar batería y datos móviles de un
/// trabajador en la calle para nada. La decisión del `tech-lead` para la
/// fase 2 (ver tarea 018) es **carga puntual + deslizar para actualizar**,
/// salvo el chat.
///
/// Para el usuario de la sesión eso se concreta aquí: un objeto en memoria que
/// se rellena al iniciar sesión, se vuelve a pedir al arrancar la app
/// (`GET /api/auth/yo`) y se refresca después de cada edición del perfil. Es
/// un [ValueNotifier], que es lo que este proyecto ya usa para el tema
/// (`notificadorTema` en `utils/constantes.dart`), así que las pantallas lo
/// consumen con `ValueListenableBuilder` sin traer ninguna librería de estado.
class SesionUsuario extends ValueNotifier<EstadoSesion> {
  SesionUsuario() : super(const EstadoSesion.comprobando());

  Usuario? get usuario => value.usuario;

  /// Id del usuario en el backend (un UUID), o `''` si no hay sesión.
  ///
  /// **Ojo:** ya no es el `uid` de Firebase. Los servicios que siguen
  /// hablando con Firestore reciben este identificador y no encontrarán nada,
  /// porque en Firestore no existe. Es la consecuencia esperada de migrar la
  /// autenticación primero; ver el reporte de la tarea 020.
  String get uid => value.usuario?.uid ?? '';

  bool get hay => value.hay;

  void comprobando() => value = const EstadoSesion.comprobando();

  void entrar(Usuario usuario, {bool perfilSinConfirmar = false}) =>
      value = EstadoSesion.conSesion(usuario,
          perfilSinConfirmar: perfilSinConfirmar);

  void salir() => value = const EstadoSesion.sinSesion();

  /// Reemplaza el perfil sin cambiar de sesión (tras editarlo o recargarlo).
  /// Si no había sesión no hace nada: no es forma de iniciar una.
  void actualizarPerfil(Usuario usuario) {
    if (!value.hay) return;
    value = EstadoSesion.conSesion(usuario);
  }
}

/// Sesión única de la app. Mismo estilo que `notificadorTema`: la app no tiene
/// contenedor de inyección de dependencias y no se va a añadir uno solo para
/// esto (ver el reporte de la tarea 018).
final SesionUsuario sesionActual = SesionUsuario();
