import 'package:cloud_firestore/cloud_firestore.dart';

import 'json_utiles.dart';

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

  // ── API propia (backend Spring Boot) ────────────────────────
  // Entidad `Evidencia`. Cambian: autorId → autorUid, creadoEn → fecha.
  //
  // El backend además guarda `archivoUrl` (la foto/vídeo que Firestore nunca
  // llegó a tener, porque hacía falta Firebase Storage). Este modelo todavía
  // no tiene dónde ponerlo; añadir el campo es trabajo de la pantalla de
  // "entregar con evidencias" (fase 3). Ver reporte de la tarea 018.

  factory Evidencia.desdeJson(Map<String, dynamic> json) => Evidencia(
    id: textoJson(json['id']),
    texto: textoJson(json['texto']),
    autorUid: textoJson(json['autorId']),
    autorNombre: textoJson(json['autorNombre']),
    fecha: fechaJson(json['creadoEn']),
  );

  /// Cuerpo de `POST /api/trabajos/{trabajoId}/evidencias`. `texto` es
  /// obligatorio en el backend (`@NotBlank`, ADR-0008).
  Map<String, dynamic> aJson() => {'texto': texto};
}
