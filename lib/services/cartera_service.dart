import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tarjeta.dart';
import '../utils/constantes.dart';

/// Servicio de cartera: tarjetas guardadas y saldo en la app.
///
/// NOTA: en producción los movimientos de dinero deben procesarse en un
/// backend seguro (Cloud Functions) con una pasarela de pago real. Esta
/// implementación es un prototipo para pruebas.
class CarteraService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _usuarioRef(String uid) =>
      _db.collection(FirestoreColecciones.usuarios).doc(uid);

  CollectionReference<Map<String, dynamic>> _tarjetasRef(String uid) =>
      _usuarioRef(uid).collection(FirestoreColecciones.tarjetas);

  Stream<List<Tarjeta>> streamTarjetas(String uid) => _tarjetasRef(uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Tarjeta.desdeFirestore(d)).toList());

  Stream<double> streamSaldo(String uid) => _usuarioRef(uid)
      .snapshots()
      .map((d) => ((d.data()?['saldo'] ?? 0) as num).toDouble());

  /// Agrega una tarjeta (guarda solo los últimos 4 dígitos).
  Future<String?> agregarTarjeta({
    required String uid,
    required String numero,
    required String titular,
    required String vencimiento,
  }) async {
    try {
      final limpio = numero.replaceAll(RegExp(r'\s'), '');
      if (limpio.length < 13) return 'Número de tarjeta inválido';
      final tarjeta = Tarjeta(
        marca: Tarjeta.marcaDesdeNumero(limpio),
        ultimos4: limpio.substring(limpio.length - 4),
        titular: titular.trim(),
        vencimiento: vencimiento.trim(),
      );
      await _tarjetasRef(uid).add(tarjeta.aFirestore());
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  Future<String?> eliminarTarjeta(String uid, String idTarjeta) async {
    try {
      await _tarjetasRef(uid).doc(idTarjeta).delete();
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// Recarga saldo (simulado desde una tarjeta).
  Future<String?> recargarSaldo(String uid, double monto) async {
    try {
      await _usuarioRef(uid).update({'saldo': FieldValue.increment(monto)});
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }
}
