import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../compartido/modelos/usuario.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../nucleo/api/api_client.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../../nucleo/api/configuracion_api.dart';
import '../../../nucleo/api/sesion_api.dart';
import '../../../nucleo/sesion/sesion_usuario.dart';

/// Autenticación y cuenta **contra el backend propio** (`/api/auth/**`), no
/// contra Firebase: login, registro, restaurar la sesión al arrancar, cierre
/// de sesión y baja de cuenta.
///
/// Es el primer servicio que se migra (tarea 020, fase 2a de ADR-0009) porque
/// todo lo demás necesita el token. Los otros servicios siguen hablando con
/// Firestore mientras les llega su turno.
///
/// **El perfil y el directorio de personas ya no viven aquí.** Desde la tarea
/// 027 (parte B-2, ADR-0014) están en `PerfilService`
/// (`funcionalidades/perfil/datos/perfil_service.dart`): recargar/editar el
/// perfil propio, el CV del trabajador, el perfil público ajeno y
/// `listarTrabajadores`. Ambos comparten `ApiClient.instancia` y
/// `sesionActual`; solo `AuthService` escribe el almacén de sesión del
/// dispositivo.
///
/// ## Lo que cambia respecto a la versión con Firebase
///
/// | Antes (Firebase) | Ahora (backend) |
/// |---|---|
/// | `authStateChanges()` | [estadoSesion], un `ValueListenable` en memoria |
/// | `streamUsuarioActual()` | `PerfilService.recargarPerfil` + [estadoSesion] |
/// | `streamTrabajadores()` | `PerfilService.listarTrabajadores`, carga puntual |
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

  /// Hace que la app vuelva al login cuando la sesión muere sola.
  ///
  /// Sin esto, un refresh token caducado o revocado deja al usuario dentro de
  /// una pantalla donde ya no carga nada y cada acción da un error de sesión:
  /// el cliente HTTP se entera, pero la interfaz no. Firebase no tenía este
  /// problema porque `authStateChanges()` avisaba solo.
  ///
  /// Se llama una vez al arrancar. La suscripción vive lo que vive la app, así
  /// que no hace falta cancelarla.
  StreamSubscription<EventoSesion> escucharFinDeSesion() {
    return _api.eventosSesion.listen((evento) {
      if (evento == EventoSesion.terminada) _sesion.salir();
    });
  }

  /// Instala la regla de ADR-0013 en el cliente HTTP: **sin sesión confirmada
  /// no se ejecuta ninguna acción que cree o modifique datos**.
  ///
  /// Se llama una vez al arrancar, junto a [escucharFinDeSesion]. A partir de
  /// ahí, cualquier `POST`/`PUT`/`PATCH`/`DELETE` autenticado de cualquier
  /// pantalla pasa por aquí sin que la pantalla tenga que saberlo.
  ///
  /// Lo que hace en cada escritura:
  ///
  /// 1. Si la sesión ya está confirmada (el caso normal), deja pasar sin
  ///    gastar nada.
  /// 2. Si viene marcada como "datos de la última visita"
  ///    (`EstadoSesion.avisoSinConexion`, tarea 023), **intenta confirmarla**
  ///    con `GET /api/auth/yo`. Si lo consigue, el aviso desaparece de toda la
  ///    app y la acción sigue adelante: al usuario le vuelve la conexión y la
  ///    app se cura sola, sin tener que buscar dónde deslizar para actualizar.
  /// 3. Si no lo consigue, devuelve `false` y `ApiClient` lanza
  ///    [SinConexionConfirmada]. La petición **no sale**.
  ///
  /// Nunca lanza: un fallo aquí significaría bloquear al usuario con un error
  /// que ninguna pantalla sabe traducir.
  void vigilarEscriturasSinConexion() {
    _api.exigirSesionConfirmada(() async {
      if (!_sesion.value.avisoSinConexion) return true;
      if (!_api.haySesion) return true; // login/registro: no es una escritura de datos
      try {
        _sesion.actualizarPerfil(await _pedirPerfilPropio());
        return true;
      } on ExcepcionApi catch (e) {
        debugPrint('Escritura bloqueada, sesión sin confirmar: $e');
        return false;
      } catch (e) {
        debugPrint('Escritura bloqueada, fallo al confirmar la sesión: $e');
        return false;
      }
    });
  }

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

  // ── Perfil y usuarios ───────────────────────────────────────
  //
  // Se movió a `PerfilService`
  // (`funcionalidades/perfil/datos/perfil_service.dart`) en la tarea 027
  // parte B-2: recargar/editar el perfil propio, el CV del trabajador, el
  // perfil público ajeno y el listado de trabajadores. `AuthService` se
  // queda con la sesión y la cuenta.

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
