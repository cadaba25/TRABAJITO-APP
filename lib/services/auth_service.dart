import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario.dart';
import '../utils/constantes.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get estadoSesion => _auth.authStateChanges();
  User? get usuarioActual => _auth.currentUser;
  bool get haySesion => _auth.currentUser != null;

  // ── REGISTRO PASO 1: crear cuenta en Firebase Auth ─────────
  Future<String?> crearCuentaAuth({
    required String correo,
    required String contrasena,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: contrasena,
      );
      // Enviar verificación de correo (no bloqueante).
      try {
        await _auth.currentUser?.sendEmailVerification();
      } catch (_) {}
      return null; // éxito
    } on FirebaseAuthException catch (e) {
      return _traducirError(e.code);
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── GUARDAR PERFIL COMPLETO EN FIRESTORE ───────────────────
  Future<String?> guardarPerfil(Usuario usuario) async {
    try {
      await _db
          .collection(FirestoreColecciones.usuarios)
          .doc(usuario.uid)
          .set(usuario.aFirestore(), SetOptions(merge: true));
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── ACTUALIZAR CAMPOS ESPECÍFICOS ─────────────────────────
  Future<String?> actualizarCampos(Map<String, dynamic> campos) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 'No hay sesión activa';
      await _db
          .collection(FirestoreColecciones.usuarios)
          .doc(uid)
          .update(campos);
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── INICIO DE SESIÓN ───────────────────────────────────────
  Future<String?> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: contrasena,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _traducirError(e.code);
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── CERRAR SESIÓN ─────────────────────────────────────────
  Future<void> cerrarSesion() async => _auth.signOut();

  // ── RECUPERAR CONTRASEÑA ──────────────────────────────────
  Future<String?> enviarResetPassword(String correo) async {
    try {
      await _auth.sendPasswordResetEmail(email: correo.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _traducirError(e.code);
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── VERIFICACIÓN DE CORREO ────────────────────────────────
  bool get correoVerificado => _auth.currentUser?.emailVerified ?? false;

  Future<String?> enviarVerificacionCorreo() async {
    try {
      final u = _auth.currentUser;
      if (u != null && !u.emailVerified) {
        await u.sendEmailVerification();
      }
      return null;
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── ELIMINAR CUENTA ───────────────────────────────────────
  /// Borra el documento del usuario y sus datos asociados en Firestore, y
  /// luego elimina la cuenta de Authentication. Deja ambas partes en sync.
  Future<String?> eliminarCuenta() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No hay sesión activa';
      final uid = user.uid;

      // Borrar datos en Firestore (perfil, publicaciones y postulaciones).
      final pubs = await _db
          .collection(FirestoreColecciones.publicaciones)
          .where('uidEmpleador', isEqualTo: uid)
          .get();
      final posts = await _db
          .collection(FirestoreColecciones.postulaciones)
          .where('uidTrabajador', isEqualTo: uid)
          .get();

      final batch = _db.batch();
      for (final d in pubs.docs) {
        batch.delete(d.reference);
      }
      for (final d in posts.docs) {
        batch.delete(d.reference);
      }
      batch.delete(
          _db.collection(FirestoreColecciones.usuarios).doc(uid));
      await batch.commit();

      // Borrar la cuenta de Authentication.
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Por seguridad, cierra sesión e inicia de nuevo antes de eliminar tu cuenta.';
      }
      return _traducirError(e.code);
    } catch (_) {
      return MensajesError.errorGeneral;
    }
  }

  // ── STREAM DE TRABAJADORES ────────────────────────────────
  /// Lista en tiempo real de los usuarios trabajadores.
  /// Filtra por igualdad (sin índice compuesto); el orden se hace en memoria.
  Stream<List<Usuario>> streamTrabajadores() {
    return _db
        .collection(FirestoreColecciones.usuarios)
        .where('tipoUsuario', isEqualTo: ValoresDefecto.rolTrabajador)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Usuario.desdeFirestore(d)).toList());
  }

  // ── STREAM DEL USUARIO ACTUAL ──────────────────────────────
  /// Documento del usuario actual en vivo (se mantiene fresco tras
  /// completar el registro o actualizar el perfil).
  Stream<Usuario?> streamUsuarioActual() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection(FirestoreColecciones.usuarios)
        .doc(uid)
        .snapshots()
        .map((d) => d.exists ? Usuario.desdeFirestore(d) : null);
  }

  // ── OBTENER USUARIO POR UID ────────────────────────────────
  Future<Usuario?> obtenerUsuarioPorUid(String uid) async {
    try {
      final doc = await _db
          .collection(FirestoreColecciones.usuarios)
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return Usuario.desdeFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  // ── OBTENER USUARIO ACTUAL ─────────────────────────────────
  Future<Usuario?> obtenerUsuarioActual() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      final doc = await _db
          .collection(FirestoreColecciones.usuarios)
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return Usuario.desdeFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  // ── TRADUCIR ERRORES ──────────────────────────────────────
  String _traducirError(String codigo) {
    switch (codigo) {
      case 'email-already-in-use':   return MensajesError.correoEnUso;
      // Firebase unifica "usuario inexistente" y "contraseña incorrecta" en
      // invalid-credential (protección anti-enumeración de correos).
      case 'wrong-password':
      case 'invalid-credential':     return MensajesError.credencialesInvalidas;
      case 'user-not-found':         return MensajesError.usuarioNoEncontrado;
      case 'network-request-failed': return MensajesError.errorConexion;
      case 'weak-password':          return 'La contraseña es muy débil.';
      case 'invalid-email':          return MensajesError.correoInvalido;
      case 'too-many-requests':      return 'Demasiados intentos. Espera un momento.';
      default:                       return MensajesError.errorGeneral;
    }
  }
}
