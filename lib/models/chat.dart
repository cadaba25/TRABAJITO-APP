import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constantes.dart';
import 'json_utiles.dart';

/// Chat entre contratista y trabajador (uno por trabajo asignado).
class Chat {
  final String id; // = idPublicacion
  final String idPublicacion;
  final String tituloPublicacion;
  final String uidEmpleador;
  final String nombreEmpleador;
  final String uidTrabajador;
  final String nombreTrabajador;
  final List<String> participantes;
  final String ultimoMensaje;
  final DateTime fechaUltimoMensaje;
  final Map<String, int> noLeidos; // mensajes sin leer por uid
  // Negociación de pago
  final double pagoMonto;
  final String pagoPropuestoPor;
  final bool pagoAcordado;
  // Negociación de tiempo
  final String tiempoValor;
  final String tiempoPropuestoPor;
  final bool tiempoAcordado;

  const Chat({
    required this.id,
    required this.idPublicacion,
    this.tituloPublicacion = '',
    required this.uidEmpleador,
    this.nombreEmpleador = '',
    required this.uidTrabajador,
    this.nombreTrabajador = '',
    this.participantes = const [],
    this.ultimoMensaje = '',
    required this.fechaUltimoMensaje,
    this.noLeidos = const {},
    this.pagoMonto = 0,
    this.pagoPropuestoPor = '',
    this.pagoAcordado = false,
    this.tiempoValor = '',
    this.tiempoPropuestoPor = '',
    this.tiempoAcordado = false,
  });

  /// Nombre de la otra persona para mostrar en la lista/encabezado.
  String otroNombre(String miUid) =>
      miUid == uidEmpleador ? nombreTrabajador : nombreEmpleador;

  bool get pagoPendiente => pagoPropuestoPor.isNotEmpty && !pagoAcordado;
  bool get tiempoPendiente => tiempoPropuestoPor.isNotEmpty && !tiempoAcordado;

  int noLeidosDe(String uid) => noLeidos[uid] ?? 0;

