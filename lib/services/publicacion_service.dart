import 'package:flutter/foundation.dart';

import '../models/evidencia.dart';
import '../models/publicacion.dart';
import '../utils/constantes.dart';
import 'api/api_client.dart';
import 'api/api_excepciones.dart';
import 'api/configuracion_api.dart';
import 'api/pagina_api.dart';

/// Trabajos publicados, **contra el backend propio** (`/api/trabajos/**`).
///
/// Migrado desde Firestore en la tarea 026 (fase 2b de ADR-0009). Junto con
/// `PostulacionService` es el corazón del recorrido que se enseña: publicar →
/// verlo en el feed → recibir postulaciones → elegir a alguien → trabajar,
/// pagar y cerrar.
///
/// ## Lo que cambia respecto a la versión con Firestore
///
/// | Antes (Firestore) | Ahora (backend) |
/// |---|---|
/// | `streamPublicaciones()` | [listarFeed], paginado, + "deslizar para actualizar" |
/// | `streamMisPublicaciones(uid)` | [misPublicaciones], sin uid: sale del token |
/// | `streamPublicacion(id)` | [obtenerPublicacion] |
/// | `streamEvidencias(id)` | [listarEvidencias] |
/// | transacciones de Firestore para el escrow | una llamada por transición; **el servidor decide** |
/// | `asignarTrabajador(...)` | `PostulacionService.aceptar(...)` (asigna, rechaza al resto y **crea el chat**) |
///
/// **Los seis `Stream` desaparecieron.** Es la decisión del `tech-lead` para
/// la fase 2 (ver tarea 018 y el reporte de la 020): carga puntual +
/// `RefreshIndicator`, nunca sondeo. El tiempo real se reserva para el chat.
///
/// ## Lo que el backend NO sabe hacer (verificado el 2026-09-04)
///
/// - **No hay `PUT`/`PATCH` de un trabajo**: una publicación no se puede
///   editar. Ver [actualizarPublicacion].
/// - **No hay `DELETE`**: no se borra, se cierra. Ver [eliminarPublicacion] y
///   [cerrarPublicacion].
/// - **Un trabajo cerrado no se reabre.** `cancelar` con `reabrir: true` solo
///   sirve para deshacer una contratación, no para resucitar un cancelado.
///
/// ## Reglas de negocio que el cliente no puede saltarse
///
/// Todas viven en el servidor (ADR-0007) y aquí solo se disparan. Las que más
/// afectan a la interfaz:
///
/// - **Entregar exige al menos una evidencia** del trabajador, y si el
///   contratista pidió correcciones, una evidencia **nueva**, posterior a esa
///   petición. Por eso [marcarTerminado] puede responder un 409 con un texto
///   que la pantalla enseña tal cual.
/// - **Desde `en_progreso` ya nadie cancela.** La única salida es
///   [reclamarProblema], que congela el escrow hasta que soporte resuelva.
/// - **Cancelar exige elegir** entre reabrir al feed o cerrar: ver
///   [cancelarContratacion].
class PublicacionService {
  PublicacionService({ApiClient? cliente})
      : _api = cliente ?? ApiClient.instancia;

  final ApiClient _api;

  /// Tamaño de página del feed. El backend usa 20 por defecto; se fija aquí
  /// para que la pantalla sepa cuántos pide y no dependa de un defecto ajeno.
  static const int tamanoPagina = 20;

  /// Mensaje del último fallo, para los métodos que devuelven un modelo en vez
  /// de un `String?`.
  String? ultimoError;

  // ── Lectura ─────────────────────────────────────────────────

  /// Página del feed de trabajos **activos**, el más reciente primero.
  ///
  /// Sustituye a `streamPublicaciones({limite})`. Dos diferencias que la
  /// pantalla tiene que tener en cuenta:
  ///
  /// - El backend **solo devuelve los activos** (`TrabajoService.feed`), así
  ///   que no hay que filtrar por estado en el cliente.
  /// - Se pagina de verdad: en vez de subir un `limite` y volver a pedirlo
  ///   todo, se piden páginas y se van sumando. [PaginaApi.hayMas] dice si
  ///   queda alguna.
  ///
  /// **Ojo con los nombres de los parámetros**: este endpoint los llama
  /// `pagina` y `tamano`, no `page`/`size`. Mandar los de Spring Data no da
  /// error: se ignoran en silencio y devuelven siempre la página 0 de tamaño
  /// 20 — que es mucho peor que un fallo, porque el scroll infinito repetiría
  /// los mismos veinte trabajos para siempre. Por eso no se usan los
  /// parámetros por defecto de `ApiClient.obtenerPagina`.
  Future<PaginaApi<Publicacion>> listarFeed({
    int pagina = 0,
    int tamano = tamanoPagina,
  }) {
    return _api.obtenerPagina<Publicacion>(
      RutasApi.trabajos,
      Publicacion.desdeJson,
      consulta: {'pagina': pagina, 'tamano': tamano},
    );
  }

