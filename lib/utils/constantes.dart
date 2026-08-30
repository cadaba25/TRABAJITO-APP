import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// COLORES — Manual de marca Trabajito V1.0
// ─────────────────────────────────────────────────────────────
class AppColores {
  // Paleta de marca
  static const Color principal      = Color(0xFF0D1B2A); // Azul Marino
  static const Color azulProfesional= Color(0xFF1565C0); // Azul Profesional
  static const Color dorado         = Color(0xFFFFC107); // Amarillo Dorado (acento héroe)
  static const Color verde          = Color(0xFF20C997); // Verde Moderno
  static const Color grisLienzo     = Color(0xFFF1F3F6); // Gris Claro
  static const Color texto          = Color(0xFF0D1B2A); // Texto (marino)

  // Alias retrocompatibles (usados en todo el código existente)
  static const Color azulOscuro  = principal;            // #0D1B2A
  static const Color secundario  = principal;
  static const Color azul        = azulProfesional;      // #1565C0
  static const Color azulClaro   = Color(0xFF1E88E5);
  static const Color acento      = dorado;               // #FFC107
  static const Color blanco      = Color(0xFFFFFFFF);
  static const Color grisClaro   = Color(0xFFE3E7EC);
  static const Color grisMedio   = Color(0xFF8A93A2);
  static const Color grisTexto   = Color(0xFF5B6675);
  static const Color error       = Color(0xFFEF4444);
  static const Color exito       = verde;                // #20C997
  static const Color fondo       = grisLienzo;           // #F1F3F6
  static const Color advertencia = dorado;

  // Superficies para modo oscuro
  static const Color fondoOscuro      = Color(0xFF0A1622);
  static const Color superficieOscura = Color(0xFF14273A);
  static const Color bordeOscuro      = Color(0xFF24384F);
  static const Color textoOscuro      = Color(0xFFE7ECF2);
}

/// Notificador global del modo de tema (false = claro, true = oscuro).
final ValueNotifier<bool> notificadorTema = ValueNotifier<bool>(false);

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

// ─────────────────────────────────────────────────────────────
// FIRESTORE
// ─────────────────────────────────────────────────────────────
class FirestoreColecciones {
  static const String usuarios = 'usuarios';
  static const String publicaciones = 'publicaciones';
  static const String postulaciones = 'postulaciones';
  static const String calificaciones = 'calificaciones';
  static const String chats = 'chats';
  static const String mensajes = 'mensajes';
  static const String tarjetas = 'tarjetas';   // subcolección de usuarios
  static const String evidencias = 'evidencias'; // subcolección de publicaciones
}

/// Estados del ciclo de vida de una publicación de trabajo.
class EstadosTrabajo {
  static const String activo         = 'activo';         // publicado
  static const String asignado       = 'asignado';       // en negociación (chat)
  static const String acordado       = 'acordado';       // contrato, pendiente de iniciar
  static const String enProgreso     = 'en_progreso';    // trabajo iniciado
  static const String esperandoConfirmacion = 'esperando_confirmacion';
  static const String completado     = 'completado';     // aceptado, pago liberado
  static const String finalizado     = 'finalizado';     // ambos calificaron (archivado)
  static const String cerrado        = 'cerrado';
  // Los dos siguientes existen en el backend (enum EstadoTrabajo) y no tenían
  // constante aquí porque el flujo de Firestore nunca los produjo. Se añaden
  // para que `desdeApi` no devuelva un literal suelto (tarea 018).
  static const String enDisputa      = 'en_disputa';     // reclamo a soporte, escrow congelado
  static const String cancelado      = 'cancelado';      // cancelado antes de iniciar

  /// Etiqueta legible del estado.
  static String etiqueta(String e) {
    switch (e) {
      case activo:                return 'Publicado';
      case asignado:              return 'En negociación';
      case acordado:              return 'Pendiente de iniciar';
      case enProgreso:            return 'En progreso';
      case esperandoConfirmacion: return 'Esperando confirmación';
      case enDisputa:             return 'En disputa';
      case completado:            return 'Completado';
      case finalizado:            return 'Finalizado';
      case cancelado:             return 'Cancelado';
      default:                    return 'Cerrado';
    }
  }

