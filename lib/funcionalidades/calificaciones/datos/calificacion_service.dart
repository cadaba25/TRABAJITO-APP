import 'package:flutter/foundation.dart';

import '../../../compartido/modelos/calificacion.dart';
import '../../../nucleo/api/api_client.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../../nucleo/api/configuracion_api.dart';
import '../../../nucleo/textos/mensajes_error.dart';

/// Calificaciones **contra el backend propio** (`/api/calificaciones`).
/// Migrado desde Firestore en la tarea 052.
///
/// La transacción del cliente (promedio, banderas de la publicación, paso a
/// `FINALIZADO`) desapareció: la hace el servidor. El receptor y el rol
/// calificado también los deduce él del trabajo, no del cliente.
class CalificacionService {
  CalificacionService({ApiClient? cliente})
      : _api = cliente ?? ApiClient.instancia;

  final ApiClient _api;

  /// Califica al otro participante de [idTrabajo]. `null` si fue bien.
  /// El 409 llega con el texto del servidor ("Ya calificaste este trabajo",
  /// "El trabajo aún no está completado").
  Future<String?> calificar({
    required String idTrabajo,
    required int estrellas,
    String comentario = '',
  }) async {
    try {
      await _api.crear(RutasApi.calificaciones, cuerpo: {
        'trabajoId': idTrabajo,
        'estrellas': estrellas,
        'comentario': comentario,
      });
      return null;
    } on ExcepcionApi catch (e) {
      if (e.campos.isNotEmpty) return e.campos.values.first;
      return e.mensaje;
    } catch (e) {
      debugPrint('Fallo inesperado en CalificacionService: $e');
      return MensajesError.errorGeneral;
    }
  }

  /// Reseñas recibidas por [uid], de la más nueva a la más vieja; [rol]
  /// (`TRABAJADOR`/`EMPLEADOR`) filtra por papel. Lanza [ExcepcionApi] si
  /// falla: quien llama decide qué enseñar.
  Future<List<Calificacion>> listarDe(String uid, {String? rol}) async {
    final json = await _api.obtener(
      RutasApi.calificacionesDe(uid),
      consulta: rol == null ? null : {'rol': rol},
    );
    if (json is! List) {
      throw const RespuestaIlegible(
          detalle: 'Se esperaba una lista de calificaciones');
    }
    return [
      for (final e in json)
        if (e is Map) Calificacion.desdeJson(Map<String, dynamic>.from(e)),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }
}
