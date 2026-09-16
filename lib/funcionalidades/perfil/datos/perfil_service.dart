import 'package:flutter/foundation.dart';

import '../../../compartido/modelos/usuario.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../nucleo/api/api_client.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../../nucleo/api/configuracion_api.dart';
import '../../../nucleo/sesion/sesion_usuario.dart';

/// Perfil y directorio de personas **contra el backend propio**
/// (`/api/usuarios/**` y `GET /api/auth/yo`).
///
/// Sale de `AuthService` en la tarea 027 (parte B-2, ADR-0014): aquel archivo
/// tenía dos razones para cambiar —la sesión y el perfil/usuarios— y `perfil`
/// ya es una funcionalidad propia. Aquí vive lo segundo:
///
/// - recargar y editar el perfil propio,
/// - el CV del trabajador (habilidades, experiencia, estudios),
/// - el perfil público de otra persona,
/// - el listado de trabajadores para las pestañas "Trabajadores" y "Ranking".
///
/// **No toca el almacén de sesión.** Comparte con `AuthService` el mismo
/// `ApiClient.instancia` y el mismo `sesionActual`, pero solo escribe el
/// perfil en memoria (`SesionUsuario.actualizarPerfil`). El guardado de la
/// sesión en el dispositivo (login, registro, restaurar) sigue siendo de
/// `AuthService`.
///
/// Los métodos devuelven `String?` como en `AuthService`: `null` = todo bien,
/// un texto = mensaje ya en español para el usuario. Cuando además importa
/// **qué campo** falló, está [ultimoErrorPorCampo].
class PerfilService {
  PerfilService({ApiClient? cliente, SesionUsuario? sesion})
      : _api = cliente ?? ApiClient.instancia,
        _sesion = sesion ?? sesionActual;

  final ApiClient _api;
  final SesionUsuario _sesion;

  /// Errores por campo del último fallo (`{'nombres': '...'}`), para marcar el
  /// campo dentro del formulario en vez de soltar solo un `SnackBar`.
  /// Se vacía al empezar cada operación.
  Map<String, String> ultimoErrorPorCampo = const {};

  /// Id del usuario en el backend (UUID). Cadena vacía si no hay sesión.
  String get uidActual => _sesion.uid;

  // ── Perfil propio ───────────────────────────────────────────

  /// Vuelve a pedir el perfil propio completo y lo publica en la sesión.
  /// Es lo que sustituye a `streamUsuarioActual()`: en vez de un documento en
  /// vivo, una recarga cuando hace falta (arranque, tras editar, al deslizar
  /// para actualizar).
  Future<String?> recargarPerfil() {
    return _intentar(() async {
      _sesion.actualizarPerfil(await _pedirPerfilPropio());
      return null;
    });
  }

  /// Edita el perfil propio (`PUT /api/usuarios/me`) y publica en la sesión el
  /// perfil que responde el servidor.
  ///
  /// [campos] son los del formulario, con los mismos nombres que usaba la
  /// versión de Firestore. Se mandan **solo los que se pasan**: para el
  /// backend, un campo ausente significa "no lo toques", así que esta llamada
  /// nunca pisa nada que no se le haya dado.
  ///
  /// **Las habilidades no se mandan por aquí** aunque el backend las acepte en
  /// este cuerpo: van por [reemplazarHabilidades], que obliga a pasar la lista
  /// a conciencia. Ver la explicación en `Usuario.cvCargado`.
  Future<String?> actualizarCampos(Map<String, dynamic> campos) {
    return _intentar(() async {
      final cuerpo = _cuerpoDePerfil(campos);
      if (cuerpo.isEmpty) return null;
      final json = await _api.reemplazar(RutasApi.miPerfil, cuerpo: cuerpo);
      // La respuesta de `PUT /me` ya trae el perfil completo con CV, así que
      // no hace falta un `GET` detrás.
      _sesion.actualizarPerfil(Usuario.desdeJson(ApiClient.comoObjeto(json)));
      return null;
    });
  }

  /// Perfil **público** de otra persona. No trae correo, DNI, teléfonos,
  /// fecha de nacimiento ni saldo: el backend los oculta por privacidad
  /// (ADR-0011). Sí trae el CV, que es lo que la pantalla de un trabajador
  /// necesita enseñar.
  Future<Usuario?> obtenerUsuarioPorUid(String uid) async {
    if (uid.isEmpty) return null;
    if (uid == uidActual) return obtenerUsuarioActual();
    try {
      final json = await _api.obtenerObjeto(RutasApi.perfilDe(uid));
      return Usuario.desdeJson(json);
    } on ExcepcionApi catch (e) {
      debugPrint('No se pudo cargar el perfil $uid: $e');
      return null;
    }
  }

  /// Perfil propio. Devuelve el que ya está en memoria si lo hay, y si no lo
  /// pide al servidor.
  Future<Usuario?> obtenerUsuarioActual() async {
    final enMemoria = _sesion.usuario;
    if (enMemoria != null && enMemoria.cvCargado) return enMemoria;
    if (!_api.haySesion) return null;
    try {
      final usuario = await _pedirPerfilPropio();
      _sesion.actualizarPerfil(usuario);
      return usuario;
    } on ExcepcionApi catch (e) {
      debugPrint('No se pudo cargar el perfil propio: $e');
      return enMemoria;
    }
  }

