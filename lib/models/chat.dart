import 'package:cloud_firestore/cloud_firestore.dart';

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
}
