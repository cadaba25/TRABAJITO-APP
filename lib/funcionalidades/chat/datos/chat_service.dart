import 'package:flutter/foundation.dart';

import '../../../compartido/modelos/json_utiles.dart';
import '../../../nucleo/api/api_client.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../../nucleo/api/configuracion_api.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import 'chat.dart';

/// Chats y negociación de pago/tiempo **contra el backend propio**
/// (`/api/chats/**`). Migrado desde Firestore en la tarea 053 (ADR-0018).
///
/// ## Lo que cambia respecto a la versión con Firestore
///
/// | Antes | Ahora |
/// |---|---|
/// | `streamMisChats` / `streamChat` / `streamMensajes` / `streamTotalNoLeidos` | cargas puntuales ([misChats], [obtenerChat], [mensajes], [totalNoLeidos]); **la pantalla las repite con un sondeo** (`SondeoPeriodico`) |
/// | `asegurarChat` (crear/reparar) | desaparece: el chat lo crea el servidor al aceptar la postulación. [chatDeTrabajo] devuelve `null` si aún no existe |
/// | el id del chat era el del trabajo | el id es un UUID propio; el del trabajo se resuelve con [chatDeTrabajo] |
/// | el cliente decidía qué mensaje de sistema escribir | los textos ("Pago acordado: L. 150.00 / hora"...) los pone el servidor |
/// | `uid` como parámetro de cada llamada | sale del JWT |
///
/// Las lecturas lanzan [ExcepcionApi] (la pantalla decide qué enseñar); las
/// acciones devuelven `null` si fue bien o el texto del error, como el resto de
/// servicios migrados.
class ChatService {
  ChatService({ApiClient? cliente}) : _api = cliente ?? ApiClient.instancia;

  final ApiClient _api;

  /// Chats propios, del más reciente al más antiguo, con los no leídos ya
  /// puestos. Si el contador falla, la lista se devuelve igual con 0 (un
  /// badge mal no justifica esconder las conversaciones).
  Future<List<Chat>> misChats() async {
    final lista = await _lista(RutasApi.chats);
    Map<String, int> porChat = const {};
    try {
      porChat = (await _noLeidos()).porChat;
    } on ExcepcionApi catch (e) {
      debugPrint('No se pudieron leer los no leídos: ${e.mensaje}');
    }
    return [
      for (final j in lista)
        Chat.desdeJson(j).conNoLeidos(porChat[textoJson(j['id'])] ?? 0),
    ]..sort((a, b) => b.fechaUltimoMensaje.compareTo(a.fechaUltimoMensaje));
  }

  /// Total de mensajes sin leer (para el badge de la pestaña).
  Future<int> totalNoLeidos() async => (await _noLeidos()).total;

  Future<Chat> obtenerChat(String chatId) async =>
      Chat.desdeJson(await _api.obtenerObjeto(RutasApi.chat(chatId)));

  /// Chat del trabajo, o `null` si el servidor responde 404 (el trabajo aún
  /// no tiene a nadie asignado, o se asignó antes de existir el chat).
  Future<Chat?> chatDeTrabajo(String trabajoId) async {
    try {
      return Chat.desdeJson(
          await _api.obtenerObjeto(RutasApi.chatDeTrabajo(trabajoId)));
    } on NoEncontrado {
      return null;
    }
  }

  /// Mensajes del chat en orden ascendente. Con [desde] solo los
  /// **estrictamente posteriores** a esa fecha (sondeo incremental); quien
  /// llama debe deduplicar por id, porque la fecha del cliente se trunca a
  /// microsegundos.
  Future<List<Mensaje>> mensajes(String chatId, {DateTime? desde}) async {
    final lista = await _lista(
      RutasApi.mensajesDe(chatId),
      consulta: desde == null ? null : {'desde': fechaAJson(desde)},
    );
    return [for (final j in lista) Mensaje.desdeJson(j)];
  }

  /// Envía un mensaje de texto. `null` si fue bien.
  Future<String?> enviarMensaje(String chatId, String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return Future.value(null);
    return _intentar(() async {
      await _api.crear(RutasApi.mensajesDe(chatId),
          cuerpo: Mensaje(texto: limpio, deUid: '', fecha: DateTime.now())
              .aJson());
      return null;
    });
  }

  /// Marca como leídos los mensajes del otro. Best-effort: un fallo aquí no
  /// se le enseña al usuario (se reintenta en el siguiente tic).
  Future<void> marcarLeido(String chatId) async {
    try {
      await _api.crear(RutasApi.chatLeido(chatId));
    } on ExcepcionApi catch (e) {
      debugPrint('No se pudo marcar leído: ${e.mensaje}');
    }
  }

  // ── Negociación ─────────────────────────────────────────────
  // La primera propuesta de pago debe hacerla el trabajador (400 si no); el
  // texto del servidor se enseña tal cual.

  Future<String?> proponerPago(String chatId, double monto) =>
      _accion(RutasApi.proponerPago(chatId), {'monto': monto});

  Future<String?> aceptarPago(String chatId) =>
      _accion(RutasApi.aceptarPago(chatId));

  Future<String?> proponerTiempo(String chatId, String valor) =>
      _accion(RutasApi.proponerTiempo(chatId), {'tiempo': valor});

  Future<String?> aceptarTiempo(String chatId) =>
      _accion(RutasApi.aceptarTiempo(chatId));

  Future<String?> _accion(String ruta, [Map<String, Object?>? cuerpo]) {
    return _intentar(() async {
      await _api.crear(ruta, cuerpo: cuerpo);
      return null;
    });
  }

  Future<({int total, Map<String, int> porChat})> _noLeidos() async {
    final json = await _api.obtenerObjeto(RutasApi.chatsNoLeidos);
    final crudo = json['porChat'];
    return (
      total: enteroJson(json['total']),
      porChat: {
        if (crudo is Map)
          for (final e in crudo.entries) '${e.key}': enteroJson(e.value),
      },
    );
  }

  Future<List<Map<String, dynamic>>> _lista(String ruta,
      {Map<String, Object?>? consulta}) async {
    final json = await _api.obtener(ruta, consulta: consulta);
    if (json is! List) {
      throw RespuestaIlegible(detalle: 'Se esperaba una lista en $ruta');
    }
    return [
      for (final e in json)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  Future<String?> _intentar(Future<String?> Function() operacion) async {
    try {
      return await operacion();
    } on ExcepcionApi catch (e) {
      if (e.campos.isNotEmpty) return e.campos.values.first;
      return e.mensaje;
    } catch (e) {
      debugPrint('Fallo inesperado en ChatService: $e');
      return MensajesError.errorGeneral;
    }
  }
}
