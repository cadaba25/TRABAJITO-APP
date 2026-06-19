import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de una publicación de trabajo/servicio creada por un empleador.
class Publicacion {
  final String id;
  final String uidEmpleador;
  final String autor;        // nombre visible del empleador / empresa
  final String categoria;    // sector / rubro
  final String titulo;
  final String descripcion;
  final String departamento;
  final String ciudad;
  final String presupuesto;  // texto libre, p. ej. "L. 800"
  final DateTime fechaCreacion;
  final String estado;       // 'activo' | 'cerrado'

  const Publicacion({
    this.id = '',
    required this.uidEmpleador,
    required this.autor,
    required this.categoria,
    required this.titulo,
    required this.descripcion,
    this.departamento = '',
    this.ciudad = '',
    this.presupuesto = '',
    required this.fechaCreacion,
    this.estado = 'activo',
  });

  /// Ubicación legible para la UI.
  String get ubicacion {
    if (ciudad.isNotEmpty && departamento.isNotEmpty) return '$ciudad, $departamento';
    if (ciudad.isNotEmpty) return ciudad;
    return departamento;
  }

  /// Tiempo transcurrido desde la publicación, en formato corto.
  String get tiempoRelativo {
    final d = DateTime.now().difference(fechaCreacion);
    if (d.inSeconds < 60) return 'hace un momento';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays < 7) return 'hace ${d.inDays} d';
    final semanas = (d.inDays / 7).floor();
    return 'hace $semanas sem';
  }

  factory Publicacion.desdeFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Publicacion(
      id: doc.id,
      uidEmpleador: d['uidEmpleador'] ?? '',
      autor: d['autor'] ?? '',
      categoria: d['categoria'] ?? '',
      titulo: d['titulo'] ?? '',
      descripcion: d['descripcion'] ?? '',
      departamento: d['departamento'] ?? '',
      ciudad: d['ciudad'] ?? '',
      presupuesto: d['presupuesto'] ?? '',
      fechaCreacion: d['fechaCreacion'] != null
          ? (d['fechaCreacion'] as Timestamp).toDate()
          : DateTime.now(),
      estado: d['estado'] ?? 'activo',
    );
  }

  Map<String, dynamic> aFirestore() => {
    'uidEmpleador': uidEmpleador,
    'autor': autor,
    'categoria': categoria,
    'titulo': titulo,
    'descripcion': descripcion,
    'departamento': departamento,
    'ciudad': ciudad,
    'presupuesto': presupuesto,
    'fechaCreacion': Timestamp.fromDate(fechaCreacion),
    'estado': estado,
  };
}