  /// Todos los estados conocidos, en orden del ciclo de vida.
  static const List<String> todos = [
    activo, asignado, acordado, enProgreso, esperandoConfirmacion,
    enDisputa, completado, finalizado, cerrado, cancelado,
  ];

  /// Traduce el enum del backend (`"EN_PROGRESO"`) al valor de la app
  /// (`'en_progreso'`). Un estado desconocido cae en [cerrado] en vez de
  /// colarse tal cual por la UI.
  static String desdeApi(Object? valor) =>
      MapeoEnumApi.desdeApi(valor, todos, siNoSeConoce: cerrado);

  /// Inverso de [desdeApi]: `'en_progreso'` → `"EN_PROGRESO"`.
  static String aApi(String estado) => MapeoEnumApi.aApi(estado);
}

/// Estados de una postulación.
class EstadosPostulacion {
  static const String pendiente = 'pendiente';
  static const String aceptada  = 'aceptada';
  static const String rechazada = 'rechazada';
  static const String retirada  = 'retirada';

  static const List<String> todos = [pendiente, aceptada, rechazada, retirada];

  /// `"PENDIENTE"` (backend) → `'pendiente'` (app).
  static String desdeApi(Object? valor) =>
      MapeoEnumApi.desdeApi(valor, todos, siNoSeConoce: pendiente);

  static String aApi(String estado) => MapeoEnumApi.aApi(estado);
}

/// Tipos de mensaje de chat.
///
/// El backend tiene más (`IMAGEN`, `ARCHIVO`, `PROPUESTA_PAGO`,
/// `PROPUESTA_TIEMPO`); la app solo distingue mensaje normal de mensaje del
/// sistema, así que todo lo que no sea `TEXTO` se trata como [sistema].
class TiposMensaje {
  static const String texto   = 'texto';
  static const String sistema = 'sistema';

  static String desdeApi(Object? valor) =>
      MapeoEnumApi.desdeApi(valor, const [texto], siNoSeConoce: sistema);

  static String aApi(String tipo) => MapeoEnumApi.aApi(tipo);
}

/// Conversión entre los enums del backend (`MAYUSCULAS_CON_GUION_BAJO`) y los
/// valores en minúscula que usa la app.
///
/// Está aquí, junto a las constantes, para que ningún servicio ni modelo
/// escriba `"EN_PROGRESO"` a mano.
class MapeoEnumApi {
  /// Pasa el valor del backend a minúsculas y comprueba que sea uno de los
  /// [conocidos]. Si no lo es (el backend añadió un estado que la app no
  /// entiende), devuelve [siNoSeConoce] en vez de propagar un valor que
  /// ninguna pantalla sabe pintar.
  static String desdeApi(
    Object? valor,
    List<String> conocidos, {
    required String siNoSeConoce,
  }) {
    if (valor is! String || valor.isEmpty) return siNoSeConoce;
    final normalizado = valor.trim().toLowerCase();
    return conocidos.contains(normalizado) ? normalizado : siNoSeConoce;
  }

  /// `'en_progreso'` → `"EN_PROGRESO"`.
  static String aApi(String valor) => valor.trim().toUpperCase();
}

/// Roles tal y como los nombra el backend (enum `Rol`).
///
/// La app los guarda en minúscula (`'trabajador'`, `'empleador'`) desde
/// Firestore; el backend los manda en mayúscula. `ADMIN` no tiene pantallas en
/// la app (el panel de administración es solo de la API), pero se conserva
/// como `'admin'` en vez de convertirlo en otro rol: rebajarlo a empleador
/// sería inventarle permisos que no le tocan.
class RolesApi {
  static const String admin = 'admin';

  static const List<String> todos = [
    ValoresDefecto.rolTrabajador,
    ValoresDefecto.rolEmpleador,
    admin,
  ];

  /// `"TRABAJADOR"` → `'trabajador'`. Lo desconocido cae en trabajador, que es
  /// el rol con menos privilegios.
  static String desdeApi(Object? valor) => MapeoEnumApi.desdeApi(
        valor,
        todos,
        siNoSeConoce: ValoresDefecto.rolTrabajador,
      );

  static String aApi(String rol) => MapeoEnumApi.aApi(rol);
}

