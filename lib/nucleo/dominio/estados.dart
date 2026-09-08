import 'mapeo_enum_api.dart';

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
