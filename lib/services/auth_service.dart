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
      case 'wrong-password':
      case 'invalid-credential':     return MensajesError.contrasenaIncorrecta;
      case 'user-not-found':         return MensajesError.usuarioNoEncontrado;
      case 'network-request-failed': return MensajesError.errorConexion;
      case 'weak-password':          return 'La contraseña es muy débil.';
      case 'invalid-email':          return MensajesError.correoInvalido;
      case 'too-many-requests':      return 'Demasiados intentos. Espera un momento.';
      default:                       return MensajesError.errorGeneral;
    }
  }
}