  // ── CV del trabajador (sub-recursos propios) ────────────────

  /// Reemplaza la lista completa de habilidades.
  ///
  /// Es un reemplazo, no un "añade una": el formulario las maneja como un
  /// conjunto y manda el conjunto entero. Justamente por eso hay que llamarlo
  /// con la lista de verdad: pasar `[]` **borra** las habilidades.
  Future<String?> reemplazarHabilidades(List<String> habilidades) {
    return _intentar(() async {
      await _api.reemplazar(RutasApi.misHabilidades,
          cuerpo: {'habilidades': habilidades});
      return null;
    });
  }

  /// Añade un puesto al historial laboral (`POST`, crea uno nuevo).
  Future<String?> agregarExperiencia(Experiencia experiencia) {
    return _intentar(() async {
      await _api.crear(RutasApi.miExperiencia, cuerpo: experiencia.aJson());
      return null;
    });
  }

  /// Añade un estudio (`POST`, crea uno nuevo).
  Future<String?> agregarEstudio(Estudio estudio) {
    return _intentar(() async {
      await _api.crear(RutasApi.misEstudios, cuerpo: estudio.aJson());
      return null;
    });
  }

  // ── Listados de personas ────────────────────────────────────

  /// Trabajadores para las pestañas "Trabajadores" y "Ranking".
  ///
  /// Antes era `streamTrabajadores()`, un stream de Firestore con **todos**
  /// los usuarios de rol trabajador. El backend expone hoy una sola lista de
  /// personas, `GET /api/usuarios/ranking`: los **50 trabajadores activos con
  /// más trabajos completados**. Dos diferencias que hay que tener presentes:
  ///
  /// - Está topada en 50 y ordenada por trabajos completados. Para la pestaña
  ///   de ranking es exactamente lo que hace falta; para la de trabajadores es
  ///   un recorte, y hará falta un endpoint de búsqueda/paginación propio
  ///   cuando haya más de 50 (anotado como pendiente en el reporte 020).
  /// - Es la vista **pública**: los elementos llegan sin CV
  ///   (`habilidades`/`experiencia`/`estudios` a `null`), así que la tarjeta
  ///   de cada trabajador no puede enseñar su especialidad sin abrir el
  ///   perfil. No es un fallo de parseo: es lo que manda el servidor.
  Future<List<Usuario>> listarTrabajadores() async {
    final json = await _api.obtener(RutasApi.ranking);
    if (json is! List) {
      throw const RespuestaIlegible(
          detalle: 'Se esperaba una lista de usuarios en /api/usuarios/ranking');
    }
    return [
      for (final e in json)
        if (e is Map<String, dynamic>) Usuario.desdeJson(e),
    ];
  }

  // ── Interno ─────────────────────────────────────────────────

  /// `GET /api/auth/yo` — la única lectura que trae el **perfil completo**
  /// del dueño: datos personales, saldo y las tres listas del CV.
  Future<Usuario> _pedirPerfilPropio() async =>
      Usuario.desdeJson(await _api.obtenerObjeto(RutasApi.yo));

  /// Filtra el mapa del formulario dejando solo lo que
  /// `ActualizarPerfilRequest` acepta.
  ///
  /// Sin este filtro, un campo que el backend no conoce viajaría igualmente y
  /// —al haber `@Valid` y deserialización estricta— podría convertir un
  /// guardado normal en un 400 incomprensible. También deja fuera
  /// `habilidades` a propósito (ver [actualizarCampos]).
  static Map<String, dynamic> _cuerpoDePerfil(Map<String, dynamic> campos) {
    const admitidos = {
      'nombres', 'apellidos', 'telefono', 'telefonoEmergencia',
      'fechaNacimiento', 'genero', 'presentacion', 'urlCV', 'departamento',
      'ciudad', 'codigoPostal', 'pais', 'viveEnHonduras', 'fotoUrl',
      'registroCompleto', 'tipoEmpleador', 'nombreEmpresa', 'rtn',
      'cargoContacto', 'sectorEmpresa', 'tamanoEmpresa', 'sitioWeb',
      'descripcionEmpresa',
    };
    final cuerpo = <String, dynamic>{};
    campos.forEach((clave, valor) {
      // `fotoPerfil` es como se llama en el modelo de la app; el backend lo
      // llama `fotoUrl`. Es la única traducción de nombre del perfil.
      final nombre = clave == 'fotoPerfil' ? 'fotoUrl' : clave;
      if (valor != null && admitidos.contains(nombre)) cuerpo[nombre] = valor;
    });
    return cuerpo;
  }

  /// Envoltorio común: ejecuta la operación y traduce cualquier fallo del
  /// backend a un texto en español, guardando de paso los errores por campo.
  Future<String?> _intentar(Future<String?> Function() operacion) async {
    ultimoErrorPorCampo = const {};
    try {
      return await operacion();
    } on DemasiadosIntentos catch (e) {
      final espera = e.esperaLegible;
      return espera == null
          ? e.mensaje
          : '${e.mensaje} Vuelve a intentarlo en $espera.';
    } on ExcepcionApi catch (e) {
      ultimoErrorPorCampo = e.campos;
      if (e.campos.isNotEmpty) return e.campos.values.first;
      return e.mensaje;
    } catch (e) {
      debugPrint('Fallo inesperado en PerfilService: $e');
      return MensajesError.errorGeneral;
    }
  }
}