class CamposUsuario {
  static const String uid           = 'uid';
  static const String primerNombre  = 'primerNombre';
  static const String segundoNombre = 'segundoNombre';
  static const String primerApellido= 'primerApellido';
  static const String segundoApellido='segundoApellido';
  static const String correo        = 'correo';
  static const String telefono      = 'telefono';
  static const String telefonoEmergencia = 'telefonoEmergencia';
  static const String fechaNacimiento = 'fechaNacimiento';
  static const String genero        = 'genero';
  static const String departamento  = 'departamento';
  static const String ciudad        = 'ciudad';
  static const String codigoPostal  = 'codigoPostal';
  static const String pais          = 'pais';
  static const String viveEnHonduras= 'viveEnHonduras';
  static const String urlCV         = 'urlCV';
  static const String experiencia   = 'experiencia';
  static const String estudios      = 'estudios';
  static const String fechaRegistro = 'fechaRegistro';
  static const String rol           = 'rol';
  static const String fotoPerfil    = 'fotoPerfil';
  static const String estado        = 'estado';
  static const String tipoUsuario   = 'tipoUsuario'; // trabajador / empleador
  static const String registroCompleto = 'registroCompleto';
}

class ValoresDefecto {
  static const String rolTrabajador   = 'trabajador';
  static const String rolEmpleador    = 'empleador';
  static const String fotoPerfilVacia = '';
  static const String estadoActivo    = 'activo';
}

/// Reglas que **el servidor impone** y que el formulario debe pedir igual.
///
/// No son preferencias de la app: son las validaciones reales del backend
/// (ADR-0010 para la contraseña, ADR-0011 para la edad). Si el formulario
/// pide menos, el usuario rellena los 5 pasos del registro para que el
/// servidor le responda 400 al final, que es exactamente la experiencia que
/// hay que evitar.
///
/// Verificadas contra el servidor el 2026-08-27 (tarea 020).
class ReglasCuenta {
  /// Mínimo del backend. Firebase pedía 6; el backend propio pide 10.
  static const int contrasenaMinima = 10;

  /// Máximo del backend: BCrypt trunca en 72 bytes, así que aceptar más daría
  /// una falsa sensación de fortaleza.
  static const int contrasenaMaxima = 72;

  /// Edad mínima. Antes solo la comprobaba la pantalla; ahora también el
  /// servidor, que responde 400 si no se cumple.
  static const int edadMinima = 18;
}

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
  static const String telefonoInvalido    = 'Ingresa un número válido (mínimo 8 dígitos)';
  static const String sitioWebInvalido     = 'Ingresa una URL válida (ej. www.empresa.com)';
  static const String dniInvalido          = 'Ingresa un DNI válido (13 dígitos)';
  static const String soloHonduras         = 'Por ahora Trabajito solo está disponible en Honduras. ¡Pronto fuera del país!';
}

// ─────────────────────────────────────────────────────────────
// DATOS DE HONDURAS
// ─────────────────────────────────────────────────────────────
class DatosHonduras {
  static const List<String> departamentos = [
    'Atlántida', 'Choluteca', 'Colón', 'Comayagua', 'Copán',
    'Cortés', 'El Paraíso', 'Francisco Morazán', 'Gracias a Dios',
    'Intibucá', 'Islas de la Bahía', 'La Paz', 'Lempira',
    'Ocotepeque', 'Olancho', 'Santa Bárbara', 'Valle', 'Yoro',
  ];

