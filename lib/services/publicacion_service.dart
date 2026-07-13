import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/publicacion.dart';
import '../utils/constantes.dart';

/// Servicio para crear y consultar publicaciones de trabajos en Firestore.
class PublicacionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestoreColecciones.publicaciones);

  /// Crea una nueva publicación. Devuelve null si todo fue bien o un
  /// mensaje de error.
  Future<String?> crearPublicacion(Publicacion publicacion) async {
    try {
      await _col.add(publicacion.aFirestore());
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// Publicaciones activas más recientes, limitadas a [limite].
  ///
  /// Filtra por estado en el servidor (escalable: no descarga trabajos ya
  /// asignados/cerrados). Requiere el índice compuesto
  /// (estado ASC, fechaCreacion DESC) — ver firestore.indexes.json.
  Stream<List<Publicacion>> streamPublicaciones({int limite = 20}) {
    return _col
        .where('estado', isEqualTo: EstadosTrabajo.activo)
        .orderBy('fechaCreacion', descending: true)
        .limit(limite)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Publicacion.desdeFirestore(d)).toList());
  }

  /// Stream con las publicaciones de un empleador específico.
  ///
  /// Se filtra por uid (igualdad, sin índice compuesto) y se ordena por
  /// fecha en memoria.
  Stream<List<Publicacion>> streamMisPublicaciones(String uid) {
    return _col
        .where('uidEmpleador', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final lista =
          snap.docs.map((d) => Publicacion.desdeFirestore(d)).toList();
      lista.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      return lista;
    });
  }

  /// Cambia el estado de una publicación ('activo' | 'cerrado').
  Future<String?> actualizarEstado(String id, String estado) async {
    try {
      await _col.doc(id).update({'estado': estado});
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// Elimina una publicación.
  Future<String?> eliminarPublicacion(String id) async {
    try {
      await _col.doc(id).delete();
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// Obtiene una publicación puntual por id.
  Future<Publicacion?> obtenerPublicacion(String id) async {
    try {
      final doc = await _col.doc(id).get();
      return doc.exists ? Publicacion.desdeFirestore(doc) : null;
    } catch (_) {
      return null;
    }
  }

  /// Publicación en vivo por id (para el detalle).
  Stream<Publicacion?> streamPublicacion(String id) {
    return _col
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? Publicacion.desdeFirestore(d) : null);
  }

  /// Asigna el trabajo al trabajador de [idPostulacion]: el trabajo pasa a
  /// 'asignado', esa postulación queda 'aceptada' y las demás 'rechazada'.
  ///
  /// Usa una transacción (ACID): relee el estado dentro de la transacción para
  /// impedir asignaciones dobles bajo concurrencia. Las postulaciones se
  /// consultan fuera (Firestore no permite queries dentro de transacciones).
  Future<String?> asignarTrabajador({
    required String idPublicacion,
    required String idPostulacion,
    required String uidTrabajador,
    required String nombreTrabajador,
  }) async {
    try {
      final postCol = _db.collection(FirestoreColecciones.postulaciones);
      final pubRef = _col.doc(idPublicacion);
      final chatRef =
          _db.collection(FirestoreColecciones.chats).doc(idPublicacion);
      final todas =
          await postCol.where('idPublicacion', isEqualTo: idPublicacion).get();

      String? err;
      await _db.runTransaction((tx) async {
        final pubSnap = await tx.get(pubRef);
        if (!pubSnap.exists) { err = 'La publicación ya no existe'; return; }
        final pubData = pubSnap.data()!;
        if ((pubData['estado'] ?? '') != EstadosTrabajo.activo) {
          err = 'Este trabajo ya no está disponible para asignar';
          return;
        }
        final uidEmpleador = pubData['uidEmpleador'] ?? '';
        tx.update(pubRef, {
          'estado': EstadosTrabajo.asignado,
          'uidTrabajadorAsignado': uidTrabajador,
          'nombreTrabajadorAsignado': nombreTrabajador,
        });
        for (final doc in todas.docs) {
          tx.update(doc.reference, {
            'estado': doc.id == idPostulacion
                ? EstadosPostulacion.aceptada
                : EstadosPostulacion.rechazada,
          });
        }
        tx.set(chatRef, {
          'idPublicacion': idPublicacion,
          'tituloPublicacion': pubData['titulo'] ?? '',
          'uidEmpleador': uidEmpleador,
          'nombreEmpleador': pubData['autor'] ?? '',
          'uidTrabajador': uidTrabajador,
          'nombreTrabajador': nombreTrabajador,
          'participantes': [uidEmpleador, uidTrabajador],
          'ultimoMensaje': 'Chat iniciado. ¡Acuerden el pago y el tiempo!',
          'fechaUltimoMensaje': Timestamp.now(),
          'pagoMonto': 0,
          'pagoPropuestoPor': '',
          'pagoAcordado': false,
          'tiempoValor': '',
          'tiempoPropuestoPor': '',
          'tiempoAcordado': false,
          'fechaCreacion': Timestamp.now(),
        });
      });
      return err;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── PAGO EN GARANTÍA (ESCROW) ──────────────────────────────
  // NOTA: prototipo. En producción esto debe correr en un backend seguro
  // (Cloud Functions) con una pasarela de pago real.

  /// El contratista deposita el pago en garantía: se descuenta de su saldo
  /// y el trabajo pasa a 'en_progreso'.
  Future<String?> reservarPago({
    required String idPublicacion,
    required String uidEmpleador,
    required double monto,
  }) async {
    try {
      final pubRef = _col.doc(idPublicacion);
      final userRef =
          _db.collection(FirestoreColecciones.usuarios).doc(uidEmpleador);
      String? err;
      await _db.runTransaction((tx) async {
        final pubSnap = await tx.get(pubRef);
        final userSnap = await tx.get(userRef);
        if (!pubSnap.exists) { err = 'La publicación ya no existe'; return; }
        if (pubSnap.data()?['pagoRetenido'] == true) return; // ya reservado
        final saldo = ((userSnap.data()?['saldo'] ?? 0) as num).toDouble();
        if (saldo < monto) { err = 'Saldo insuficiente. Recarga tu cartera.'; return; }
        tx.update(userRef, {'saldo': saldo - monto});
        tx.update(pubRef, {
          'montoAcordado': monto,
          'pagoRetenido': true,
          'estado': EstadosTrabajo.enProgreso,
        });
      });
      return err;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// El trabajador marca el trabajo como entregado.
  Future<String?> marcarEntregado(String idPublicacion) async {
    try {
      await _col.doc(idPublicacion).update({'entregado': true});
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// El contratista confirma la entrega y se libera el pago al trabajador.
  Future<String?> confirmarYPagar(String idPublicacion) async {
    try {
      final pubRef = _col.doc(idPublicacion);
      await _db.runTransaction((tx) async {
        final pubSnap = await tx.get(pubRef);
        if (!pubSnap.exists) throw Exception('no existe');
        final data = pubSnap.data()!;
        if (data['pagoLiberado'] == true) return; // idempotente
        if (data['pagoRetenido'] != true) throw Exception('sin escrow');
        final uidTrab = data['uidTrabajadorAsignado'] ?? '';
        final monto = ((data['montoAcordado'] ?? 0) as num).toDouble();
        final workerRef =
            _db.collection(FirestoreColecciones.usuarios).doc(uidTrab);
        final workerSnap = await tx.get(workerRef);
        final saldo = ((workerSnap.data()?['saldo'] ?? 0) as num).toDouble();
        final tc = (workerSnap.data()?['trabajosCompletados'] ?? 0) as int;
        tx.update(workerRef,
            {'saldo': saldo + monto, 'trabajosCompletados': tc + 1});
        tx.update(pubRef,
            {'pagoLiberado': true, 'estado': EstadosTrabajo.completado});
      });
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// Reembolsa el pago retenido al contratista y cierra el trabajo (disputa).
  Future<String?> reembolsar(String idPublicacion, String uidEmpleador) async {
    try {
      final pubRef = _col.doc(idPublicacion);
      final userRef =
          _db.collection(FirestoreColecciones.usuarios).doc(uidEmpleador);
      await _db.runTransaction((tx) async {
        final pubSnap = await tx.get(pubRef);
        final userSnap = await tx.get(userRef);
        final data = pubSnap.data()!;
        if (data['pagoRetenido'] != true || data['pagoLiberado'] == true) return;
        final monto = ((data['montoAcordado'] ?? 0) as num).toDouble();
        final saldo = ((userSnap.data()?['saldo'] ?? 0) as num).toDouble();
        tx.update(userRef, {'saldo': saldo + monto});
        tx.update(pubRef, {'pagoRetenido': false, 'estado': EstadosTrabajo.cerrado});
      });
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// Marca el trabajo como completado e incrementa trabajosCompletados del
  /// trabajador asignado (una sola vez, dentro de una transacción).
  Future<String?> marcarCompletado(String idPublicacion) async {
    try {
      final pubRef = _col.doc(idPublicacion);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(pubRef);
        if (!snap.exists) throw Exception('no existe');
        final data = snap.data()!;
        final estado = data['estado'] ?? '';
        if (estado == EstadosTrabajo.completado) return; // idempotente
        if (estado != EstadosTrabajo.asignado &&
            estado != EstadosTrabajo.enProgreso) {
          throw Exception('estado inválido');
        }
        final uidTrab = data['uidTrabajadorAsignado'] ?? '';
        tx.update(pubRef, {'estado': EstadosTrabajo.completado});
        if (uidTrab is String && uidTrab.isNotEmpty) {
          final userRef =
              _db.collection(FirestoreColecciones.usuarios).doc(uidTrab);
          tx.update(userRef, {'trabajosCompletados': FieldValue.increment(1)});
        }
      });
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }
}