  /// Trabajos publicados por quien tiene la sesión abierta, del más nuevo al
  /// más viejo. No lleva uid: el backend lo saca del token.
  ///
  /// No pagina (devuelve un array pelado), así que aquí no hay páginas que
  /// recorrer. Si un empleador llega a tener cientos habrá que paginarlo en el
  /// servidor; hoy no lo hace.
  Future<List<Publicacion>> misPublicaciones() =>
      _listaDeTrabajos(RutasApi.misTrabajos);

  /// Trabajos en los que quien pide es el **trabajador asignado**.
  ///
  /// En Firestore no existía: la app llegaba a ellos a través de las
  /// postulaciones aceptadas. Se expone porque es la lectura que de verdad
  /// contesta "¿qué tengo que hacer hoy?" para un trabajador.
  Future<List<Publicacion>> misTrabajosAsignados() =>
      _listaDeTrabajos(RutasApi.trabajosAsignados);

  /// Un trabajo por su id. Devuelve `null` si ya no existe o si no se pudo
  /// leer, igual que hacía la versión de Firestore.
  Future<Publicacion?> obtenerPublicacion(String id) async {
    if (id.isEmpty) return null;
    try {
      return await recargarPublicacion(id);
    } on ExcepcionApi catch (e) {
      debugPrint('No se pudo cargar el trabajo $id: $e');
      return null;
    }
  }

  /// Igual que [obtenerPublicacion] pero **propagando el error**, para que la
  /// pantalla pueda distinguir "ya no existe" de "no hay conexión" y enseñar
  /// el mensaje correcto en vez de un vacío ambiguo.
  ///
  /// Sustituye a `streamPublicacion(id)`: el detalle pide el trabajo al
  /// abrirse y lo vuelve a pedir después de cada acción, que es cuando de
  /// verdad puede haber cambiado.
  Future<Publicacion> recargarPublicacion(String id) async =>
      Publicacion.desdeJson(await _api.obtenerObjeto(RutasApi.trabajo(id)));

  /// Avances/evidencias del trabajo, del más antiguo al más nuevo (lo ordena
  /// el servidor). Solo las ven las dos partes; a un tercero le responde 403.
  Future<List<Evidencia>> listarEvidencias(String idPublicacion) async {
    final json = await _api.obtener(RutasApi.evidenciasDe(idPublicacion));
    if (json is! List) {
      throw const RespuestaIlegible(
          detalle: 'Se esperaba una lista de evidencias');
    }
    return [
      for (final e in json)
        if (e is Map) Evidencia.desdeJson(Map<String, dynamic>.from(e)),
    ];
  }

  // ── Publicar ────────────────────────────────────────────────

  /// Publica un trabajo. `null` si todo fue bien.
  ///
  /// Del modelo solo viaja lo que el backend acepta (`Publicacion.aJson`): el
  /// empleador, el estado y las fechas los pone el servidor. Recordatorio del
  /// contrato: **el título no puede pasar de 50 caracteres** o responde 400
  /// con `fields.titulo` (el formulario ya lo limita).
  Future<String?> crearPublicacion(Publicacion publicacion) {
    return _intentar(() async {
      await _api.crear(RutasApi.trabajos, cuerpo: publicacion.aJson());
      return null;
    });
  }

  /// Publica y devuelve el trabajo que creó el servidor —con su id y su fecha
  /// de verdad—, o `null` si falló; en ese caso el motivo queda en
  /// [ultimoError].
  ///
  /// Existe porque tras publicar conviene poder abrir el detalle del trabajo
  /// recién creado sin gastar una segunda lectura.
  Future<Publicacion?> crearYDevolver(Publicacion publicacion) async {
    Publicacion? creada;
    ultimoError = await _intentar(() async {
      final json =
          await _api.crear(RutasApi.trabajos, cuerpo: publicacion.aJson());
      creada = Publicacion.desdeJson(ApiClient.comoObjeto(json));
      return null;
    });
    return creada;
  }