  static const Map<String, List<String>> ciudadesPorDepartamento = {
    'Atlántida':           ['La Ceiba', 'El Porvenir', 'Esparta', 'Jutiapa', 'La Masica', 'San Francisco', 'Tela', 'Arizona'],
    'Choluteca':           ['Choluteca', 'Apacilagua', 'Concepción de María', 'Duyure', 'El Corpus', 'El Triunfo', 'Marcovia', 'Morolica', 'Namasigüe', 'Orocuina', 'Pespire', 'San Antonio de Flores', 'San Isidro', 'San José', 'San Marcos de Colón', 'Santa Ana de Yusguare'],
    'Colón':               ['Trujillo', 'Balfate', 'Iriona', 'Limón', 'Sabá', 'Santa Fe', 'Santa Rosa de Aguán', 'Sonaguera', 'Tocoa', 'Bonito Oriental'],
    'Comayagua':           ['Comayagua', 'Ajuterique', 'El Rosario', 'Esquías', 'Humuya', 'La Libertad', 'Lamaní', 'La Trinidad', 'Lejamaní', 'Meámbar', 'Minas de Oro', 'Ojos de Agua', 'San Jerónimo', 'San José de Comayagua', 'San José del Potrero', 'San Luis', 'San Sebastián', 'Siguatepeque', 'Trinidad', 'Villa de San Antonio'],
    'Copán':               ['Santa Rosa de Copán', 'Cabañas', 'Concepción', 'Copán Ruinas', 'Corquín', 'Cucuyagua', 'Dolores', 'Dulce Nombre', 'El Paraíso', 'Florida', 'La Jigua', 'La Unión', 'Nueva Arcadia', 'San Agustín', 'San Antonio', 'San Jerónimo', 'San José', 'San Juan de Opoa', 'San Nicolás', 'San Pedro', 'Santa Rita', 'Trinidad de Copán', 'Veracruz'],
    'Cortés':              ['San Pedro Sula', 'Choloma', 'La Lima', 'Omoa', 'Pimienta', 'Potrerillos', 'Puerto Cortés', 'San Antonio de Cortés', 'San Francisco de Yojoa', 'San Manuel', 'Santa Cruz de Yojoa', 'Villanueva', 'El Progreso'],
    'El Paraíso':          ['Yuscarán', 'Alauca', 'Danlí', 'El Paraíso', 'Güinope', 'Jacaleapa', 'Liure', 'Morocelí', 'Oropolí', 'Potrerillos', 'San Antonio de Flores', 'San Lucas', 'San Matías', 'Soledad', 'Teupasenti', 'Texiguat', 'Vado Ancho', 'Yauyupe', 'Trojes'],
    'Francisco Morazán':   ['Tegucigalpa', 'Alubaren', 'Cedros', 'Curarén', 'El Porvenir', 'Güaimaca', 'La Libertad', 'La Venta', 'Lepaterique', 'Maraita', 'Marale', 'Nueva Armenia', 'Ojojona', 'Orica', 'Reitoca', 'Sabanagrande', 'San Antonio de Oriente', 'San Buenaventura', 'San Ignacio', 'San Juan de Flores', 'San Miguelito', 'Santa Ana', 'Santa Lucía', 'Talanga', 'Tatumbla', 'Valle de Ángeles', 'Villa de San Francisco', 'Vallecillo'],
    'Gracias a Dios':      ['Puerto Lempira', 'Brus Laguna', 'Ahuas', 'Juan Francisco Bulnes', 'Villeda Morales', 'Wampusirpe'],
    'Intibucá':            ['La Esperanza', 'Camasca', 'Colomoncagua', 'Concepción', 'Dolores', 'Intibucá', 'Jesús de Otoro', 'Magdalena', 'Masaguara', 'San Antonio', 'San Isidro', 'San Juan', 'San Marcos de la Sierra', 'San Miguelito', 'Santa Lucía', 'Yamaranguila', 'San Francisco de Opalaca'],
    'Islas de la Bahía':   ['Roatán', 'Guanaja', 'José Santos Guardiola', 'Utila'],
    'La Paz':              ['La Paz', 'Aguanqueterique', 'Cabañas', 'Cane', 'Chinacla', 'Guajiquiro', 'Lauterique', 'Marcala', 'Mercedes de Oriente', 'Opatoro', 'San Antonio del Norte', 'San Juan', 'San Pedro de Tutule', 'Santa Ana', 'Santa Elena', 'Santa María', 'Santiago de Puringla', 'Yarula'],
    'Lempira':             ['Gracias', 'Belén', 'Candelaria', 'Cololaca', 'Erandique', 'Gualcince', 'Guarita', 'La Campa', 'La Iguala', 'Las Flores', 'La Unión', 'La Virtud', 'Lepaera', 'Mapulaca', 'Piraera', 'San Andrés', 'San Francisco', 'San Juan Guarita', 'San Manuel Colohete', 'San Rafael', 'San Sebastián', 'Santa Cruz', 'Talgua', 'Tambla', 'Tomalá', 'Valladolid', 'Virginia', 'San Marcos de Caiquín'],
    'Ocotepeque':          ['Ocotepeque', 'Belén Gualcho', 'Concepción', 'Dolores Merendón', 'Fraternidad', 'La Encarnación', 'La Labor', 'Lucerna', 'Mercedes', 'San Fernando', 'San Francisco del Valle', 'San Jorge', 'San Marcos', 'Santa Fe', 'Sensenti', 'Sinuapa'],
    'Olancho':             ['Juticalpa', 'Campamento', 'Catacamas', 'Concordia', 'Dulce Nombre de Culmí', 'El Rosario', 'Esquipulas del Norte', 'Gualaco', 'Guarizama', 'Guata', 'Guayape', 'Jano', 'La Unión', 'Mangulile', 'Manto', 'Salamá', 'San Esteban', 'San Francisco de Becerra', 'San Francisco de la Paz', 'Santa María del Real', 'Silca', 'Yocón', 'Patuca'],
    'Santa Bárbara':       ['Santa Bárbara', 'Arada', 'Atima', 'Azacualpa', 'Ceguaca', 'Chinda', 'Concepción del Norte', 'Concepción del Sur', 'El Níspero', 'Gualala', 'Ilama', 'Macuelizo', 'Naranjito', 'Nuevo Celilac', 'Petoa', 'Protección', 'Quimistán', 'San Francisco de Ojuera', 'San José de Colinas', 'San Luis', 'San Marcos', 'San Nicolás', 'San Pedro Zacapa', 'San Vicente Centenario', 'Santa Rita', 'Trinidad'],
    'Valle':               ['Nacaome', 'Alianza', 'Amapala', 'Aramecina', 'Caridad', 'Goascorán', 'Langue', 'San Francisco de Coray', 'San Lorenzo'],
    'Yoro':                ['Yoro', 'Arenal', 'El Negrito', 'El Progreso', 'Jocón', 'Morazán', 'Olanchito', 'Santa Rita', 'Sulaco', 'Victoria', 'Yorito'],
  };

