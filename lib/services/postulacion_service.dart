import 'package:flutter/foundation.dart';

import '../models/postulacion.dart';
import '../utils/constantes.dart';
import 'api/api_client.dart';
import 'api/api_excepciones.dart';
import 'api/configuracion_api.dart';

/// Postulaciones a trabajos, **contra el backend propio**
/// (`/api/postulaciones/**`). Migrado desde Firestore en la tarea 026.
///
/// ## Lo que cambia respecto a la versión con Firestore
///
/// | Antes (Firestore) | Ahora (backend) |
/// |---|---|
/// | `streamMisPostulaciones(uid)` | [misPostulaciones], sin uid: sale del token |
/// | `streamPostulantes(idPub)` | [postulantesDe] |
/// | `streamMiPostulacion(idPub, uid)` | [miPostulacionEn], que filtra la lista propia |
/// | id determinista `pub_uid` para evitar duplicados | restricción única en la BD → 409 |
/// | asignar al trabajador desde `PublicacionService` | [aceptar], que además **crea el chat** |
///
/// Los tres `Stream` desaparecieron: carga puntual + "deslizar para
/// actualizar", como en el resto de la fase 2.
///
/// ## Dos avisos de contrato que condicionan la interfaz
///
/// - **Postularse al propio trabajo responde 409** (decisión del dueño, tarea
///   019). No es un fallo del cliente: con el doble perfil de la tarea 012 una
///   misma cuenta podrá publicar y postularse, y el único sitio donde eso se
///   puede impedir de verdad es el servidor.
/// - **La postulación que devuelve el backend no trae el título del trabajo ni
///   el id del empleador.** En Firestore iban desnormalizados dentro del
///   documento para poder pintar la lista de una sola lectura; la entidad de
///   Postgres no los tiene. Quien necesite el título tiene que pedir el
///   trabajo aparte — ver `MisPostulacionesScreen`.
class PostulacionService {
  PostulacionService({ApiClient? cliente})
      : _api = cliente ?? ApiClient.instancia;

  final ApiClient _api;

  // ── Lectura ─────────────────────────────────────────────────

  /// Postulaciones propias del trabajador, de la más nueva a la más vieja (lo
  /// ordena el servidor). Incluye las retiradas y las rechazadas: son parte de
  /// su historial.
  Future<List<Postulacion>> misPostulaciones() =>
      _lista(RutasApi.misPostulaciones);

  /// Postulantes de un trabajo. **Solo el dueño del trabajo**; a cualquier
  /// otro el servidor le responde 403.
  ///
  /// Se filtran las retiradas, como hacía la versión de Firestore: al
  /// contratista no le sirve de nada ver a quien se echó atrás. El backend las
  /// devuelve todas.
  Future<List<Postulacion>> postulantesDe(String idPublicacion) async {
    final lista = await _lista(
      RutasApi.postulaciones,
      consulta: {'trabajoId': idPublicacion},
    );
    return lista
        .where((p) => p.estado != EstadosPostulacion.retirada)
        .toList()
      ..sort((a, b) => b.fechaPostulacion.compareTo(a.fechaPostulacion));
  }

  /// La postulación propia a [idPublicacion], o `null` si no hay ninguna.
  ///
  /// Sustituye a `streamMiPostulacion(...)`. El backend no tiene un endpoint
  /// de "mi postulación a este trabajo", así que se filtra sobre la lista
  /// propia; es una sola petición y esa lista es corta por naturaleza.
  ///
  /// Devuelve también las retiradas: quien llama decide si eso cuenta como
  /// "ya te postulaste" (no cuenta, y el backend tampoco deja volver a
  /// postularse — la restricción única no distingue el estado).
  Future<Postulacion?> miPostulacionEn(String idPublicacion) async {
    for (final p in await misPostulaciones()) {
      if (p.idPublicacion == idPublicacion) return p;
    }
    return null;
  }

  /// Ids de los trabajos a los que ya se postuló, para marcar las tarjetas del
  /// feed sin una petición por tarjeta.
  ///
  /// Cuenta también las **retiradas**: la restricción única de la BD
  /// (`uq_postulacion_trabajo_trabajador`) no mira el estado, así que un
  /// segundo intento responde 409 igual. Enseñar el botón como disponible
  /// sería mentir.
  Future<Set<String>> idsDeTrabajosPostulados() async {
    return {for (final p in await misPostulaciones()) p.idPublicacion};
  }

  // ── Escritura ───────────────────────────────────────────────

  /// El trabajador se postula. `null` si fue bien.
  ///
  /// Del modelo solo viajan `trabajoId` y `mensaje` (`Postulacion.aJson`); el
  /// trabajador y su nombre los pone el servidor desde el token.
  ///
  /// Errores que la pantalla verá tal cual, con el texto del backend:
  /// "Ya te postulaste a este trabajo" y "No puedes postularte a tu propio
  /// trabajo" (los dos 409).
  Future<String?> postular(Postulacion p) {
    return _intentar(() async {
      await _api.crear(RutasApi.postulaciones, cuerpo: p.aJson());
      return null;
    });
  }

  /// El trabajador retira su postulación (queda como retirada, no se borra).
  ///
  /// Es `DELETE` y responde sin cuerpo. **No permite volver a postularse**: la
  /// restricción única sigue viendo la fila.
  Future<String?> retirar(String id) {
    return _intentar(() async {
      await _api.eliminar(RutasApi.postulacion(id));
      return null;
    });
  }

  /// El contratista elige a este postulante.
  ///
  /// Sustituye a `PublicacionService.asignarTrabajador(...)`, que en Firestore
  /// era una transacción a mano en el cliente. Ahora lo hace el servidor en
  /// una sola transacción: asigna el trabajo, deja esta postulación aceptada,
  /// **rechaza todas las demás** y **crea el chat** entre las dos partes.
  ///
  /// Si el trabajo ya no está activo responde 409 ("Este trabajo ya no está
  /// disponible para asignar"), que es lo que protege de dos contratistas
  /// eligiendo a la vez.
  Future<String?> aceptar(String idPostulacion) {
    return _intentar(() async {
      await _api.crear(RutasApi.aceptarPostulacion(idPostulacion),
          cuerpo: const <String, dynamic>{});
      return null;
    });
  }

  // ── Interno ─────────────────────────────────────────────────

  Future<List<Postulacion>> _lista(
    String ruta, {
    Map<String, Object?>? consulta,
  }) async {
    final json = await _api.obtener(ruta, consulta: consulta);
    if (json is! List) {
      throw RespuestaIlegible(
          detalle: 'Se esperaba una lista de postulaciones en $ruta');
    }
    return [
      for (final e in json)
        if (e is Map) Postulacion.desdeJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// `null` si fue bien, o un texto en español listo para enseñar. Mismo
  /// envoltorio que el resto de servicios migrados.
  Future<String?> _intentar(Future<String?> Function() operacion) async {
    try {
      return await operacion();
    } on ExcepcionApi catch (e) {
      if (e.campos.isNotEmpty) return e.campos.values.first;
      return e.mensaje;
    } catch (e) {
      debugPrint('Fallo inesperado en PostulacionService: $e');
      return MensajesError.errorGeneral;
    }
  }
}