  /// **No se puede editar un trabajo ya publicado.** El backend no expone
  /// `PUT` ni `PATCH` sobre `/api/trabajos/{id}` (comprobado el 2026-09-04).
  ///
  /// Con Firestore la app sí podía: escribía los campos directamente en el
  /// documento. Es una pérdida real de funcionalidad frente a lo que había, y
  /// se dice en vez de fingir que se guardó — mismo criterio que con el cambio
  /// de contraseña en la fase 2a. Anotado como pendiente en el reporte 026.
  ///
  /// Los parámetros se conservan para no romper a quien llama, pero no se usa
  /// ninguno: no hay dónde mandarlos.
  Future<String?> actualizarPublicacion(
    String id,
    Map<String, dynamic> campos,
  ) async =>
      MensajesError.sinEdicionDeTrabajo;

  /// **Un trabajo no se borra.** El backend no expone `DELETE`, y es
  /// coherente: de un trabajo cuelgan postulaciones, un chat, evidencias y a
  /// veces dinero. Lo que sí se puede es cerrarlo, con [cerrarPublicacion].
  Future<String?> eliminarPublicacion(String id) async =>
      MensajesError.sinBorradoDeTrabajo;

  /// Cierra la publicación para que deje de recibir postulaciones
  /// (`POST /{id}/cancelar` con `reabrir: false`; el trabajo queda cancelado).
  ///
  /// El servidor deja además todas las postulaciones vivas como rechazadas,
  /// que es justo lo que la versión de Firestore no hacía.
  ///
  /// **No tiene vuelta atrás**: no existe forma de reabrir un trabajo cerrado.
  /// Y solo funciona antes de que el trabajo inicie; después responde 409 con
  /// la explicación.
  Future<String?> cerrarPublicacion(String id) =>
      _transicion(RutasApi.cancelarTrabajo(id), cuerpo: {'reabrir': false});

  // ── Evidencias / avances ────────────────────────────────────

  /// Añade un avance. Solo puede hacerlo el trabajador asignado y solo con el
  /// trabajo en progreso; en otro caso el servidor responde 403 o 409.
  ///
  /// No es un adorno: **sin al menos una evidencia no se puede entregar**
  /// (ADR-0007). Ver [marcarTerminado].
  Future<String?> agregarEvidencia(String idPublicacion, Evidencia e) {
    return _intentar(() async {
      await _api.crear(RutasApi.evidenciasDe(idPublicacion), cuerpo: e.aJson());
      return null;
    });
  }

  // ── Transiciones del trabajo (las valida el servidor) ───────

  /// El contratista confirma el acuerdo y deposita el pago en garantía.
  ///
  /// El dinero sale de su saldo dentro de la misma transacción que crea el
  /// contrato, con bloqueo pesimista (ADR-0006): sin saldo suficiente responde
  /// 400 y no se crea nada. El `uidEmpleador` que pedía la versión de
  /// Firestore ya no hace falta —sale del token— y se conserva en la firma
  /// solo por no tocar la pantalla que llama.
  Future<String?> reservarPago({
    required String idPublicacion,
    required String uidEmpleador,
    required double monto,
    required String tiempo,
  }) {
    return _transicion(
      RutasApi.reservarPago(idPublicacion),
      cuerpo: {'monto': monto, 'tiempo': tiempo},
    );
  }

  /// El trabajador inicia el trabajo (`acordado` → `en_progreso`).
  Future<String?> iniciarTrabajo(String idPublicacion) =>
      _transicion(RutasApi.iniciarTrabajo(idPublicacion));

  /// El trabajador entrega (`en_progreso` → `esperando_confirmacion`).
  ///
  /// **Exige al menos una evidencia suya** (ADR-0007) y, si el contratista
  /// pidió correcciones, una evidencia posterior a esa petición. Si falta,
  /// responde 409 explicando qué hacer, y ese texto se enseña tal cual.
  Future<String?> marcarTerminado(String idPublicacion) =>
      _transicion(RutasApi.terminarTrabajo(idPublicacion));

