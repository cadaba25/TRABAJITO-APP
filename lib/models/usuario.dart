import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constantes.dart';

/// Modelo de experiencia laboral
class Experiencia {
  final String empresa;
  final String puesto;
  final String habilidades;
  final String descripcion;
  final String fechaInicio;
  final String fechaFin;      // vacío si trabaja actualmente
  final bool trabajaActualmente;

  const Experiencia({
    required this.empresa,
    required this.puesto,
    this.habilidades = '',
    this.descripcion = '',
    required this.fechaInicio,
    this.fechaFin = '',
    this.trabajaActualmente = false,
  });

  Map<String, dynamic> aMap() => {
    'empresa': empresa,
    'puesto': puesto,
    'habilidades': habilidades,
    'descripcion': descripcion,
    'fechaInicio': fechaInicio,
    'fechaFin': fechaFin,
    'trabajaActualmente': trabajaActualmente,
  };

  factory Experiencia.desdeMap(Map<String, dynamic> m) => Experiencia(
    empresa: m['empresa'] ?? '',
    puesto: m['puesto'] ?? '',
    habilidades: m['habilidades'] ?? '',
    descripcion: m['descripcion'] ?? '',
    fechaInicio: m['fechaInicio'] ?? '',
    fechaFin: m['fechaFin'] ?? '',
    trabajaActualmente: m['trabajaActualmente'] ?? false,
  );
}

/// Modelo de estudio
class Estudio {
  final String nivel;
  final String centro;
  final String fechaInicio;
  final String fechaFin;       // vacío si está cursando
  final bool cursandoActualmente;

  const Estudio({
    required this.nivel,
    required this.centro,
    required this.fechaInicio,
    this.fechaFin = '',
    this.cursandoActualmente = false,
  });

  Map<String, dynamic> aMap() => {
    'nivel': nivel,
    'centro': centro,
    'fechaInicio': fechaInicio,
    'fechaFin': fechaFin,
    'cursandoActualmente': cursandoActualmente,
  };

  factory Estudio.desdeMap(Map<String, dynamic> m) => Estudio(
    nivel: m['nivel'] ?? '',
    centro: m['centro'] ?? '',
    fechaInicio: m['fechaInicio'] ?? '',
    fechaFin: m['fechaFin'] ?? '',
    cursandoActualmente: m['cursandoActualmente'] ?? false,
  );
}

/// Modelo principal de usuario Trabajito
class Usuario {
  final String uid;
  final String tipoUsuario;       // 'trabajador' | 'empleador'
  final String nombres;           // uno o varios nombres
  final String apellidos;         // uno o varios apellidos
  final String dni;               // documento de identidad (13 dígitos)
  // Campos heredados (compatibilidad con usuarios antiguos)
  final String primerNombre;
  final String segundoNombre;
  final String primerApellido;
  final String segundoApellido;
  final String correo;
  final String telefono;
  final String telefonoEmergencia;
  final String fechaNacimiento;
  final String genero;
  final bool viveEnHonduras;
  final String departamento;
  final String ciudad;
  final String codigoPostal;
  final String pais;
  final String urlCV;
  final List<Experiencia> experiencia;
  final List<Estudio> estudios;
  final DateTime fechaRegistro;
  final String rol;
  final String fotoPerfil;
  final String estado;
  final bool registroCompleto;
  final int trabajosCompletados;  // para el ranking semanal
  final double calificacionPromedio;
  final int totalCalificaciones;

  // ── CAMPOS DE EMPLEADOR ─────────────────────────────────────
  final String tipoEmpleador;       // 'persona' | 'empresa'
  final String nombreEmpresa;       // razón social (solo empresa)
  final String rtn;                 // Registro Tributario Nacional (solo empresa)
  final String cargoContacto;       // puesto del contacto dentro de la empresa
  final String sectorEmpresa;       // sector / rubro
  final String tamanoEmpresa;       // cantidad de empleados
  final String sitioWeb;            // sitio web (opcional)
  final String descripcionEmpresa;  // descripción / qué buscan

