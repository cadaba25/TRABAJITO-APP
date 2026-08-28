import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constantes.dart';
import 'json_utiles.dart';

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
  final String zona;         // colonia / barrio / referencia
  final String presupuesto;  // texto libre, p. ej. "L. 800"
  final String plazo;        // 'Corto plazo' | 'Medio plazo' | 'Largo plazo'
  final DateTime fechaCreacion;
  final String estado;       // activo | asignado | en_progreso | completado | cerrado
  final String uidTrabajadorAsignado;
  final String nombreTrabajadorAsignado;
  final bool calificadoPorEmpleador;
  final bool calificadoPorTrabajador;
  // Contrato / escrow
  final double montoAcordado;   // pago acordado (por hora) reservado
  final String tiempoAcordado;  // plazo acordado (texto)
  final DateTime? fechaAcuerdo;  // cuándo se creó el contrato
  final DateTime? fechaInicio;   // cuándo el trabajador inició
  final bool pagoRetenido;      // el contratista ya depositó en garantía
  final bool entregado;         // el trabajador marcó como terminado
  final bool pagoLiberado;      // el pago se liberó al trabajador
  final bool correccionSolicitada;
  final String motivoCorreccion;

  const Publicacion({
    this.id = '',
    required this.uidEmpleador,
    required this.autor,
    required this.categoria,
    required this.titulo,
    required this.descripcion,
    this.departamento = '',
    this.ciudad = '',
    this.zona = '',
    this.presupuesto = '',
    this.plazo = '',
    required this.fechaCreacion,
    this.estado = 'activo',
    this.uidTrabajadorAsignado = '',
    this.nombreTrabajadorAsignado = '',
    this.calificadoPorEmpleador = false,
    this.calificadoPorTrabajador = false,
    this.montoAcordado = 0,
    this.tiempoAcordado = '',
    this.fechaAcuerdo,
    this.fechaInicio,
    this.pagoRetenido = false,
    this.entregado = false,
    this.pagoLiberado = false,
    this.correccionSolicitada = false,
    this.motivoCorreccion = '',
  });

  /// Ubicación legible para la UI (ciudad + departamento).
  String get ubicacion {
    if (ciudad.isNotEmpty && departamento.isNotEmpty) return '$ciudad, $departamento';
    if (ciudad.isNotEmpty) return ciudad;
    return departamento;
  }

  /// Ubicación detallada, incluyendo la zona/colonia si está disponible.
  String get ubicacionDetallada {
    final base = ubicacion;
    if (zona.isNotEmpty) return base.isEmpty ? zona : '$zona, $base';
    return base;
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
      zona: d['zona'] ?? '',
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
      tiempoAcordado: d['tiempoAcordado'] ?? '',
      fechaAcuerdo: d['fechaAcuerdo'] != null
          ? (d['fechaAcuerdo'] as Timestamp).toDate() : null,
      fechaInicio: d['fechaInicio'] != null
          ? (d['fechaInicio'] as Timestamp).toDate() : null,
      pagoRetenido: d['pagoRetenido'] ?? false,
      entregado: d['entregado'] ?? false,
      pagoLiberado: d['pagoLiberado'] ?? false,
      correccionSolicitada: d['correccionSolicitada'] ?? false,
      motivoCorreccion: d['motivoCorreccion'] ?? '',
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
    'zona': zona,
    'presupuesto': presupuesto,
    'plazo': plazo,
    'fechaCreacion': Timestamp.fromDate(fechaCreacion),
    'estado': estado,
    'uidTrabajadorAsignado': uidTrabajadorAsignado,
    'nombreTrabajadorAsignado': nombreTrabajadorAsignado,
    'calificadoPorEmpleador': calificadoPorEmpleador,
    'calificadoPorTrabajador': calificadoPorTrabajador,
    'montoAcordado': montoAcordado,
    'tiempoAcordado': tiempoAcordado,
    if (fechaAcuerdo != null) 'fechaAcuerdo': Timestamp.fromDate(fechaAcuerdo!),
    if (fechaInicio != null) 'fechaInicio': Timestamp.fromDate(fechaInicio!),
    'pagoRetenido': pagoRetenido,
    'entregado': entregado,
    'pagoLiberado': pagoLiberado,
    'correccionSolicitada': correccionSolicitada,
    'motivoCorreccion': motivoCorreccion,
  };

  // ── API propia (backend Spring Boot) ────────────────────────
  // Corresponde a `TrabajoResponse`. Cambios de nombre respecto a Firestore:
  //   empleadorId               → uidEmpleador
  //   autorNombre               → autor
  //   trabajadorAsignadoId      → uidTrabajadorAsignado
  //   trabajadorAsignadoNombre  → nombreTrabajadorAsignado
  //   creadoEn                  → fechaCreacion
  // y `estado` viene como enum en MAYÚSCULAS (`"EN_PROGRESO"`).
  //
  // El backend manda además cuatro campos de disputa que este modelo no tiene
  // (`fechaSolicitudCorreccion`, `disputaAbiertaPorId`, `motivoDisputa`,
  // `resolucionDisputa`, de ADR-0007). Se ignoran a propósito: las pantallas
  // de disputa son fase 3. Ver reporte de la tarea 018.

  factory Publicacion.desdeJson(Map<String, dynamic> json) => Publicacion(
    id: textoJson(json['id']),
    uidEmpleador: textoJson(json['empleadorId']),
    autor: textoJson(json['autorNombre']),
    categoria: textoJson(json['categoria']),
    titulo: textoJson(json['titulo']),
    descripcion: textoJson(json['descripcion']),
    departamento: textoJson(json['departamento']),
    ciudad: textoJson(json['ciudad']),
    zona: textoJson(json['zona']),
    presupuesto: textoJson(json['presupuesto']),
    plazo: textoJson(json['plazo']),
    fechaCreacion: fechaJson(json['creadoEn']),
    estado: EstadosTrabajo.desdeApi(json['estado']),
    uidTrabajadorAsignado: textoJson(json['trabajadorAsignadoId']),
    nombreTrabajadorAsignado: textoJson(json['trabajadorAsignadoNombre']),
    calificadoPorEmpleador: boolJson(json['calificadoPorEmpleador']),
    calificadoPorTrabajador: boolJson(json['calificadoPorTrabajador']),
    montoAcordado: decimalJson(json['montoAcordado']),
    tiempoAcordado: textoJson(json['tiempoAcordado']),
    fechaAcuerdo: fechaJsonOpcional(json['fechaAcuerdo']),
    fechaInicio: fechaJsonOpcional(json['fechaInicio']),
    pagoRetenido: boolJson(json['pagoRetenido']),
    entregado: boolJson(json['entregado']),
    pagoLiberado: boolJson(json['pagoLiberado']),
    correccionSolicitada: boolJson(json['correccionSolicitada']),
    motivoCorreccion: textoJson(json['motivoCorreccion']),
  );

  /// Cuerpo de `POST /api/trabajos` (`CrearTrabajoRequest`).
  ///
  /// Solo van los campos que el backend acepta del cliente: el empleador, el
  /// estado, el escrow y las fechas los pone el servidor ("el cliente nunca
  /// decide permisos" — `backend/README.md`). Mandar `estado` o `pagoRetenido`
  /// desde aquí sería, además de inútil, un intento de saltarse la máquina de
  /// estados de ADR-0007.
  ///
  /// Ojo: `titulo` tiene un máximo de 50 caracteres en el backend
  /// (`@Size(max = 50)`); si se pasa, responde 400 con `fields.titulo`.
  Map<String, dynamic> aJson() => {
    'titulo': titulo,
    'descripcion': descripcion,
    'categoria': categoria,
    'departamento': departamento,
    'ciudad': ciudad,
    'zona': zona,
    'presupuesto': presupuesto,
    'plazo': plazo,
  };
}
