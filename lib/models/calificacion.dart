import 'package:cloud_firestore/cloud_firestore.dart';

/// Calificación (reseña) de un participante hacia el otro tras completar un trabajo.
class Calificacion {
  final String id;
  final String idPublicacion;
  final String deUid;          // quién califica
  final String deNombre;
  final String paraUid;        // a quién califica
  final String rolCalificado;  // 'trabajador' | 'empleador'
  final int estrellas;         // 1..5
  final String comentario;
  final DateTime fecha;

  const Calificacion({
    this.id = '',
    required this.idPublicacion,
    required this.deUid,
    this.deNombre = '',
    required this.paraUid,
    required this.rolCalificado,
    required this.estrellas,
    this.comentario = '',
    required this.fecha,
  });

  factory Calificacion.desdeFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Calificacion(
      id: doc.id,
      idPublicacion: d['idPublicacion'] ?? '',
      deUid: d['deUid'] ?? '',
      deNombre: d['deNombre'] ?? '',
      paraUid: d['paraUid'] ?? '',
      rolCalificado: d['rolCalificado'] ?? '',
      estrellas: (d['estrellas'] ?? 0) as int,
      comentario: d['comentario'] ?? '',
      fecha: d['fecha'] != null
          ? (d['fecha'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> aFirestore() => {
    'idPublicacion': idPublicacion,
    'deUid': deUid,
    'deNombre': deNombre,
    'paraUid': paraUid,
    'rolCalificado': rolCalificado,
    'estrellas': estrellas,
    'comentario': comentario,
    'fecha': Timestamp.fromDate(fecha),
  };
}
