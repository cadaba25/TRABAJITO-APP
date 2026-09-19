import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../funcionalidades/autenticacion/datos/auth_service.dart';
import '../../funcionalidades/calificaciones/datos/calificacion_service.dart';
import '../../funcionalidades/cartera/datos/cartera_service.dart';
import '../../funcionalidades/chat/datos/chat_service.dart';
import '../../funcionalidades/perfil/datos/perfil_service.dart';
import '../../funcionalidades/postulaciones/datos/postulacion_service.dart';
import '../../funcionalidades/trabajos/datos/publicacion_service.dart';

/// **Raíz de composición de la app**: el único sitio donde se construyen los
/// servicios (ADR-0014, regla 15 de `CLAUDE.md`).
///
/// Hasta la tarea 027 cada pantalla se fabricaba el suyo dentro
/// (`final _s = AuthService();`, y `CarteraService` uno **nuevo en cada
/// acceso**). Eso no era un detalle de estilo: es la razón por la que solo 2
/// de las ~14 pantallas tenían test. Una pantalla que construye su propio
/// cliente HTTP no admite un doble, y sin doble no hay test de pantalla.
///
/// Con esto, un test monta la pantalla envuelta en
/// `MultiProvider(providers: proveedoresDeLaApp(auth: AuthServiceFalso()), ...)`
/// —o directamente `Provider<AuthService>.value(...)`— y la pantalla ni se
/// entera.
///
/// Los `create` son **perezosos**: si un test no toca un servicio, no se
/// construye ninguno. Importa, porque construir un `AuthService` de verdad
/// arrastra `ApiClient.instancia`, y ese lee el almacén seguro del
/// dispositivo.
///
/// ## Qué NO está aquí, a propósito
///
/// - `ApiClient`: tiene su propio mecanismo (`ApiClient.fijarInstancia`), que
///   es el que usan los ~60 tests de la capa HTTP. Duplicarlo con `provider`
///   daría dos formas de sustituir lo mismo, que es peor que una.
/// - `notificadorTema`: es un `ValueNotifier` global sin dependencias que no
///   hace falta sustituir en ningún test. Ver `nucleo/tema/notificador_tema.dart`.
List<SingleChildWidget> proveedoresDeLaApp({
  AuthService? auth,
  PerfilService? perfil,
  PublicacionService? publicaciones,
  PostulacionService? postulaciones,
  CarteraService? cartera,
  CalificacionService? calificaciones,
  ChatService? chats,
}) {
  return [
    Provider<AuthService>(create: (_) => auth ?? AuthService()),
    Provider<PerfilService>(create: (_) => perfil ?? PerfilService()),
    Provider<PublicacionService>(
        create: (_) => publicaciones ?? PublicacionService()),
    Provider<PostulacionService>(
        create: (_) => postulaciones ?? PostulacionService()),
    Provider<CarteraService>(create: (_) => cartera ?? CarteraService()),
    Provider<CalificacionService>(
        create: (_) => calificaciones ?? CalificacionService()),
    Provider<ChatService>(create: (_) => chats ?? ChatService()),
  ];
}
