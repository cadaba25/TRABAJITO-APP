import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sesion_api.dart';

/// Dónde se guardan la sesión y la URL del servidor entre arranques de la app.
///
/// Es una interfaz para poder probar `ApiClient` sin tocar el almacén real del
/// dispositivo (los canales de plataforma no existen en `flutter test`).
abstract interface class AlmacenSesion {
  Future<SesionApi?> leerSesion();
  Future<void> guardarSesion(SesionApi sesion);
  Future<void> borrarSesion();

  /// URL base elegida a mano en este dispositivo (pantalla de desarrollo o
  /// demo). `null` = usar la de `--dart-define` o la de por defecto.
  Future<String?> leerUrlBase();
  Future<void> guardarUrlBase(String? url);
}

/// Implementación real: Keychain en iOS y almacenamiento cifrado con clave del
/// Android Keystore en Android.
///
/// **Por qué `flutter_secure_storage` y no `shared_preferences`:** lo que se
/// guarda aquí es un refresh token de 30 días que **es** la sesión — quien lo
/// tenga puede pedir tokens de acceso nuevos hasta que se revoque.
/// `shared_preferences` escribe XML en claro dentro del sandbox de la app: en
/// un dispositivo con root, o vía copia de seguridad de Android, es legible.
/// El almacén seguro cifra el valor (AES-GCM) con una clave envuelta por el
/// Keystore del hardware, que no sale de él.
///
/// Firebase Auth guardaba su propia sesión por dentro y este problema no
/// existía como decisión nuestra; al pasar al backend propio, sí lo es.
class AlmacenSesionSeguro implements AlmacenSesion {
  AlmacenSesionSeguro({FlutterSecureStorage? almacen})
      : _almacen = almacen ??
            const FlutterSecureStorage(
              // En la v11 del paquete el cifrado ya es el comportamiento por
              // defecto en Android (AES-GCM + clave envuelta con RSA en el
              // Keystore); no hay que activarlo con ningún flag.
              aOptions: AndroidOptions(),
              // `first_unlock`: legible tras el primer desbloqueo desde el
              // arranque. Hace falta para que la app pueda renovar el token en
              // segundo plano; `unlocked` lo impediría.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _almacen;

  static const String _claveSesion = 'trabajito.sesion';
  static const String _claveUrlBase = 'trabajito.url_base';

  @override
  Future<SesionApi?> leerSesion() async {
    final crudo = await _almacen.read(key: _claveSesion);
    final sesion = SesionApi.deserializar(crudo);
    // Lo guardado no se entiende (formato viejo o dato corrupto): se limpia
    // para no reintentar leerlo en cada arranque.
    if (sesion == null && crudo != null) {
      await _almacen.delete(key: _claveSesion);
    }
    return sesion;
  }

  @override
  Future<void> guardarSesion(SesionApi sesion) =>
      _almacen.write(key: _claveSesion, value: sesion.serializar());

  @override
  Future<void> borrarSesion() => _almacen.delete(key: _claveSesion);

  @override
  Future<String?> leerUrlBase() => _almacen.read(key: _claveUrlBase);

  @override
  Future<void> guardarUrlBase(String? url) => (url == null || url.isEmpty)
      ? _almacen.delete(key: _claveUrlBase)
      : _almacen.write(key: _claveUrlBase, value: url);
}

/// Almacén en memoria, para tests y para arrancar sin plugins de plataforma.
/// **No persiste nada**: al cerrar la app la sesión se pierde.
class AlmacenSesionEnMemoria implements AlmacenSesion {
  SesionApi? _sesion;
  String? _urlBase;

  /// Cuántas veces se ha escrito la sesión. Los tests lo usan para comprobar
  /// que un refresco compartido guarda una sola vez.
  int escrituras = 0;

  @override
  Future<SesionApi?> leerSesion() async => _sesion;

  @override
  Future<void> guardarSesion(SesionApi sesion) async {
    _sesion = sesion;
    escrituras++;
  }

  @override
  Future<void> borrarSesion() async => _sesion = null;

  @override
  Future<String?> leerUrlBase() async => _urlBase;

  @override
  Future<void> guardarUrlBase(String? url) async => _urlBase = url;
}
