// Test de arranque de la app: `PantallaInicial` (en lib/main.dart) decide
// entre `LoginScreen` e `InicioScreen`, mostrando `PantallaCarga` mientras
// todavía no se sabe si hay sesión.
//
// **Este archivo cambió por completo en la tarea 020** y conviene saber por
// qué, porque la versión anterior era bastante más complicada.
//
// Antes, la decisión la tomaba `FirebaseAuth.authStateChanges()`. Como el
// proyecto no tenía ninguna abstracción propia sobre `firebase_auth`, la única
// forma de probarlo era sustituir `FirebaseAuthPlatform.instance` por una
// implementación falsa —heredando de `FirebaseAuthPlatform`, `UserPlatform` y
// `MultiFactorPlatform`— y controlar a mano lo que emitía el stream de auth:
// unas 60 líneas de andamiaje para probar tres ramas de un `if`.
//
// Ahora la decisión la toma `sesionActual`, un `ValueNotifier` de Dart puro
// (lib/services/sesion_usuario.dart). El test solo le pone el estado que
// quiere probar. Ya no hace falta mockear ninguna plataforma de auth, y eso es
// una ventaja concreta de haber salido de Firebase Auth.
//
// **Lo que todavía hace falta y por qué:** `setupFirebaseCoreMocks()` sigue
// aquí porque `InicioScreen` crea en su `initState` el contador de mensajes
// sin leer (`ChatService.streamTotalNoLeidos`), y `cloud_firestore` exige una
// app de Firebase en cuanto se instancia. `chat_service` es el último servicio
// de la migración (fase 2b de ADR-0009); cuando le toque, estas líneas se van.
// Firestore en sí no está mockeado, así que ese caso comprueba la **decisión
// de enrutamiento** —que es la lógica de `PantallaInicial`— y tolera el error
// interno esperado.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trabajito/main.dart';
import 'package:trabajito/models/usuario.dart';
import 'package:trabajito/screens/inicio_screen.dart';
import 'package:trabajito/screens/login_screen.dart';
import 'package:trabajito/services/sesion_usuario.dart';
import 'package:trabajito/utils/constantes.dart';

Usuario usuarioDePrueba() => Usuario(
      uid: '4325e383-6748-49e3-b18f-ba1890356e57',
      tipoUsuario: ValoresDefecto.rolTrabajador,
      nombres: 'Ana Maria',
      apellidos: 'Lopez Diaz',
      correo: 'trabajador@trabajito.test',
      fechaRegistro: DateTime(2026, 8, 27),
      rol: ValoresDefecto.rolTrabajador,
      registroCompleto: true,
    );

/// `InicioScreen` lanza uno o varios errores de Firestore al montarse sin
/// backend de Firebase. Se descartan todos: lo que se prueba aquí es a qué
/// pantalla lleva `PantallaInicial`, no lo que hay dentro de ella.
void descartarErroresEsperados(WidgetTester tester) {
  var descartados = 0;
  while (tester.takeException() != null) {
    descartados++;
    if (descartados > 10) break; // salvaguarda: nunca debería llegar aquí
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  tearDown(() {
    // Cada test declara su propio estado; no se arrastra sesión entre ellos.
    sesionActual.comprobando();
  });

  testWidgets(
    'PantallaInicial muestra PantallaCarga mientras aún no se sabe si hay sesión',
    (tester) async {
      // Es el estado real al abrir la app: se está leyendo el almacén seguro
      // del dispositivo y, si había sesión, confirmándola contra el servidor.
      // Enseñar el login aquí lo haría parpadear en cada arranque de alguien
      // que sí tiene sesión.
      sesionActual.comprobando();

      await tester.pumpWidget(const TrabajitApp());

      expect(find.byType(PantallaCarga), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(InicioScreen), findsNothing);
    },
  );

  testWidgets(
    'PantallaInicial muestra LoginScreen cuando no hay sesión',
    (tester) async {
      sesionActual.salir();

      await tester.pumpWidget(const TrabajitApp());

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(InicioScreen), findsNothing);

      // Verificación de contenido real, no solo el tipo de widget.
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
          findsOneWidget);
    },
  );

  testWidgets(
    'pasar de comprobando a sinSesion cambia la pantalla sin reconstruir la app',
    (tester) async {
      sesionActual.comprobando();
      await tester.pumpWidget(const TrabajitApp());
      expect(find.byType(PantallaCarga), findsOneWidget);

      // Esto es lo que hace `AuthService.restaurarSesion()` cuando no
      // encuentra nada guardado en el dispositivo.
      sesionActual.salir();
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(PantallaCarga), findsNothing);
    },
  );

  testWidgets(
    'PantallaInicial construye InicioScreen cuando hay sesión '
    '(decisión de enrutamiento; el contenido de InicioScreen depende de '
    'Firestore, que aquí no está mockeado)',
    (tester) async {
      sesionActual.entrar(usuarioDePrueba());

      await tester.pumpWidget(const TrabajitApp());

      expect(find.byType(InicioScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      descartarErroresEsperados(tester);
    },
  );

  testWidgets(
    'cerrar sesión devuelve a LoginScreen',
    (tester) async {
      sesionActual.entrar(usuarioDePrueba());
      await tester.pumpWidget(const TrabajitApp());
      descartarErroresEsperados(tester);

      // Es lo que ocurre tanto al pulsar "cerrar sesión" como cuando el
      // cliente HTTP avisa de que el refresh token murió y `AuthService`
      // devuelve la sesión a `sinSesion`.
      sesionActual.salir();
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(InicioScreen), findsNothing);
    },
  );
}
