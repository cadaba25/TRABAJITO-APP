import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calificacion.dart';
import '../utils/constantes.dart';

/// Servicio de calificaciones bidireccionales.
class CalificacionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestoreColecciones.calificaciones);

  String _docId(String idPublicacion, String deUid) => '${idPublicacion}_$deUid';

  /// Registra una calificación y actualiza, en una transacción:
  /// - el documento de calificación (impide doble calificación),
  /// - el promedio del usuario calificado,
  /// - la bandera correspondiente en la publicación.
  Future<String?> calificar({
    required Calificacion calificacion,
    required bool porEmpleador,
  }) async {
    try {
      final calRef = _col.doc(_docId(calificacion.idPublicacion, calificacion.deUid));
      final userRef = _db
          .collection(FirestoreColecciones.usuarios)
          .doc(calificacion.paraUid);
      final pubRef = _db
          .collection(FirestoreColecciones.publicaciones)
          .doc(calificacion.idPublicacion);

      await _db.runTransaction((tx) async {
        final calSnap = await tx.get(calRef);
        if (calSnap.exists) {
          throw Exception('ya calificado');
        }
        final userSnap = await tx.get(userRef);
        final pubSnap = await tx.get(pubRef);
        final data = userSnap.data() ?? {};
        final total = (data['totalCalificaciones'] ?? 0) as int;
        final promedio = ((data['calificacionPromedio'] ?? 0) as num).toDouble();
        final nuevoTotal = total + 1;
        final nuevoPromedio =
            ((promedio * total) + calificacion.estrellas) / nuevoTotal;

        // ¿Con esta calificación quedan ambas partes calificadas?
        final pub = pubSnap.data() ?? {};
        final otraHecha = porEmpleador
            ? (pub['calificadoPorTrabajador'] == true)
            : (pub['calificadoPorEmpleador'] == true);

        tx.set(calRef, calificacion.aFirestore());
        tx.update(userRef, {
          'totalCalificaciones': nuevoTotal,
          'calificacionPromedio': nuevoPromedio,
        });
        tx.update(pubRef, {
          if (porEmpleador) 'calificadoPorEmpleador': true,
          if (!porEmpleador) 'calificadoPorTrabajador': true,
          if (otraHecha) 'estado': EstadosTrabajo.finalizado,
        });
      });
      return null;
    } catch (e) {
      if (e.toString().contains('ya calificado')) {
        return 'Ya calificaste este trabajo';
      }
      return MensajesError.errorGeneral;
    }
  }

  /// Reseñas recibidas por un usuario (orden en memoria).
  Stream<List<Calificacion>> streamCalificaciones(String paraUid) {
    return _col.where('paraUid', isEqualTo: paraUid).snapshots().map((snap) {
      final lista = snap.docs.map((d) => Calificacion.desdeFirestore(d)).toList();
      lista.sort((a, b) => b.fecha.compareTo(a.fecha));
      return lista;
    });
  }
}