  const Usuario({
    required this.uid,
    required this.tipoUsuario,
    this.nombres = '',
    this.apellidos = '',
    this.dni = '',
    this.primerNombre = '',
    this.segundoNombre = '',
    this.primerApellido = '',
    this.segundoApellido = '',
    required this.correo,
    this.telefono = '',
    this.telefonoEmergencia = '',
    this.fechaNacimiento = '',
    this.genero = '',
    this.viveEnHonduras = true,
    this.departamento = '',
    this.ciudad = '',
    this.codigoPostal = '',
    this.pais = 'Honduras',
    this.urlCV = '',
    this.experiencia = const [],
    this.estudios = const [],
    required this.fechaRegistro,
    required this.rol,
    this.fotoPerfil = '',
    this.estado = 'activo',
    this.registroCompleto = false,
    this.trabajosCompletados = 0,
    this.calificacionPromedio = 0,
    this.totalCalificaciones = 0,
    this.tipoEmpleador = '',
    this.nombreEmpresa = '',
    this.rtn = '',
    this.cargoContacto = '',
    this.sectorEmpresa = '',
    this.tamanoEmpresa = '',
    this.sitioWeb = '',
    this.descripcionEmpresa = '',
  });

  /// Indica si el usuario es un empleador
  bool get esEmpleador => tipoUsuario == 'empleador';

  /// Nombres efectivos (usa los nuevos campos o los heredados).
  String get _nombresEfectivo => nombres.isNotEmpty
      ? nombres
      : [primerNombre, segundoNombre].where((s) => s.isNotEmpty).join(' ');

  String get _apellidosEfectivo => apellidos.isNotEmpty
      ? apellidos
      : [primerApellido, segundoApellido].where((s) => s.isNotEmpty).join(' ');

  /// Nombre completo (todos los nombres y apellidos).
  String get nombreCompleto =>
      '$_nombresEfectivo $_apellidosEfectivo'.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Solo primer nombre + primer apellido (para vistas compactas).
  String get nombreCorto {
    final n = _nombresEfectivo.split(RegExp(r'\s+')).firstWhere(
        (e) => e.isNotEmpty, orElse: () => '');
    final a = _apellidosEfectivo.split(RegExp(r'\s+')).firstWhere(
        (e) => e.isNotEmpty, orElse: () => '');
    return [n, a].where((s) => s.isNotEmpty).join(' ');
  }

  /// Nombre principal a mostrar: la empresa cuando aplique, si no el nombre corto.
  String get nombreVisible =>
      (esEmpleador && tipoEmpleador == 'empresa' && nombreEmpresa.isNotEmpty)
          ? nombreEmpresa
          : nombreCorto;

  /// Iniciales para avatar
  String get iniciales {
    if (esEmpleador && tipoEmpleador == 'empresa' && nombreEmpresa.isNotEmpty) {
      final palabras = nombreEmpresa.trim().split(RegExp(r'\s+'));
      final a = palabras.isNotEmpty && palabras[0].isNotEmpty ? palabras[0][0] : '';
      final b = palabras.length > 1 && palabras[1].isNotEmpty ? palabras[1][0] : '';
      return '$a$b'.toUpperCase();
    }
    final partes = nombreCorto.split(RegExp(r'\s+'));
    final p = partes.isNotEmpty && partes[0].isNotEmpty ? partes[0][0].toUpperCase() : '';
    final a = partes.length > 1 && partes[1].isNotEmpty ? partes[1][0].toUpperCase() : '';
    return '$p$a';
  }

