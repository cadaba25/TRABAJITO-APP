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

  /// Stream con las publicaciones más recientes, limitadas a [limite]
  /// (permite paginación incremental al hacer scroll).
  ///
  /// Se ordena solo por fecha (índice de campo único, sin necesidad de
  /// índices compuestos). Las publicaciones cerradas se filtran en memoria.
  Stream<List<Publicacion>> streamPublicaciones({int limite = 20}) {
    return _col
        .orderBy('fechaCreacion', descending: true)
        .limit(limite)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Publicacion.desdeFirestore(d))
            .where((p) => p.estado == 'activo')
            .toList());
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
}
