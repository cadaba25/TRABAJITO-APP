import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constantes.dart';
import 'json_utiles.dart';

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

  // El backend NO guarda experiencia laboral hoy (la entidad `Usuario` de
  // Spring no tiene la columna). Estos métodos usan la misma forma que
  // Firestore para que, cuando exista, no haya que reescribirlos. Ver el
  // reporte de la tarea 018 → "Pendientes".
  factory Experiencia.desdeJson(Map<String, dynamic> json) =>
      Experiencia.desdeMap(json);

  Map<String, dynamic> aJson() => aMap();
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

  // Mismo caso que `Experiencia`: el backend todavía no guarda estudios.
  factory Estudio.desdeJson(Map<String, dynamic> json) =>
      Estudio.desdeMap(json);

  Map<String, dynamic> aJson() => aMap();
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
  final String presentacion;        // descripción/presentación del trabajador
  final List<String> habilidades;   // etiquetas de lo que sabe hacer
  final List<Experiencia> experiencia;
  final List<Estudio> estudios;
  final DateTime fechaRegistro;
  final String rol;
  final String fotoPerfil;
  final String estado;
  final bool registroCompleto;
  final int trabajosCompletados;  // para el ranking semanal
  final int trabajosPublicados;   // publicaciones creadas (empleador)
  final int pagosConfirmados;     // trabajos aceptados y pagados (empleador)
  final double calificacionPromedio;
  final int totalCalificaciones;
  final double saldo;             // saldo de la cartera (Lempiras)

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
    this.presentacion = '',
    this.habilidades = const [],
    this.experiencia = const [],
    this.estudios = const [],
    required this.fechaRegistro,
    required this.rol,
    this.fotoPerfil = '',
    this.estado = 'activo',
    this.registroCompleto = false,
    this.trabajosCompletados = 0,
    this.trabajosPublicados = 0,
    this.pagosConfirmados = 0,
    this.calificacionPromedio = 0,
    this.totalCalificaciones = 0,
    this.saldo = 0,
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
      presentacion: d['presentacion'] ?? '',
      habilidades: (d['habilidades'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
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
      trabajosPublicados: (d['trabajosPublicados'] ?? 0) as int,
      pagosConfirmados: (d['pagosConfirmados'] ?? 0) as int,
      calificacionPromedio: ((d['calificacionPromedio'] ?? 0) as num).toDouble(),
      totalCalificaciones: (d['totalCalificaciones'] ?? 0) as int,
      saldo: ((d['saldo'] ?? 0) as num).toDouble(),
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
    'presentacion': presentacion,
    'habilidades': habilidades,
    'experiencia': experiencia.map((e) => e.aMap()).toList(),
    'estudios': estudios.map((e) => e.aMap()).toList(),
    'fechaRegistro': Timestamp.fromDate(fechaRegistro),
    'rol': rol,
    'fotoPerfil': fotoPerfil,
    'estado': estado,
    'registroCompleto': registroCompleto,
    'trabajosCompletados': trabajosCompletados,
    'trabajosPublicados': trabajosPublicados,
    'pagosConfirmados': pagosConfirmados,
    'calificacionPromedio': calificacionPromedio,
    'totalCalificaciones': totalCalificaciones,
    'saldo': saldo,
    'tipoEmpleador': tipoEmpleador,
    'nombreEmpresa': nombreEmpresa,
    'rtn': rtn,
    'cargoContacto': cargoContacto,
    'sectorEmpresa': sectorEmpresa,
    'tamanoEmpresa': tamanoEmpresa,
    'sitioWeb': sitioWeb,
    'descripcionEmpresa': descripcionEmpresa,
  };

  // ── API propia (backend Spring Boot) ────────────────────────
  //
  // Corresponde a `UsuarioResponse` (lo que devuelven `/api/auth/login`,
  // `/api/auth/registro`, `/api/auth/yo`, `/api/usuarios/{id}` y el ranking).
  //
  // Cambios de nombre: `id` → `uid`, `fotoUrl` → `fotoPerfil`.
  // `rol` llega como enum en MAYÚSCULAS y alimenta a la vez `rol` y
  // `tipoUsuario`, que en Firestore eran dos campos distintos.
  //
  // **Campos de este modelo que el backend NO tiene todavía** (se comprobó la
  // entidad `Usuario` de Spring el 2026-08-27, no solo el DTO):
  //   habilidades, experiencia, estudios, telefonoEmergencia, fechaNacimiento,
  //   genero, viveEnHonduras, codigoPostal, pais, urlCV, cargoContacto,
  //   descripcionEmpresa, registroCompleto, fechaRegistro.
  // Y dos que la entidad sí tiene pero `UsuarioResponse` no expone: `rtn` y
  // `activo`.
  //
  // Es la diferencia más grande de toda la migración: el perfil del trabajador
  // (habilidades / experiencia / estudios) es justo lo que llena
  // `registro_trabajador_screen`. Migrar el perfil en la fase 2 exige que el
  // backend crezca esas columnas, o se pierde. Está anotado en el reporte de
  // la tarea 018 como pendiente para `backend-agent`.
  //
  // Al leer, esos campos quedan con su valor por defecto; si el backend los
  // llegara a mandar, se leen sin tocar nada más.

  factory Usuario.desdeJson(Map<String, dynamic> json) {
    final rol = RolesApi.desdeApi(json['rol']);
    // `tipoUsuario` decide qué ve la app (`esEmpleador`). El backend tiene un
    // tercer rol, ADMIN, que en Flutter no tiene pantallas: se le deja la
    // vista de trabajador, la de menos privilegios, en vez de inventarle una.
    final tipoUsuario =
        rol == ValoresDefecto.rolEmpleador ? rol : ValoresDefecto.rolTrabajador;
    final nombres = textoJson(json['nombres']);
    final apellidos = textoJson(json['apellidos']);

    return Usuario(
      uid: textoJson(json['id']),
      tipoUsuario: tipoUsuario,
      nombres: nombres,
      apellidos: apellidos,
      dni: textoJson(json['dni']),
      correo: textoJson(json['correo']),
      telefono: textoJson(json['telefono']),
      telefonoEmergencia: textoJson(json['telefonoEmergencia']),
      fechaNacimiento: textoJson(json['fechaNacimiento']),
      genero: textoJson(json['genero']),
      viveEnHonduras: boolJson(json['viveEnHonduras'], true),
      departamento: textoJson(json['departamento']),
      ciudad: textoJson(json['ciudad']),
      codigoPostal: textoJson(json['codigoPostal']),
      pais: textoJson(json['pais'], 'Honduras'),
      urlCV: textoJson(json['urlCV']),
      presentacion: textoJson(json['presentacion']),
      habilidades: listaTextoJson(json['habilidades']),
      experiencia: listaObjetosJson(json['experiencia'])
          .map(Experiencia.desdeJson)
          .toList(),
      estudios:
          listaObjetosJson(json['estudios']).map(Estudio.desdeJson).toList(),
      // El backend no manda cuándo se registró el usuario en ninguno de sus
      // DTOs. Se usa `creadoEn` por si algún endpoint lo incluye y, si no,
      // la hora actual — igual que hacía `desdeFirestore()` cuando faltaba.
      fechaRegistro: fechaJson(json['creadoEn']),
      rol: rol,
      fotoPerfil: textoJson(json['fotoUrl']),
      // La entidad del backend usa un booleano `activo` que su DTO no expone
      // (una cuenta suspendida no puede ni iniciar sesión, ADR-0008).
      estado: boolJson(json['activo'], true)
          ? ValoresDefecto.estadoActivo
          : 'suspendido',
      // El backend exige nombres y apellidos al registrarse, así que una
      // cuenta suya nunca está "a medias" como podía estarlo una de Firestore.
      // Se respeta el campo si algún día llega; si no, se deduce.
      registroCompleto: json.containsKey('registroCompleto')
          ? boolJson(json['registroCompleto'])
          : nombres.isNotEmpty && apellidos.isNotEmpty,
      trabajosCompletados: enteroJson(json['trabajosCompletados']),
      trabajosPublicados: enteroJson(json['trabajosPublicados']),
      pagosConfirmados: enteroJson(json['pagosConfirmados']),
      calificacionPromedio: decimalJson(json['calificacionPromedio']),
      totalCalificaciones: enteroJson(json['totalCalificaciones']),
      // OJO: en Postgres el saldo es el resultado de un libro de movimientos
      // (`MovimientoCartera`), no un número que el cliente pueda tocar. Aquí
      // es solo de lectura, para pintarlo. Ver `docs/database.md` §2.
      saldo: decimalJson(json['saldo']),
      tipoEmpleador: textoJson(json['tipoEmpleador']),
      nombreEmpresa: textoJson(json['nombreEmpresa']),
      rtn: textoJson(json['rtn']),
      cargoContacto: textoJson(json['cargoContacto']),
      sectorEmpresa: textoJson(json['sectorEmpresa']),
      tamanoEmpresa: textoJson(json['tamanoEmpresa']),
      sitioWeb: textoJson(json['sitioWeb']),
      descripcionEmpresa: textoJson(json['descripcionEmpresa']),
    );
  }

  /// Cuerpo de `PUT /api/usuarios/me` (`ActualizarPerfilRequest`).
  ///
  /// Solo van los 12 campos que el backend deja editar a su dueño. **No** se
  /// mandan `rol`, `saldo`, `correo`, `dni` ni ningún contador de reputación:
  /// el backend los ignora a propósito (ADR-0005/ADR-0008) y mandarlos daría
  /// la falsa impresión de que se pueden cambiar desde la app.
  ///
  /// Justo esos campos son los que hoy cualquiera puede pisar en Firestore
  /// (riesgo abierto de la tarea 004); con el backend dejan de ser escribibles
  /// desde el cliente.
  Map<String, dynamic> aJson() => {
    'nombres': nombres,
    'apellidos': apellidos,
    'telefono': telefono,
    'presentacion': presentacion,
    'departamento': departamento,
    'ciudad': ciudad,
    'fotoUrl': fotoPerfil,
    'tipoEmpleador': tipoEmpleador,
    'nombreEmpresa': nombreEmpresa,
    'sectorEmpresa': sectorEmpresa,
    'tamanoEmpresa': tamanoEmpresa,
    'sitioWeb': sitioWeb,
  };

  /// Cuerpo de `POST /api/auth/registro` (`RegistroRequest`).
  ///
  /// `rol` va como `RolPublico`: el backend solo acepta `TRABAJADOR` o
  /// `EMPLEADOR` y responde 400 ante cualquier otra cosa, incluido `ADMIN`
  /// (ADR-0005, tarea 008). Se manda [tipoUsuario], que es lo que elige el
  /// usuario en el registro.
  ///
  /// La contraseña no vive en el modelo (no se guarda nunca en memoria más de
  /// lo imprescindible), así que se pasa aquí. Debe tener entre 10 y 72
  /// caracteres y no estar en la lista de bloqueo del backend (ADR-0010); si
  /// no, la respuesta es 400 con `fields.password` y el motivo en español.
  Map<String, dynamic> aJsonRegistro({required String password}) => {
    'correo': correo.trim(),
    'password': password,
    'nombres': nombres,
    'apellidos': apellidos,
    'dni': dni,
    'telefono': telefono,
    'rol': RolesApi.aApi(tipoUsuario),
    'departamento': departamento,
    'ciudad': ciudad,
  };
}