  factory Usuario.desdeFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Usuario(
      uid: d['uid'] ?? '',
      tipoUsuario: d['tipoUsuario'] ?? 'trabajador',
      nombres: d['nombres'] ?? '',
      apellidos: d['apellidos'] ?? '',
      dni: d['dni'] ?? '',
      primerNombre: d['primerNombre'] ?? '',
      segundoNombre: d['segundoNombre'] ?? '',
      primerApellido: d['primerApellido'] ?? '',
      segundoApellido: d['segundoApellido'] ?? '',
      correo: d['correo'] ?? '',
      telefono: d['telefono'] ?? '',
      telefonoEmergencia: d['telefonoEmergencia'] ?? '',
      fechaNacimiento: d['fechaNacimiento'] ?? '',
      genero: d['genero'] ?? '',
      viveEnHonduras: d['viveEnHonduras'] ?? true,
      departamento: d['departamento'] ?? '',
      ciudad: d['ciudad'] ?? '',
      codigoPostal: d['codigoPostal'] ?? '',
      pais: d['pais'] ?? 'Honduras',
      urlCV: d['urlCV'] ?? '',
      experiencia: (d['experiencia'] as List<dynamic>? ?? [])
          .map((e) => Experiencia.desdeMap(e as Map<String, dynamic>))
          .toList(),
      estudios: (d['estudios'] as List<dynamic>? ?? [])
          .map((e) => Estudio.desdeMap(e as Map<String, dynamic>))
          .toList(),
      fechaRegistro: d['fechaRegistro'] != null
          ? (d['fechaRegistro'] as Timestamp).toDate()
          : DateTime.now(),
      rol: d['rol'] ?? 'trabajador',
      fotoPerfil: d['fotoPerfil'] ?? '',
      estado: d['estado'] ?? 'activo',
      registroCompleto: d['registroCompleto'] ?? false,
      trabajosCompletados: (d['trabajosCompletados'] ?? 0) as int,
      calificacionPromedio: ((d['calificacionPromedio'] ?? 0) as num).toDouble(),
      totalCalificaciones: (d['totalCalificaciones'] ?? 0) as int,
      tipoEmpleador: d['tipoEmpleador'] ?? '',
      nombreEmpresa: d['nombreEmpresa'] ?? '',
      rtn: d['rtn'] ?? '',
      cargoContacto: d['cargoContacto'] ?? '',
      sectorEmpresa: d['sectorEmpresa'] ?? '',
      tamanoEmpresa: d['tamanoEmpresa'] ?? '',
      sitioWeb: d['sitioWeb'] ?? '',
      descripcionEmpresa: d['descripcionEmpresa'] ?? '',
    );
  }

  Map<String, dynamic> aFirestore() => {
    'uid': uid,
    'tipoUsuario': tipoUsuario,
    'nombres': nombres,
    'apellidos': apellidos,
    'dni': dni,
    'primerNombre': primerNombre,
    'segundoNombre': segundoNombre,
    'primerApellido': primerApellido,
    'segundoApellido': segundoApellido,
    'correo': correo,
    'telefono': telefono,
    'telefonoEmergencia': telefonoEmergencia,
    'fechaNacimiento': fechaNacimiento,
    'genero': genero,
    'viveEnHonduras': viveEnHonduras,
    'departamento': departamento,
    'ciudad': ciudad,
    'codigoPostal': codigoPostal,
    'pais': pais,
    'urlCV': urlCV,
    'experiencia': experiencia.map((e) => e.aMap()).toList(),
    'estudios': estudios.map((e) => e.aMap()).toList(),
    'fechaRegistro': Timestamp.fromDate(fechaRegistro),
    'rol': rol,
    'fotoPerfil': fotoPerfil,
    'estado': estado,
    'registroCompleto': registroCompleto,
    'trabajosCompletados': trabajosCompletados,
    'calificacionPromedio': calificacionPromedio,
    'totalCalificaciones': totalCalificaciones,
    'tipoEmpleador': tipoEmpleador,
    'nombreEmpresa': nombreEmpresa,
    'rtn': rtn,
    'cargoContacto': cargoContacto,
    'sectorEmpresa': sectorEmpresa,
    'tamanoEmpresa': tamanoEmpresa,
    'sitioWeb': sitioWeb,
    'descripcionEmpresa': descripcionEmpresa,
  };
}