  static const List<String> generos = [
    'Masculino', 'Femenino', 'Prefiero no decirlo',
  ];

  static const List<String> nivelesEstudio = [
    'Primaria', 'Secundaria', 'Técnico', 'Universidad', 'Maestría', 'Doctorado',
  ];

  /// Habilidades/oficios sugeridos para autocompletar el perfil del trabajador.
  static const List<String> habilidadesSugeridas = [
    // Hogar y limpieza
    'Limpieza', 'Limpieza profunda', 'Lavado de autos', 'Planchado',
    'Cuidado de mascotas', 'Niñera', 'Cuidado de adultos mayores',
    // Construcción y mantenimiento
    'Plomería', 'Electricidad', 'Pintura', 'Albañilería', 'Carpintería',
    'Herrería', 'Soldadura', 'Enderezado y pintura', 'Techos',
    'Instalación de pisos', 'Drywall', 'Impermeabilización',
    // Jardinería y campo
    'Jardinería', 'Poda de árboles', 'Fumigación', 'Agricultura',
    // Mecánica y transporte
    'Mecánica', 'Mecánica de motos', 'Electricidad automotriz',
    'Conducción', 'Mudanzas', 'Mensajería', 'Fletes', 'Mototaxi',
    // Tecnología
    'Reparación de computadoras', 'Reparación de celulares',
    'Instalación de cámaras', 'Redes e internet', 'Soporte técnico',
    'Aire acondicionado', 'Refrigeración',
    'Reparación de electrodomésticos', 'Cerrajería',
    // Belleza y salud
    'Belleza', 'Barbería', 'Maquillaje', 'Uñas', 'Masajes', 'Enfermería',
    // Alimentos y eventos
    'Cocina', 'Repostería', 'Bartender', 'Mesero', 'Catering',
    'Decoración de eventos', 'Fotografía', 'Edición de video', 'DJ',
    // Oficina y creativo
    'Costura', 'Diseño gráfico', 'Community manager', 'Redacción',
    'Contabilidad', 'Tutorías', 'Traducción', 'Atención al cliente',
    'Ventas', 'Marketing digital',
  ];
}