  /// El contratista pide correcciones: el trabajo vuelve a `en_progreso` y se
  /// marca el corte a partir del cual hace falta una evidencia nueva.
  Future<String?> solicitarCorreccion(String idPublicacion, String motivo) =>
      _transicion(RutasApi.solicitarCorreccion(idPublicacion),
          cuerpo: {'motivo': motivo});

  /// El contratista acepta la entrega y se libera el pago al trabajador.
  Future<String?> aceptarTrabajo(String idPublicacion) =>
      _transicion(RutasApi.aceptarTrabajo(idPublicacion));

  /// El contratista deshace la contratación, **solo antes de que el trabajo
  /// inicie**. Si había pago en garantía, se le reembolsa entero.
  ///
  /// [reabrir] no tiene valor por defecto a propósito, ni aquí ni en el
  /// backend: es una elección del empleador y omitirla responde 400.
  ///
  /// - `true`  → el trabajo vuelve al feed como activo, el trabajador saliente
  ///   queda rechazado y **los demás candidatos vuelven a pendiente**.
  /// - `false` → el trabajo se cierra como cancelado y todas las postulaciones
  ///   vivas quedan rechazadas.
  Future<String?> cancelarContratacion({
    required String idPublicacion,
    required bool reabrir,
    String motivo = '',
  }) {
    return _transicion(
      RutasApi.cancelarTrabajo(idPublicacion),
      cuerpo: {'reabrir': reabrir, if (motivo.isNotEmpty) 'motivo': motivo},
    );
  }

  /// El trabajador rechaza la asignación. Solo vale si todavía no hay pago en
  /// garantía; con el escrow ya depositado responde 409.
  Future<String?> rechazarAsignacion({required String idPublicacion}) =>
      _transicion(RutasApi.rechazarTrabajo(idPublicacion));

  /// Cualquiera de las dos partes reclama un problema a soporte.
  ///
  /// Es la **única salida** de un trabajo ya iniciado que no acaba de común
  /// acuerdo: lo deja en disputa con el dinero congelado —ni liberado ni
  /// reembolsado— hasta que un ADMIN resuelva. Puede reclamar también el
  /// trabajador, a propósito: si no, quedaría atrapado en un trabajo que no
  /// puede cancelar y cuyo pago depende de que la otra parte quiera
  /// confirmarlo.
  ///
  /// El servidor exige [motivo] no vacío (400 si falta).
  Future<String?> reclamarProblema({
    required String idPublicacion,
    required String motivo,
    String descripcion = '',
  }) {
    return _transicion(
      RutasApi.reclamarTrabajo(idPublicacion),
      cuerpo: {
        'motivo': motivo,
        if (descripcion.isNotEmpty) 'descripcion': descripcion,
      },
    );
  }

  // ── Interno ─────────────────────────────────────────────────

  Future<List<Publicacion>> _listaDeTrabajos(String ruta) async {
    final json = await _api.obtener(ruta);
    if (json is! List) {
      throw RespuestaIlegible(
          detalle: 'Se esperaba una lista de trabajos en $ruta');
    }
    return [
      for (final e in json)
        if (e is Map) Publicacion.desdeJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Dispara una transición de la máquina de estados. Todas responden con el
  /// trabajo actualizado, que aquí se ignora a propósito: la pantalla recarga
  /// después, y así lo que se ve viene siempre de la misma lectura.
  Future<String?> _transicion(String ruta, {Object? cuerpo}) {
    return _intentar(() async {
      await _api.crear(ruta, cuerpo: cuerpo ?? const <String, dynamic>{});
      return null;
    });
  }

  /// Mismo envoltorio que `AuthService._intentar`: `null` si fue bien, o un
  /// texto en español listo para enseñar.
  ///
  /// Los 409 de la máquina de estados llegan con un `message` que ya explica
  /// qué hacer ("sube una evidencia nueva antes de volver a entregar"), así
  /// que se pasan tal cual: reescribirlos aquí sería perder información.
  Future<String?> _intentar(Future<String?> Function() operacion) async {
    try {
      return await operacion();
    } on ExcepcionApi catch (e) {
      if (e.campos.isNotEmpty) return e.campos.values.first;
      return e.mensaje;
    } catch (e) {
      debugPrint('Fallo inesperado en PublicacionService: $e');
      return MensajesError.errorGeneral;
    }
  }
}
