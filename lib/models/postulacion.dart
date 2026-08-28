import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constantes.dart';
import 'json_utiles.dart';

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

  // ── API propia (backend Spring Boot) ────────────────────────
  // Entidad `Postulacion`. Cambian: trabajoId → idPublicacion,
  // trabajadorId → uidTrabajador, trabajadorNombre → nombreTrabajador,
  // creadoEn → fechaPostulacion, y `estado` viene en MAYÚSCULAS.
  //
  // El backend NO manda `tituloPublicacion` ni `uidEmpleador`; en Firestore
  // estaban desnormalizados dentro de la postulación para pintar la lista sin
  // una segunda lectura. La fase 2 tendrá que resolverlo (pedir el trabajo
  // aparte o ampliar el DTO del backend). Ver reporte de la tarea 018.

  factory Postulacion.desdeJson(Map<String, dynamic> json) => Postulacion(
    id: textoJson(json['id']),
    idPublicacion: textoJson(json['trabajoId']),
    tituloPublicacion: textoJson(json['tituloTrabajo']),
    uidTrabajador: textoJson(json['trabajadorId']),
    nombreTrabajador: textoJson(json['trabajadorNombre']),
    uidEmpleador: textoJson(json['empleadorId']),
    mensaje: textoJson(json['mensaje']),
    estado: EstadosPostulacion.desdeApi(json['estado']),
    fechaPostulacion: fechaJson(json['creadoEn']),
  );

  /// Cuerpo de `POST /api/postulaciones`. `trabajoId` es obligatorio
  /// (`@NotNull`, ADR-0008); el trabajador sale del token.
  Map<String, dynamic> aJson() => {
    'trabajoId': idPublicacion,
    'mensaje': mensaje,
  };
}
