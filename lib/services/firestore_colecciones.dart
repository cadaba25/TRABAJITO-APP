// Nombres de las colecciones de Firestore.
//
// **Este archivo muere en la fase 3 de ADR-0009.** Solo lo usan los tres
// servicios que todavía no se han migrado al backend propio
// (`chat_service`, `calificacion_service` y `cartera_service`). Vive aquí, al
// lado de ellos y NO en `nucleo/`, precisamente para que se borre con ellos:
// nada de `lib/nucleo/` ni de `lib/funcionalidades/` debe importarlo.
class FirestoreColecciones {
  static const String usuarios = 'usuarios';
  static const String publicaciones = 'publicaciones';
  static const String postulaciones = 'postulaciones';
  static const String calificaciones = 'calificaciones';
  static const String chats = 'chats';
  static const String mensajes = 'mensajes';
  static const String tarjetas = 'tarjetas';   // subcolección de usuarios
  static const String evidencias = 'evidencias'; // subcolección de publicaciones
}
