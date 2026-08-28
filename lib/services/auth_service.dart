import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import '../utils/constantes.dart';
import 'api/api_client.dart';
import 'api/api_excepciones.dart';
import 'api/configuracion_api.dart';
import 'api/sesion_api.dart';
import 'sesion_usuario.dart';

/// Autenticación y perfil **contra el backend propio** (`/api/auth/**` y
/// `/api/usuarios/**`), no contra Firebase.
///
/// Es el primer servicio que se migra (tarea 020, fase 2a de ADR-0009) porque
/// todo lo demás necesita el token. Los otros cinco servicios siguen hablando
/// con Firestore mientras les llega su turno.
///
/// ## Lo que cambia respecto a la versión con Firebase
///
/// | Antes (Firebase) | Ahora (backend) |
/// |---|---|
/// | `authStateChanges()` | [estadoSesion], un `ValueListenable` en memoria |
/// | `streamUsuarioActual()` | [recargarPerfil] + [estadoSesion] |
/// | `streamTrabajadores()` | [listarTrabajadores], carga puntual |
/// | cuenta en Auth + documento en Firestore, en dos pasos | un solo `POST /api/auth/registro` |
/// | `signOut()` local | `POST /api/auth/logout`, que **revoca la sesión en el servidor** |
///
/// ## Los métodos devuelven `String?` como antes
///
/// `null` = todo bien; un texto = mensaje ya en español para enseñar al
/// usuario. Se mantiene esa forma a propósito: es lo que esperan las once
/// pantallas que llaman aquí, y cambiarla a excepciones habría convertido esta
/// tarea en una reescritura de la UI entera. El `message` del backend
/// (ADR-0008) ya viene listo para mostrar, así que casi siempre se pasa tal
/// cual. Cuando además importa saber **qué campo** falló, está
/// [ultimoErrorPorCampo].
class AuthService {
  AuthService({ApiClient? cliente, SesionUsuario? sesion})
      : _api = cliente ?? ApiClient.instancia,
        _sesion = sesion ?? sesionActual;

  final ApiClient _api;
  final SesionUsuario _sesion;

  /// Errores por campo del último fallo (`{'password': '...'}`), para marcar
  /// el campo dentro del formulario en vez de soltar solo un `SnackBar`.
  /// Se vacía al empezar cada operación.
  Map<String, String> ultimoErrorPorCampo = const {};

  // ── Estado de la sesión ─────────────────────────────────────

  /// Lo que antes daba `authStateChanges()`. Las pantallas lo consumen con
  /// `ValueListenableBuilder`.
  ValueListenable<EstadoSesion> get estadoSesion => _sesion;

  Usuario? get usuarioActual => _sesion.usuario;

  /// Id del usuario en el backend (UUID). Cadena vacía si no hay sesión.
  String get uidActual => _sesion.uid;

  bool get haySesion => _sesion.hay;

  /// Avisos de fin de sesión que emite el propio cliente HTTP (refresh token
  /// caducado o revocado). La app los escucha para volver al login sin que el
  /// usuario se quede mirando una pantalla que ya no puede cargar nada.
  Stream<EventoSesion> get eventosSesion => _api.eventosSesion;

  // ── Arranque ────────────────────────────────────────────────

  /// Restaura la sesión guardada en el dispositivo al abrir la app.
  ///
  /// Sustituye a la primera emisión de `authStateChanges()`. Tres desenlaces:
  ///
  /// - No hay nada guardado → `sinSesion`, se enseña el login.
  /// - Hay sesión y el servidor la confirma → `conSesion` con el **perfil
  ///   completo**, que es justo lo que devuelve `GET /api/auth/yo` (con CV
  ///   incluido; el login no lo trae).
  /// - Hay sesión pero no hay conexión → se entra igual con el perfil
  ///   guardado, marcado como sin confirmar. Echar al usuario porque le falló
  ///   el wifi sería peor que enseñarle datos de hace un rato, y este es el
  ///   caso de uso real de la app: gente trabajando en la calle.
  Future<void> restaurarSesion() async {
    _sesion.comprobando();
    try {
      await _api.iniciar();
    } catch (e) {
      // El almacén seguro puede fallar (dispositivo sin Keystore, plugin no
      // disponible en un test). Sin sesión guardada, al login.
      debugPrint('No se pudo leer la sesión guardada: $e');
      _sesion.salir();
      return;
    }

    if (!_api.haySesion) {
      _sesion.salir();
      return;
    }

    try {
      _sesion.entrar(await _pedirPerfilPropio());
    } on SesionInvalida {
      // El refresh token caducó o fue revocado: la sesión ya no vale.
      await _api.cerrarSesion();
      _sesion.salir();
    } on ErrorDeRed {
      final guardado = _usuarioDeLaSesionGuardada();
      if (guardado == null) {
        _sesion.salir();
      } else {
        _sesion.entrar(guardado, perfilSinConfirmar: true);
      }
    } on ExcepcionApi catch (e) {
      debugPrint('No se pudo confirmar la sesión: $e');
      await _api.cerrarSesion();
      _sesion.salir();
    }
  }

  // ── Registro ────────────────────────────────────────────────

