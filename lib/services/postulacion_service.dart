import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/postulacion.dart';
import '../utils/constantes.dart';

/// Servicio para crear y consultar postulaciones a trabajos.
class PostulacionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestoreColecciones.postulaciones);

  /// docId determinista para impedir postulaciones duplicadas.
  String _docId(String idPublicacion, String uidTrabajador) =>
      '${idPublicacion}_$uidTrabajador';

  /// Crea (o re-activa) la postulación de un trabajador a un trabajo.
  Future<String?> postular(Postulacion p) async {
    try {
      final ref = _col.doc(_docId(p.idPublicacion, p.uidTrabajador));
      final actual = await ref.get();
      if (actual.exists &&
          (actual.data()?['estado'] ?? '') != EstadosPostulacion.retirada) {
        return 'Ya te postulaste a este trabajo';
      }
      await ref.set(p.aFirestore());
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// Retira una postulación pendiente.
  Future<String?> retirar(String id) async {
    try {
      await _col.doc(id).update({'estado': EstadosPostulacion.retirada});
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  /// Postulación del trabajador actual a un trabajo (o null si no existe).
  Stream<Postulacion?> streamMiPostulacion(
      String idPublicacion, String uidTrabajador) {
    return _col
        .doc(_docId(idPublicacion, uidTrabajador))
        .snapshots()
        .map((d) => d.exists ? Postulacion.desdeFirestore(d) : null);
  }

  /// Todas las postulaciones de un trabajador (orden en memoria).
  Stream<List<Postulacion>> streamMisPostulaciones(String uidTrabajador) {
    return _col
        .where('uidTrabajador', isEqualTo: uidTrabajador)
        .snapshots()
        .map((snap) {
      final lista =
          snap.docs.map((d) => Postulacion.desdeFirestore(d)).toList();
      lista.sort((a, b) => b.fechaPostulacion.compareTo(a.fechaPostulacion));
      return lista;
    });
  }

  /// Postulantes de una publicación (orden en memoria).
  Stream<List<Postulacion>> streamPostulantes(String idPublicacion) {
    return _col
        .where('idPublicacion', isEqualTo: idPublicacion)
        .snapshots()
        .map((snap) {
      final lista = snap.docs
          .map((d) => Postulacion.desdeFirestore(d))
          .where((p) => p.estado != EstadosPostulacion.retirada)
          .toList();
      lista.sort((a, b) => b.fechaPostulacion.compareTo(a.fechaPostulacion));
      return lista;
    });
  }
}