  factory Chat.desdeFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      idPublicacion: d['idPublicacion'] ?? doc.id,
      tituloPublicacion: d['tituloPublicacion'] ?? '',
      uidEmpleador: d['uidEmpleador'] ?? '',
      nombreEmpleador: d['nombreEmpleador'] ?? '',
      uidTrabajador: d['uidTrabajador'] ?? '',
      nombreTrabajador: d['nombreTrabajador'] ?? '',
      participantes: (d['participantes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      ultimoMensaje: d['ultimoMensaje'] ?? '',
      fechaUltimoMensaje: d['fechaUltimoMensaje'] != null
          ? (d['fechaUltimoMensaje'] as Timestamp).toDate()
          : DateTime.now(),
      noLeidos: (d['noLeidos'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v ?? 0) as int)),
      pagoMonto: ((d['pagoMonto'] ?? 0) as num).toDouble(),
      pagoPropuestoPor: d['pagoPropuestoPor'] ?? '',
      pagoAcordado: d['pagoAcordado'] ?? false,
      tiempoValor: d['tiempoValor'] ?? '',
      tiempoPropuestoPor: d['tiempoPropuestoPor'] ?? '',
      tiempoAcordado: d['tiempoAcordado'] ?? false,
    );
  }

  // ── API propia (backend Spring Boot) ────────────────────────
  // Corresponde a la entidad `ChatRoom`. Cambios de nombre:
  //   trabajoId        → idPublicacion      tituloTrabajo    → tituloPublicacion
  //   empleadorId      → uidEmpleador       empleadorNombre  → nombreEmpleador
  //   trabajadorId     → uidTrabajador      trabajadorNombre → nombreTrabajador
  //
  // Dos diferencias de fondo, no de nombre:
  //
  // 1. **`participantes` no existe en el backend.** En Firestore era un array
  //    para poder filtrar con `array-contains`; aquí se reconstruye a partir
  //    de los dos ids, que es lo que la UI necesita (`otroNombre`).
  // 2. **`noLeidos` tampoco existe.** El backend marca `leido` mensaje a
  //    mensaje (`POST /api/chats/{id}/leido`), no lleva un contador por chat.
  //    Se deja vacío: la lista de chats mostraría 0 sin avisar. Resolverlo es
  //    parte de la migración del chat (fase 2), que además cambia los streams
  //    de Firestore por WebSocket. Ver reporte de la tarea 018.

  factory Chat.desdeJson(Map<String, dynamic> json) {
    final uidEmpleador = textoJson(json['empleadorId']);
    final uidTrabajador = textoJson(json['trabajadorId']);
    return Chat(
      id: textoJson(json['id']),
      idPublicacion: textoJson(json['trabajoId']),
      tituloPublicacion: textoJson(json['tituloTrabajo']),
      uidEmpleador: uidEmpleador,
      nombreEmpleador: textoJson(json['empleadorNombre']),
      uidTrabajador: uidTrabajador,
      nombreTrabajador: textoJson(json['trabajadorNombre']),
      participantes: [
        if (uidEmpleador.isNotEmpty) uidEmpleador,
        if (uidTrabajador.isNotEmpty) uidTrabajador,
      ],
      ultimoMensaje: textoJson(json['ultimoMensaje']),
      fechaUltimoMensaje: fechaJson(
        json['fechaUltimoMensaje'],
        siFalta: fechaJsonOpcional(json['creadoEn']),
      ),
      pagoMonto: decimalJson(json['pagoMonto']),
      pagoPropuestoPor: textoJson(json['pagoPropuestoPor']),
      pagoAcordado: boolJson(json['pagoAcordado']),
      tiempoValor: textoJson(json['tiempoValor']),
      tiempoPropuestoPor: textoJson(json['tiempoPropuestoPor']),
      tiempoAcordado: boolJson(json['tiempoAcordado']),
    );
  }

  /// El chat no se crea ni se edita desde el cliente: lo abre el backend al
  /// aceptar una postulación, y la negociación va por endpoints propios
  /// (`/api/chats/{id}/proponer-pago`, `.../aceptar-tiempo`...).
  ///
  /// Este `aJson()` existe para simetría y para poder guardar un chat en
  /// caché local; **no** es el cuerpo de ninguna petición.
  Map<String, dynamic> aJson() => {
    'id': id,
    'trabajoId': idPublicacion,
    'tituloTrabajo': tituloPublicacion,
    'empleadorId': uidEmpleador,
    'empleadorNombre': nombreEmpleador,
    'trabajadorId': uidTrabajador,
    'trabajadorNombre': nombreTrabajador,
    'ultimoMensaje': ultimoMensaje,
    'fechaUltimoMensaje': fechaAJson(fechaUltimoMensaje),
    'pagoMonto': pagoMonto,
    'pagoPropuestoPor': pagoPropuestoPor,
    'pagoAcordado': pagoAcordado,
    'tiempoValor': tiempoValor,
    'tiempoPropuestoPor': tiempoPropuestoPor,
    'tiempoAcordado': tiempoAcordado,
  };
}

/// Mensaje dentro de un chat.
class Mensaje {
  final String id;
  final String texto;
  final String deUid;
  final String tipo; // 'texto' | 'sistema'
  final DateTime fecha;

  const Mensaje({
    this.id = '',
    required this.texto,
    required this.deUid,
    this.tipo = 'texto',
    required this.fecha,
  });

  bool get esSistema => tipo == 'sistema';

  factory Mensaje.desdeFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Mensaje(
      id: doc.id,
      texto: d['texto'] ?? '',
      deUid: d['deUid'] ?? '',
      tipo: d['tipo'] ?? 'texto',
      fecha: d['fecha'] != null
          ? (d['fecha'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> aFirestore() => {
    'texto': texto,
    'deUid': deUid,
    'tipo': tipo,
    'fecha': Timestamp.fromDate(fecha),
  };

  // ── API propia (backend Spring Boot) ────────────────────────
  // Entidad `Mensaje`. El campo del texto se llama `contenido`, no `texto`, y
  // `creadoEn` hace de `fecha`. El enum `TipoMensaje` del backend tiene seis
  // valores; la app solo distingue texto de sistema (ver `TiposMensaje`).

  factory Mensaje.desdeJson(Map<String, dynamic> json) => Mensaje(
    id: textoJson(json['id']),
    texto: textoJson(json['contenido']),
    deUid: textoJson(json['deUid']),
    tipo: TiposMensaje.desdeApi(json['tipo']),
    fecha: fechaJson(json['creadoEn']),
  );

  /// Cuerpo de `POST /api/chats/{id}/mensajes`. `contenido` es obligatorio
  /// (`@NotBlank`, ADR-0008); el autor sale del token.
  Map<String, dynamic> aJson() => {'contenido': texto};
}
