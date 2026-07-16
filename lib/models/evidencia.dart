import 'package:cloud_firestore/cloud_firestore.dart';

/// Evidencia/avance de un trabajo (comentario; fotos/videos requieren
/// Firebase Storage — pendiente).
class Evidencia {
  final String id;
  final String texto;
  final String autorUid;
  final String autorNombre;
  final DateTime fecha;

  const Evidencia({
    this.id = '',
    required this.texto,
    required this.autorUid,
    this.autorNombre = '',
    required this.fecha,
  });

  String get tiempoRelativo {
    final d = DateTime.now().difference(fecha);
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    return 'hace ${d.inDays} d';
  }

  factory Evidencia.desdeFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Evidencia(
      id: doc.id,
      texto: d['texto'] ?? '',
      autorUid: d['autorUid'] ?? '',
      autorNombre: d['autorNombre'] ?? '',
      fecha: d['fecha'] != null
          ? (d['fecha'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> aFirestore() => {
    'texto': texto,
    'autorUid': autorUid,
    'autorNombre': autorNombre,
    'fecha': Timestamp.fromDate(fecha),
  };
}
