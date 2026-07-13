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
  final String plazo;        // 'Corto plazo' | 'Medio plazo' | 'Largo plazo'
  final DateTime fechaCreacion;
  final String estado;       // activo | asignado | en_progreso | completado | cerrado
  final String uidTrabajadorAsignado;
  final String nombreTrabajadorAsignado;
  final bool calificadoPorEmpleador;
  final bool calificadoPorTrabajador;
  // Pago en garantía (escrow)
  final double montoAcordado;   // pago reservado por el contratista
  final bool pagoRetenido;      // el contratista ya depositó en garantía
  final bool entregado;         // el trabajador marcó el trabajo como entregado
  final bool pagoLiberado;      // el pago se liberó al trabajador

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
    this.plazo = '',
    required this.fechaCreacion,
    this.estado = 'activo',
    this.uidTrabajadorAsignado = '',
    this.nombreTrabajadorAsignado = '',
    this.calificadoPorEmpleador = false,
    this.calificadoPorTrabajador = false,
    this.montoAcordado = 0,
    this.pagoRetenido = false,
    this.entregado = false,
    this.pagoLiberado = false,
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
      plazo: d['plazo'] ?? '',
      fechaCreacion: d['fechaCreacion'] != null
          ? (d['fechaCreacion'] as Timestamp).toDate()
          : DateTime.now(),
      estado: d['estado'] ?? 'activo',
      uidTrabajadorAsignado: d['uidTrabajadorAsignado'] ?? '',
      nombreTrabajadorAsignado: d['nombreTrabajadorAsignado'] ?? '',
      calificadoPorEmpleador: d['calificadoPorEmpleador'] ?? false,
      calificadoPorTrabajador: d['calificadoPorTrabajador'] ?? false,
      montoAcordado: ((d['montoAcordado'] ?? 0) as num).toDouble(),
      pagoRetenido: d['pagoRetenido'] ?? false,
      entregado: d['entregado'] ?? false,
      pagoLiberado: d['pagoLiberado'] ?? false,
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
    'plazo': plazo,
    'fechaCreacion': Timestamp.fromDate(fechaCreacion),
    'estado': estado,
    'uidTrabajadorAsignado': uidTrabajadorAsignado,
    'nombreTrabajadorAsignado': nombreTrabajadorAsignado,
    'calificadoPorEmpleador': calificadoPorEmpleador,
    'calificadoPorTrabajador': calificadoPorTrabajador,
    'montoAcordado': montoAcordado,
    'pagoRetenido': pagoRetenido,
    'entregado': entregado,
    'pagoLiberado': pagoLiberado,
  };
}
