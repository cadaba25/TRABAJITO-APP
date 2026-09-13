import '../dominio/reglas_cuenta.dart';

// ─────────────────────────────────────────────────────────────
// MENSAJES
// ─────────────────────────────────────────────────────────────
class MensajesError {
  static const String correoEnUso         = 'Este correo ya está registrado.';
  static const String contrasenaIncorrecta= 'Contraseña incorrecta.';
  static const String credencialesInvalidas = 'Correo o contraseña incorrectos. Si no tienes cuenta, regístrate.';
  static const String usuarioNoEncontrado = 'No existe una cuenta con este correo. Regístrate para continuar.';
  static const String errorConexion       = 'Error de conexión. Verifica tu internet.';
  static const String errorGeneral        = 'Ocurrió un error. Intenta de nuevo.';
  static const String cuentaCreada        = '¡Cuenta creada! Ya puedes iniciar sesión.';
  static const String campoObligatorio    = 'Este campo es obligatorio';
  static const String menorEdad           = 'Debes ser mayor de 18 años para registrarte';
  static const String correoInvalido      = 'Ingresa un correo válido';
  // El backend exige de 10 a 72 caracteres (ADR-0010). Antes ponía "mínimo 6",
  // que era lo que pedía Firebase: dejarlo así haría que el registro fallara
  // en el servidor después de rellenar todo el formulario.
  static const String contrasenaMuyCorta  =
      'Mínimo ${ReglasCuenta.contrasenaMinima} caracteres';
  static const String contrasenaMuyLarga  =
      'Máximo ${ReglasCuenta.contrasenaMaxima} caracteres';
  static const String contrasenasNoCoinc  = 'Las contraseñas no coinciden';
  /// El backend todavía no tiene endpoint para esto (tarea 017 abierta), así
  /// que la app no puede prometerlo. Se dice claro en vez de fingir que sí.
  static const String sinRecuperacionContrasena =
      'Todavía no podemos restablecer contraseñas desde la app. '
      'Escríbenos a soporte.trabajitoapp@gmail.com y te ayudamos.';
  static const String sinCambioContrasena =
      'El cambio de contraseña estará disponible pronto. '
      'Mientras tanto, escríbenos a soporte.trabajitoapp@gmail.com.';

  /// ADR-0013: sin sesión confirmada no se ejecuta ninguna acción que cree o
  /// modifique datos.
  ///
  /// La segunda frase es la importante y no se debe quitar: con Firestore la
  /// escritura se encolaba y se sincronizaba sola, así que el usuario podía
  /// creer que algo se guardó. Contra HTTP no se guarda nada, y hay que
  /// decirlo con esas palabras.
  static const String sinConexionNoSeEscribe =
      'Sin conexión no podemos publicar ni guardar cambios. '
      'No se ha enviado nada: vuelve a intentarlo cuando tengas internet.';

  /// Tampoco hay borrado de trabajos: el backend solo sabe cerrarlos
  /// (`POST /api/trabajos/{id}/cancelar` con `reabrir: false`).
  static const String sinBorradoDeTrabajo =
      'Los trabajos no se borran: se cierran, para no perder el historial de '
      'quien participó en ellos.';
  static const String telefonoInvalido    = 'Ingresa un número válido (mínimo 8 dígitos)';
  static const String sitioWebInvalido     = 'Ingresa una URL válida (ej. www.empresa.com)';
  static const String dniInvalido          = 'Ingresa un DNI válido (13 dígitos)';
  static const String soloHonduras         = 'Por ahora Trabajito solo está disponible en Honduras. ¡Pronto fuera del país!';
}
