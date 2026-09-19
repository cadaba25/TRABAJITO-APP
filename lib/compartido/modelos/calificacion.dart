import 'json_utiles.dart';

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

  // ── API propia (backend Spring Boot) ────────────────────────
  // Entidad `Calificacion` del backend. Nombres distintos a los de Firestore:
  //   trabajoId → idPublicacion, autorId → deUid, receptorId → paraUid,
  //   creadoEn  → fecha
  //
  // `CalificacionResponse` manda `rolCalificado` (TRABAJADOR/EMPLEADOR) pero
  // NO el nombre del autor: `deNombre` queda vacío y la reseña se pinta como
  // "Anónimo" hasta que el backend lo incluya (ver reporte de la tarea 052).

  factory Calificacion.desdeJson(Map<String, dynamic> json) => Calificacion(
    id: textoJson(json['id']),
    idPublicacion: textoJson(json['trabajoId']),
    deUid: textoJson(json['autorId']),
    deNombre: textoJson(json['autorNombre']),
    paraUid: textoJson(json['receptorId']),
    rolCalificado: textoJson(json['rolCalificado']),
    estrellas: enteroJson(json['estrellas']),
    comentario: textoJson(json['comentario']),
    fecha: fechaJson(json['creadoEn']),
  );

  /// Cuerpo de `POST /api/calificaciones`. Solo lleva lo que el backend acepta
  /// del cliente: quién califica sale del token, no del cuerpo.
  Map<String, dynamic> aJson() => {
    'trabajoId': idPublicacion,
    'receptorId': paraUid,
    'estrellas': estrellas,
    'comentario': comentario,
  };
}
