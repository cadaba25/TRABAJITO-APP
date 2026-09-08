// ─────────────────────────────────────────────────────────────
// TEXTOS
// ─────────────────────────────────────────────────────────────
class AppTextos {
  static const String nombreApp       = 'Trabajito';
  static const String tagline         = 'Conecta. Contrata. Resuelve.';
  static const String bienvenido      = 'Bienvenido a Trabajito';
  static const String subtituloLogin  = 'Inicia sesión para continuar';
  static const String correo          = 'Correo electrónico';
  static const String contrasena      = 'Contraseña';
  static const String iniciarSesion   = 'Iniciar sesión';
  static const String crearCuenta     = 'Crear cuenta';
  static const String noTieneCuenta   = '¿No tienes cuenta? ';
  static const String registrate      = 'Regístrate';
  static const String yaTieneCuenta   = '¿Ya tienes cuenta? ';
  static const String inicia          = 'Inicia sesión';
  static const String cerrarSesion    = 'Cerrar sesión';
  static const String saludo          = 'Bienvenido a Trabajito';
  static const String nombreCompleto  = 'Nombre completo';
  static const String telefono        = 'Número de teléfono';
  static const String confirmarContrasena = 'Confirmar contraseña';
  static const String registrarse     = 'Crear mi cuenta';

  // ── Datos que la app enseña sin haberlos podido confirmar (tarea 023) ──
  //
  // Cuando la app arranca sin conexión entra con el perfil que se guardó
  // junto a la sesión. Es la decisión correcta —echar a alguien porque le
  // falló el wifi sería peor—, pero entonces la pantalla tiene que decir que
  // eso es una foto vieja, en vez de enseñarla como si acabara de llegar del
  // servidor. Los textos viven aquí y no sueltos en la pantalla porque los
  // comparten la pestaña Perfil y sus tests.
  static const String datosDeTuUltimaVisita =
      'Sin conexión: estos son los datos de tu última visita.';
  static const String datosSinConfirmarDetalle =
      'Desliza hacia abajo para actualizarlos cuando vuelvas a tener internet.';

  /// El CV (habilidades, experiencia y estudios) no venía en la respuesta que
  /// se está enseñando. **No es lo mismo que no tenerlo**, y decirlo importa:
  /// pintarlo a cero se lee como "la app me borró el currículum". Ver
  /// `Usuario.cvCargado`.
  static const String cvSinCargar = 'No pudimos cargar tu currículum.';
  static const String cvSinCargarDetalle =
      'Tus habilidades, tu experiencia y tus estudios siguen guardados en tu '
      'cuenta: aquí no se ha borrado nada. Vuelve a intentarlo cuando tengas '
      'conexión.';
}
