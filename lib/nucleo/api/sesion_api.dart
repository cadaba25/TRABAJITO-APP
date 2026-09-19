import 'dart:convert';

/// La sesión tal y como la devuelve el backend en `/api/auth/registro`,
/// `/api/auth/login` y `/api/auth/refresh` (ADR-0010, tarea 015).
///
/// Forma verificada contra el servidor real el 2026-08-27 (los valores de los
/// tokens van sustituidos aquí: no se escriben tokens reales en el repo):
///
/// ```json
/// {"token":"<JWT>","refreshToken":"<43 caracteres base64url>",
///  "tokenType":"Bearer","expiraEnSegundos":900,"usuario":{...}}
/// ```
///
/// Dos cosas que condicionan todo el cliente:
///
/// - `token` (JWT de acceso) **dura 15 minutos**.
/// - `refreshToken` es una cadena opaca que **rota en cada uso**. Presentar
///   uno ya rotado hace que el backend revoque la familia entera y expulse al
///   usuario, así que nunca puede haber dos refrescos a la vez. De eso se
///   encarga `ApiClient`.
class SesionApi {
  const SesionApi({
    required this.token,
    required this.refreshToken,
    required this.expiraEn,
    this.tipoToken = 'Bearer',
    this.usuario = const {},
  });

  /// JWT de acceso. Va en `Authorization: Bearer <token>`.
  final String token;

  /// Cadena opaca revocable. **Nunca** se manda en una cabecera: solo en el
  /// cuerpo de `/api/auth/refresh` y `/api/auth/logout`.
  final String refreshToken;

  /// Momento (hora del dispositivo) en que caduca [token].
  final DateTime expiraEn;

  /// Siempre `"Bearer"` hoy; se guarda por si el backend lo cambia.
  final String tipoToken;

  /// El `UsuarioResponse` crudo que vino junto a la sesión. Se conserva en JSON
  /// —y no como `Usuario`— para que esta clase no dependa de los modelos y
  /// para poder rehidratar el perfil al arrancar sin pedirlo al servidor.
  final Map<String, dynamic> usuario;

  /// Cabecera de autorización lista para usar.
  String get cabeceraAutorizacion => '$tipoToken $token';

  /// `true` si [token] ya caducó, con [margen] de adelanto para que no
  /// caduque en pleno vuelo de la petición.
  bool caducado({Duration margen = Duration.zero}) =>
      DateTime.now().add(margen).isAfter(expiraEn);

  /// Construye la sesión desde la respuesta del backend.
  ///
  /// [ahora] existe solo para que los tests puedan fijar el reloj.
  factory SesionApi.desdeJson(Map<String, dynamic> json, {DateTime? ahora}) {
    final token = json['token'];
    final refresh = json['refreshToken'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('La respuesta de sesión no trae "token".');
    }
    if (refresh is! String || refresh.isEmpty) {
      throw const FormatException(
          'La respuesta de sesión no trae "refreshToken".');
    }
    final segundos = json['expiraEnSegundos'];
    final vida = segundos is num ? segundos.toInt() : 0;
    final usuario = json['usuario'];
    return SesionApi(
      token: token,
      refreshToken: refresh,
      tipoToken: json['tokenType'] is String
          ? json['tokenType'] as String
          : 'Bearer',
      expiraEn: (ahora ?? DateTime.now()).add(Duration(seconds: vida)),
      usuario: usuario is Map
          ? Map<String, dynamic>.from(usuario)
          : const <String, dynamic>{},
    );
  }

  /// Copia con el mismo usuario pero tokens nuevos (tras un refresco).
  SesionApi conTokensDe(SesionApi nueva) => SesionApi(
        token: nueva.token,
        refreshToken: nueva.refreshToken,
        expiraEn: nueva.expiraEn,
        tipoToken: nueva.tipoToken,
        usuario: nueva.usuario.isEmpty ? usuario : nueva.usuario,
      );

  /// Forma en la que se persiste en el almacén seguro. Se guarda [expiraEn]
  /// como marca absoluta y no como duración, porque entre que se guarda y se
  /// vuelve a abrir la app puede pasar cualquier cosa.
  Map<String, dynamic> aJson() => {
        'token': token,
        'refreshToken': refreshToken,
        'tokenType': tipoToken,
        'expiraEn': expiraEn.toIso8601String(),
        'usuario': usuario,
      };

  String serializar() => jsonEncode(aJson());

  /// Inverso de [serializar]. Devuelve `null` si lo guardado no se entiende
  /// (formato viejo, dato corrupto): es preferible pedir login otra vez a
  /// reventar al arrancar.
  static SesionApi? deserializar(String? crudo) {
    if (crudo == null || crudo.isEmpty) return null;
    try {
      final json = jsonDecode(crudo);
      if (json is! Map<String, dynamic>) return null;
      final token = json['token'];
      final refresh = json['refreshToken'];
      final expira = DateTime.tryParse('${json['expiraEn']}');
      if (token is! String || refresh is! String || expira == null) return null;
      final usuario = json['usuario'];
      return SesionApi(
        token: token,
        refreshToken: refresh,
        tipoToken:
            json['tokenType'] is String ? json['tokenType'] as String : 'Bearer',
        expiraEn: expira,
        usuario: usuario is Map
            ? Map<String, dynamic>.from(usuario)
            : const <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
  }

  /// No imprime los tokens: acabarían en los logs.
  @override
  String toString() =>
      'SesionApi(usuario: ${usuario['correo'] ?? '?'}, expiraEn: $expiraEn)';
}

/// Qué le pasó a la sesión, para que la app reaccione (por ejemplo, volviendo
/// al login). `ApiClient` los publica en `ApiClient.eventosSesion`.
enum EventoSesion {
  /// Se guardó una sesión nueva (login o registro).
  iniciada,

  /// Se renovó el par de tokens sin que el usuario notara nada.
  renovada,

  /// La sesión terminó: logout explícito, refresh caducado/revocado, o el
  /// backend detectó reutilización del refresh token y revocó la familia.
  terminada,
}