  /// Crea la cuenta y **deja la sesión iniciada**.
  ///
  /// En Firebase esto eran dos pasos —crear la cuenta en Auth y luego escribir
  /// el documento en Firestore—, con la ventana desagradable de que el primero
  /// funcionara y el segundo no, dejando una cuenta sin perfil. El backend lo
  /// hace en una sola transacción: o hay cuenta con nombre, apellidos y rol, o
  /// no hay nada.
  ///
  /// Los datos que el registro no admite (fecha de nacimiento, género, CV, los
  /// campos de empresa...) se guardan justo después con [actualizarCampos] y
  /// los métodos de CV, que es lo que hacen los formularios por pasos.
  Future<String?> registrar({
    required Usuario datos,
    required String contrasena,
  }) async {
    return _intentar(() async {
      final json = await _api.crear(
        RutasApi.registro,
        cuerpo: datos.aJsonRegistro(password: contrasena),
        autenticada: false,
      );
      await _guardarSesionDesde(json);
      // El registro NO devuelve el CV (llega `null`), así que el perfil que se
      // publica en la sesión se pide entero. Ver `Usuario.cvCargado`.
      _sesion.entrar(await _pedirPerfilPropio());
      return null;
    });
  }

  // ── Inicio de sesión ────────────────────────────────────────

  Future<String?> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    return _intentar(() async {
      final json = await _api.crear(
        RutasApi.login,
        cuerpo: {'correo': correo.trim(), 'password': contrasena},
        autenticada: false,
        // Hace que un 401 se traduzca como "credenciales incorrectas" y no
        // como "tu sesión expiró", que aquí no tendría ningún sentido.
        esLogin: true,
      );
      await _guardarSesionDesde(json);
      // Igual que en el registro: el login no trae el CV. Pedir el perfil
      // completo cuesta una petición más y evita que la pantalla de edición
      // trabaje con un CV falso vacío.
      _sesion.entrar(await _pedirPerfilPropio());
      return null;
    });
  }

  // ── Cierre de sesión ────────────────────────────────────────

  /// Cierra sesión **de verdad**: revoca el refresh token en el servidor y
  /// borra lo guardado en el dispositivo.
  ///
  /// Si el servidor no contesta, la sesión local se borra igual (lo decide
  /// `ApiClient`): el usuario pidió salir y sale.
  Future<void> cerrarSesion() async {
    await _api.cerrarSesion();
    _sesion.salir();
  }

  // ── Perfil ──────────────────────────────────────────────────

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

  // ── Baja de la cuenta ───────────────────────────────────────

  /// Da de baja la cuenta propia (`DELETE /api/usuarios/me`).
  ///
  /// **No borra nada**: el backend la desactiva (`activo = false`) para no
  /// destruir el historial de trabajos, pagos y calificaciones de las otras
  /// personas implicadas. Después ya no se puede iniciar sesión (verificado
  /// contra el servidor: el login responde 401). La versión con Firebase sí
  /// borraba documentos; el texto de la pantalla se corrigió para no prometer
  /// un borrado que no ocurre.
  Future<String?> darDeBajaCuenta() {
    return _intentar(() async {
      await _api.eliminar(RutasApi.miPerfil);
      await cerrarSesion();
      return null;
    });
  }

  // ── Lo que el backend todavía no sabe hacer ─────────────────

  /// El backend **no tiene** endpoint para restablecer la contraseña (tarea
  /// 017, abierta). Con Firebase esto lo daba hecho `sendPasswordResetEmail`.
  /// Se devuelve un mensaje honesto en vez de fingir que se envió un correo.
  Future<String?> enviarResetPassword(String correo) async =>
      MensajesError.sinRecuperacionContrasena;

  /// Tampoco hay endpoint para cambiar la contraseña estando dentro (tarea
  /// 017). Mismo criterio que arriba.
  Future<String?> cambiarContrasena(String nueva) async =>
      MensajesError.sinCambioContrasena;

  /// El backend no verifica correos hoy: no manda correo alguno y no hay
  /// endpoint. Se dice claro.
  Future<String?> enviarVerificacionCorreo() async =>
      'La verificación de correo estará disponible pronto.';

  /// Con Firebase esto venía del token. El backend no lleva la cuenta de si un
  /// correo está verificado, así que no hay nada que consultar; se responde
  /// `true` para no bloquear ningún flujo con una comprobación que no existe.
  bool get correoVerificado => true;

  // ── Interno ─────────────────────────────────────────────────

  /// `GET /api/auth/yo` — la única lectura que trae el **perfil completo**
  /// del dueño: datos personales, saldo y las tres listas del CV.
  Future<Usuario> _pedirPerfilPropio() async =>
      Usuario.desdeJson(await _api.obtenerObjeto(RutasApi.yo));

  Future<void> _guardarSesionDesde(Object? json) async {
    final cuerpo = ApiClient.comoObjeto(json);
    final SesionApi sesion;
    try {
      sesion = SesionApi.desdeJson(cuerpo);
    } on FormatException catch (e) {
      throw RespuestaIlegible(detalle: 'Respuesta de sesión rara: ${e.message}');
    }
    await _api.guardarSesion(sesion);
  }

  /// El perfil que venía dentro de la sesión guardada en el dispositivo.
  /// Solo se usa cuando no hay conexión para pedir el de verdad.
  Usuario? _usuarioDeLaSesionGuardada() {
    final crudo = _api.usuarioDeLaSesion;
    if (crudo.isEmpty) return null;
    return Usuario.desdeJson(crudo);
  }

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
      // 429 del freno de fuerza bruta (ADR-0010). El backend manda
      // `Retry-After`; decir cuánto falta es la diferencia entre un error que
      // se entiende y uno que parece que la app está rota.
      final espera = e.esperaLegible;
      return espera == null
          ? e.mensaje
          : '${e.mensaje} Vuelve a intentarlo en $espera.';
    } on ExcepcionApi catch (e) {
      ultimoErrorPorCampo = e.campos;
      // Un 400 de validación trae el detalle en `fields` y un `message`
      // genérico ("Datos inválidos"): el detalle es más útil que el resumen.
      if (e.campos.isNotEmpty) return e.campos.values.first;
      return e.mensaje;
    } catch (e) {
      debugPrint('Fallo inesperado en AuthService: $e');
      return MensajesError.errorGeneral;
    }
  }
}
