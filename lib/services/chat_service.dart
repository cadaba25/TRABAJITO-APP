import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat.dart';
import '../utils/constantes.dart';

/// Servicio de chats y negociación de pago/tiempo entre las partes.
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestoreColecciones.chats);

  CollectionReference<Map<String, dynamic>> _msgs(String chatId) =>
      _col.doc(chatId).collection(FirestoreColecciones.mensajes);

  /// Chats del usuario (orden en memoria por último mensaje).
  Stream<List<Chat>> streamMisChats(String uid) {
    return _col
        .where('participantes', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final lista = snap.docs.map((d) => Chat.desdeFirestore(d)).toList();
      lista.sort(
          (a, b) => b.fechaUltimoMensaje.compareTo(a.fechaUltimoMensaje));
      return lista;
    });
  }

  Stream<Chat?> streamChat(String chatId) => _col
      .doc(chatId)
      .snapshots()
      .map((d) => d.exists ? Chat.desdeFirestore(d) : null);

  Future<Chat?> obtenerChat(String chatId) async {
    final d = await _col.doc(chatId).get();
    return d.exists ? Chat.desdeFirestore(d) : null;
  }

  Stream<List<Mensaje>> streamMensajes(String chatId) => _msgs(chatId)
      .orderBy('fecha')
      .snapshots()
      .map((snap) => snap.docs.map((d) => Mensaje.desdeFirestore(d)).toList());

  /// Garantiza que el documento del chat exista con sus datos de identidad
  /// (auto-repara chats de asignaciones antiguas). Idempotente: no pisa la
  /// conversación ni el estado de negociación.
  Future<void> asegurarChat(Chat c) async {
    if (c.id.isEmpty || c.uidEmpleador.isEmpty || c.uidTrabajador.isEmpty) {
      return;
    }
    await _col.doc(c.id).set({
      'idPublicacion': c.idPublicacion,
      'tituloPublicacion': c.tituloPublicacion,
      'uidEmpleador': c.uidEmpleador,
      'nombreEmpleador': c.nombreEmpleador,
      'uidTrabajador': c.uidTrabajador,
      'nombreTrabajador': c.nombreTrabajador,
      'participantes': c.participantes,
    }, SetOptions(merge: true));
  }

  Future<void> _postear(String chatId, Mensaje m) async {
    final batch = _db.batch();
    batch.set(_msgs(chatId).doc(), m.aFirestore());
    // set con merge: no falla si el doc del chat aún no existe.
    batch.set(
      _col.doc(chatId),
      {
        'ultimoMensaje': m.texto,
        'fechaUltimoMensaje': Timestamp.fromDate(m.fecha),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<String?> enviarMensaje(String chatId, String texto, String deUid) async {
    if (texto.trim().isEmpty) return null;
    try {
      await _postear(
          chatId,
          Mensaje(texto: texto.trim(), deUid: deUid, fecha: DateTime.now()));
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── NEGOCIACIÓN DE PAGO ────────────────────────────────────
  Future<String?> proponerPago(String chatId, double monto, String deUid) async {
    try {
      await _col.doc(chatId).update({
        'pagoMonto': monto,
        'pagoPropuestoPor': deUid,
        'pagoAcordado': false,
      });
      await _postear(
          chatId,
          Mensaje(
              texto: 'Propuso un pago de L. ${monto.toStringAsFixed(0)}',
              deUid: deUid,
              tipo: 'sistema',
              fecha: DateTime.now()));
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  Future<String?> aceptarPago(String chatId, String uid) async {
    try {
      String? err;
      bool acepto = false;
      await _db.runTransaction((tx) async {
        final ref = _col.doc(chatId);
        final d = (await tx.get(ref)).data() ?? {};
        final propuestoPor = d['pagoPropuestoPor'] ?? '';
        if (propuestoPor == '') { err = 'No hay una propuesta que aceptar'; return; }
        if (propuestoPor == uid) { err = 'No puedes aceptar tu propia propuesta'; return; }
        if (d['pagoAcordado'] == true) return; // idempotente
        tx.update(ref, {'pagoAcordado': true});
        acepto = true;
      });
      if (err != null) return err;
      if (acepto) {
        await _postear(
            chatId,
            Mensaje(
                texto: 'Aceptó la propuesta de pago',
                deUid: uid,
                tipo: 'sistema',
                fecha: DateTime.now()));
      }
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── NEGOCIACIÓN DE TIEMPO ──────────────────────────────────
  Future<String?> proponerTiempo(String chatId, String valor, String deUid) async {
    try {
      await _col.doc(chatId).update({
        'tiempoValor': valor,
        'tiempoPropuestoPor': deUid,
        'tiempoAcordado': false,
      });
      await _postear(
          chatId,
          Mensaje(
              texto: 'Propuso un plazo: $valor',
              deUid: deUid,
              tipo: 'sistema',
              fecha: DateTime.now()));
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  Future<String?> aceptarTiempo(String chatId, String uid) async {
    try {
      String? err;
      bool acepto = false;
      await _db.runTransaction((tx) async {
        final ref = _col.doc(chatId);
        final d = (await tx.get(ref)).data() ?? {};
        final propuestoPor = d['tiempoPropuestoPor'] ?? '';
        if (propuestoPor == '') { err = 'No hay una propuesta que aceptar'; return; }
        if (propuestoPor == uid) { err = 'No puedes aceptar tu propia propuesta'; return; }
        if (d['tiempoAcordado'] == true) return; // idempotente
        tx.update(ref, {'tiempoAcordado': true});
        acepto = true;
      });
      if (err != null) return err;
      if (acepto) {
        await _postear(
            chatId,
            Mensaje(
                texto: 'Aceptó la propuesta de plazo',
                deUid: uid,
                tipo: 'sistema',
                fecha: DateTime.now()));
      }
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }
}
