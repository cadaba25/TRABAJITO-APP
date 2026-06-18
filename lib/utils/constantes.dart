import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// COLORES
// ─────────────────────────────────────────────────────────────
class AppColores {
  static const Color azulOscuro   = Color(0xFF0F172A);
  static const Color azul         = Color(0xFF2563EB);
  static const Color azulClaro    = Color(0xFF3B82F6);
  static const Color blanco       = Color(0xFFFFFFFF);
  static const Color grisClaro    = Color(0xFFF1F5F9);
  static const Color grisMedio    = Color(0xFF94A3B8);
  static const Color grisTexto    = Color(0xFF64748B);
  static const Color error        = Color(0xFFEF4444);
  static const Color exito        = Color(0xFF22C55E);
  static const Color fondo        = Color(0xFFF8FAFC);
  static const Color advertencia  = Color(0xFFF59E0B);
}

// ─────────────────────────────────────────────────────────────
// TEXTOS
// ─────────────────────────────────────────────────────────────
class AppTextos {
  static const String nombreApp       = 'Trabajito';
  static const String tagline         = 'Conectando talento con oportunidades';
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
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE
// ─────────────────────────────────────────────────────────────
class FirestoreColecciones {
  static const String usuarios = 'usuarios';
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

// ─────────────────────────────────────────────────────────────
// MENSAJES
// ─────────────────────────────────────────────────────────────
class MensajesError {
  static const String correoEnUso         = 'Este correo ya está registrado.';
  static const String contrasenaIncorrecta= 'Contraseña incorrecta.';
  static const String usuarioNoEncontrado = 'No existe una cuenta con este correo.';
  static const String errorConexion       = 'Error de conexión. Verifica tu internet.';
  static const String errorGeneral        = 'Ocurrió un error. Intenta de nuevo.';
  static const String cuentaCreada        = '¡Cuenta creada! Ya puedes iniciar sesión.';
  static const String campoObligatorio    = 'Este campo es obligatorio';
  static const String menorEdad           = 'Debes ser mayor de 18 años para registrarte';
  static const String correoInvalido      = 'Ingresa un correo válido';
  static const String contrasenaMuyCorta  = 'Mínimo 6 caracteres';
  static const String contrasenasNoCoinc  = 'Las contraseñas no coinciden';
  static const String telefonoInvalido    = 'Ingresa un número válido (mínimo 8 dígitos)';
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
}

// ─────────────────────────────────────────────────────────────
// TEMA
// ─────────────────────────────────────────────────────────────
class AppTema {
  static ThemeData obtenerTema() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColores.azul,
        brightness: Brightness.light,
        primary: AppColores.azul,
        onPrimary: AppColores.blanco,
        surface: AppColores.blanco,
        error: AppColores.error,
      ),
      scaffoldBackgroundColor: AppColores.fondo,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.azul,
          foregroundColor: AppColores.blanco,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColores.azul,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColores.azul, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColores.blanco,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColores.grisClaro, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColores.grisClaro, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColores.azul, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColores.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColores.error, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColores.grisTexto),
        hintStyle: const TextStyle(color: AppColores.grisMedio),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColores.azulOscuro,
        foregroundColor: AppColores.blanco,
        elevation: 0,
        centerTitle: true,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColores.azul;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
