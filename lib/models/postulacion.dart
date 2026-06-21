import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constantes.dart';

/// Postulación de un trabajador a una publicación.
class Postulacion {
  final String id;
  final String idPublicacion;
  final String tituloPublicacion;
  final String uidTrabajador;
  final String nombreTrabajador;
  final String uidEmpleador;
  final String mensaje;
  final String estado; // pendiente | aceptada | rechazada | retirada
  final DateTime fechaPostulacion;

  const Postulacion({
    this.id = '',
    required this.idPublicacion,
    this.tituloPublicacion = '',
    required this.uidTrabajador,
    required this.nombreTrabajador,
    required this.uidEmpleador,
    this.mensaje = '',
    this.estado = EstadosPostulacion.pendiente,
    required this.fechaPostulacion,
  });

  String get tiempoRelativo {
    final d = DateTime.now().difference(fechaPostulacion);
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays < 7) return 'hace ${d.inDays} d';
    return 'hace ${(d.inDays / 7).floor()} sem';
  }

  factory Postulacion.desdeFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Postulacion(
      id: doc.id,
      idPublicacion: d['idPublicacion'] ?? '',
      tituloPublicacion: d['tituloPublicacion'] ?? '',
      uidTrabajador: d['uidTrabajador'] ?? '',
      nombreTrabajador: d['nombreTrabajador'] ?? '',
      uidEmpleador: d['uidEmpleador'] ?? '',
      mensaje: d['mensaje'] ?? '',
      estado: d['estado'] ?? EstadosPostulacion.pendiente,
      fechaPostulacion: d['fechaPostulacion'] != null
          ? (d['fechaPostulacion'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> aFirestore() => {
    'idPublicacion': idPublicacion,
    'tituloPublicacion': tituloPublicacion,
    'uidTrabajador': uidTrabajador,
    'nombreTrabajador': nombreTrabajador,
    'uidEmpleador': uidEmpleador,
    'mensaje': mensaje,
    'estado': estado,
    'fechaPostulacion': Timestamp.fromDate(fechaPostulacion),
  };
}
