// Test de arranque de la app: `PantallaInicial` (en lib/main.dart) decide
// entre `LoginScreen` e `InicioScreen` según el estado de autenticación de
// Firebase, mostrando `PantallaCarga` mientras el stream de auth no ha
// emitido su primer valor.
//
// El proyecto no tiene ninguna capa de abstracción propia sobre
// `firebase_auth`/`cloud_firestore` (AuthService usa `FirebaseAuth.instance`
// y `FirebaseFirestore.instance` directo), así que no hay forma de inyectar
// un mock a nivel de Dart puro sin tocar lib/. En su lugar, este test
// reemplaza `FirebaseAuthPlatform.instance` (el punto de extensión que la
// propia librería expone para que las plataformas -Android/iOS/web- se
// registren) por una implementación falsa controlada desde el test, y usa
// `setupFirebaseCoreMocks()` (utilidad de test que ya trae
// `firebase_core_platform_interface`, ya en el pub cache del proyecto como
// dependencia transitiva; no se agregó ninguna dependencia nueva) para que
// `Firebase.initializeApp()` no intente hablar con un canal de plataforma
// real.
//
// Limitación documentada: `InicioScreen` (la rama "usuario autenticado")
// crea streams de Firestore reales en su `initState` (`AuthService` y
// `ChatService`), y Firestore no se mockeó aquí (hacerlo habría requerido
// replicar buena parte de la interfaz de `cloud_firestore_platform_interface`
// -queries, colecciones, snapshots-, un esfuerzo mucho mayor al alcance de
// esta tarea). Por eso el caso "usuario autenticado" solo verifica que
// `PantallaInicial` decide construir `InicioScreen` (la decisión de
// enrutamiento, que es la lógica real que queríamos cubrir), tolerando el
// error interno esperado de `InicioScreen` al no encontrar Firestore
// disponible. El caso "usuario no autenticado" sí se verifica de punta a
// punta, con contenido real de `LoginScreen` (no solo el tipo de widget).
import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trabajito/main.dart';
import 'package:trabajito/screens/login_screen.dart';
import 'package:trabajito/screens/inicio_screen.dart';

/// Multi-factor mínimo: ningún test ejercita 2FA, así que basta con
/// heredar sin sobrescribir nada (los métodos base ya lanzan
/// `UnimplementedError` si alguien los llamara, lo cual sería una señal
/// clara de que este fake quedó corto).
class _MultiFactorFalso extends MultiFactorPlatform {
  _MultiFactorFalso(super.auth);
}

class _UsuarioFalso extends UserPlatform {
  _UsuarioFalso(FirebaseAuthPlatform auth, PigeonUserDetails datos)
      : super(auth, _MultiFactorFalso(auth), datos);
}

/// Reemplazo controlado de `FirebaseAuthPlatform.instance`. Expone un
/// método `emitirUsuario` para que cada test controle qué emite
/// `authStateChanges()` sin depender de un backend de Firebase real.
class _FirebaseAuthPlatformFalso extends FirebaseAuthPlatform {
  _FirebaseAuthPlatformFalso() : super();

  final StreamController<UserPlatform?> _controlador =
      StreamController<UserPlatform?>.broadcast();
  UserPlatform? _usuarioActual;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => _usuarioActual;

  @override
  Stream<UserPlatform?> authStateChanges() => _controlador.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => _controlador.stream;

  @override
  Stream<UserPlatform?> userChanges() => _controlador.stream;

  void emitirUsuario(UserPlatform? usuario) {
    _usuarioActual = usuario;
    _controlador.add(usuario);
  }
}

UserPlatform _crearUsuarioAutenticado(FirebaseAuthPlatform auth) {
  return _UsuarioFalso(
    auth,
    PigeonUserDetails(
      userInfo: PigeonUserInfo(
        uid: 'uid-de-prueba',
        email: 'trabajador@trabajito.test',
        isAnonymous: false,
        isEmailVerified: true,
      ),
      providerData: const [],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FirebaseAuthPlatformFalso authFalso;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    authFalso = _FirebaseAuthPlatformFalso();
    FirebaseAuthPlatform.instance = authFalso;
    await Firebase.initializeApp();
  });

  tearDown(() {
    // No queda sesión iniciada entre tests: cada test debe emitir su
    // propio estado explícitamente.
    authFalso.emitirUsuario(null);
  });

  testWidgets(
    'PantallaInicial muestra PantallaCarga mientras no hay respuesta de auth',
    (tester) async {
      await tester.pumpWidget(const TrabajitApp());

      // Antes del primer frame post-pump, el StreamBuilder está en
      // ConnectionState.waiting: debe mostrarse la pantalla de carga, no
      // login ni inicio.
      expect(find.byType(PantallaCarga), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(InicioScreen), findsNothing);
    },
  );

  testWidgets(
    'PantallaInicial muestra LoginScreen cuando no hay usuario autenticado',
    (tester) async {
      await tester.pumpWidget(const TrabajitApp());
      authFalso.emitirUsuario(null);
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(InicioScreen), findsNothing);

      // Verificación de contenido real, no solo el tipo de widget: el
      // formulario de login debe estar presente con sus campos.
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
          findsOneWidget);
    },
  );

  testWidgets(
    'PantallaInicial construye InicioScreen cuando hay usuario autenticado '
    '(decisión de enrutamiento; el contenido interno de InicioScreen '
    'depende de Firestore, no mockeado en este test)',
    (tester) async {
      await tester.pumpWidget(const TrabajitApp());
      authFalso.emitirUsuario(_crearUsuarioAutenticado(authFalso));
      await tester.pump();

      // `PantallaInicial` decidió construir InicioScreen (no LoginScreen).
      expect(find.byType(InicioScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // InicioScreen intenta hablar con Firestore en su initState, que no
      // está disponible en este test: se tolera y documenta ese error en
      // vez de dejar que tumbe el test completo, porque lo que se está
      // verificando aquí es la decisión de PantallaInicial, no el
      // contenido de InicioScreen.
      final excepcion = tester.takeException();
      if (excepcion != null) {
        // ignore: avoid_print
        print(
          'Nota: InicioScreen lanzó una excepción esperada por falta de '
          'Firestore mockeado en este test ($excepcion). Se tolera '
          'intencionalmente; ver comentario al inicio del archivo.',
        );
      }
    },
  );
}