// ─────────────────────────────────────────────────────────────
// DATOS DE EMPLEADOR
// ─────────────────────────────────────────────────────────────
class DatosEmpleador {
  /// Sectores / rubros más comunes para servicios autónomos en Honduras.
  static const List<String> sectores = [
    'Hogar y limpieza',
    'Construcción y remodelación',
    'Plomería',
    'Electricidad',
    'Pintura',
    'Jardinería',
    'Mecánica y automotriz',
    'Tecnología e informática',
    'Diseño y publicidad',
    'Belleza y estética',
    'Salud y cuidados',
    'Educación y tutorías',
    'Eventos y catering',
    'Transporte y mudanzas',
    'Comercio y ventas',
    'Restaurante y alimentos',
    'Administración y oficina',
    'Otro',
  ];

  /// Plazo del trabajo por contratación.
  static const List<String> plazos = [
    'Corto plazo',
    'Medio plazo',
    'Largo plazo',
  ];

  /// Tamaño de la empresa (número de empleados).
  static const List<String> tamanos = [
    'Solo yo (independiente)',
    '2 - 10 empleados',
    '11 - 50 empleados',
    '51 - 200 empleados',
    'Más de 200 empleados',
  ];
}

// ─────────────────────────────────────────────────────────────
// TEMA
// ─────────────────────────────────────────────────────────────
class AppTema {
  static RoundedRectangleBorder get _formaBoton =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  static OutlineInputBorder _borde(Color color, double ancho) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: ancho),
      );

  /// Compatibilidad: por defecto devuelve el tema claro.
  static ThemeData obtenerTema() => temaClaro();

  // ── TEMA CLARO ───────────────────────────────────────────
  static ThemeData temaClaro() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: ThemeData(brightness: Brightness.light).textTheme.apply(fontFamily: 'Sora'),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColores.secundario,
        brightness: Brightness.light,
        primary: AppColores.secundario,
        onPrimary: AppColores.blanco,
        secondary: AppColores.acento,
        onSecondary: AppColores.blanco,
        surface: AppColores.blanco,
        onSurface: AppColores.texto,
        error: AppColores.error,
      ),
      scaffoldBackgroundColor: AppColores.fondo,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.secundario,
          foregroundColor: AppColores.blanco,
          minimumSize: const Size(double.infinity, 52),
          shape: _formaBoton,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColores.secundario,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColores.secundario, width: 1.5),
          shape: _formaBoton,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColores.blanco,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _borde(AppColores.grisClaro, 1.5),
        enabledBorder: _borde(AppColores.grisClaro, 1.5),
        focusedBorder: _borde(AppColores.secundario, 2),
        errorBorder: _borde(AppColores.error, 1.5),
        focusedErrorBorder: _borde(AppColores.error, 2),
        labelStyle: const TextStyle(color: AppColores.grisTexto),
        hintStyle: const TextStyle(color: AppColores.grisMedio),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColores.principal,
        foregroundColor: AppColores.blanco,
        elevation: 0,
        centerTitle: true,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColores.secundario;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  // ── TEMA OSCURO ──────────────────────────────────────────
  static ThemeData temaOscuro() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: ThemeData(brightness: Brightness.dark).textTheme.apply(fontFamily: 'Sora'),
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColores.acento,
        onPrimary: AppColores.blanco,
        secondary: AppColores.acento,
        onSecondary: AppColores.blanco,
        surface: AppColores.superficieOscura,
        onSurface: AppColores.textoOscuro,
        error: AppColores.error,
        onError: AppColores.blanco,
      ),
      scaffoldBackgroundColor: AppColores.fondoOscuro,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.acento,
          foregroundColor: AppColores.blanco,
          minimumSize: const Size(double.infinity, 52),
          shape: _formaBoton,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColores.textoOscuro,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColores.bordeOscuro, width: 1.5),
          shape: _formaBoton,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColores.superficieOscura,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _borde(AppColores.bordeOscuro, 1.5),
        enabledBorder: _borde(AppColores.bordeOscuro, 1.5),
        focusedBorder: _borde(AppColores.acento, 2),
        errorBorder: _borde(AppColores.error, 1.5),
        focusedErrorBorder: _borde(AppColores.error, 2),
        labelStyle: const TextStyle(color: AppColores.grisMedio),
        hintStyle: const TextStyle(color: AppColores.grisMedio),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColores.principal,
        foregroundColor: AppColores.blanco,
        elevation: 0,
        centerTitle: true,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColores.acento;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
