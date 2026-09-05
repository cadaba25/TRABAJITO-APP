import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/inicio_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/sesion_usuario.dart';
import 'utils/constantes.dart';
import 'widgets/logo_trabajito.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Firebase sigue arrancando porque cinco de los seis servicios todavía
  // hablan con Firestore (fase 2b de ADR-0009). La **autenticación** ya no
  // pasa por aquí: la hace el backend propio.
  await Firebase.initializeApp();
  // Lee la sesión guardada en el dispositivo y la confirma contra el servidor
  // antes de decidir qué pantalla se enseña. No se espera aquí a propósito:
  // `PantallaInicial` ya muestra la pantalla de carga mientras tanto, y así el
  // primer frame sale sin esperar a la red.
  final auth = AuthService();
  // Si el refresh token muere (caduca, lo revocan, o el backend detecta que
  // se reutilizó y revoca la familia entera), el cliente HTTP lo sabe pero la
  // interfaz no: el usuario se quedaría en una pantalla donde ya nada carga.
  // Esta suscripción es lo que hace que vuelva al login solo, que es lo que
  // Firebase daba de serie con authStateChanges().
  auth.escucharFinDeSesion();
  // ADR-0013: sin sesión confirmada, ninguna acción que cree o modifique datos
  // se ejecuta, y se le dice al usuario. La comprobación se instala aquí, en
  // un solo sitio, y la aplica `ApiClient` a toda escritura de la app.
  auth.vigilarEscriturasSinConexion();
  unawaited(auth.restaurarSesion());
  runApp(const TrabajitApp());
}

/// Deja claro que el `Future` se lanza y no se espera. Evita el aviso del
/// analizador sin tener que importar `dart:async` entero.
void unawaited(Future<void> futuro) {
  futuro.catchError((Object e) => debugPrint('Fallo al restaurar sesión: $e'));
}

class TrabajitApp extends StatelessWidget {
  const TrabajitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: notificadorTema,
      builder: (context, oscuro, _) {
        return MaterialApp(
          title: AppTextos.nombreApp,
          debugShowCheckedModeBanner: false,
          theme: AppTema.temaClaro(),
          darkTheme: AppTema.temaOscuro(),
          themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
          home: const PantallaInicial(),
        );
      },
    );
  }
}

/// Decide qué se ve al abrir la app: carga, login o la pantalla principal.
///
/// Antes lo decidía `FirebaseAuth.authStateChanges()`. Ahora lo decide
/// [sesionActual], que `AuthService.restaurarSesion()` rellena leyendo el
/// almacén seguro del dispositivo y confirmando la sesión contra
/// `GET /api/auth/yo`. Los tres estados son los mismos de antes, pero
/// explícitos: mientras la fase sea `comprobando` no se enseña el login, para
/// que no parpadee en cada arranque de un usuario que sí tiene sesión.
class PantallaInicial extends StatelessWidget {
  const PantallaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoSesion>(
      valueListenable: sesionActual,
      builder: (context, estado, _) {
        switch (estado.fase) {
          case FaseSesion.comprobando:
            return const PantallaCarga();
          case FaseSesion.conSesion:
            return const InicioScreen();
          case FaseSesion.sinSesion:
            return const LoginScreen();
        }
      },
    );
  }
}

class PantallaCarga extends StatelessWidget {
  const PantallaCarga({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.azulOscuro,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LogoInsignia(size: 88),
            const SizedBox(height: 20),
            Text(
              AppTextos.nombreApp,
              style: const TextStyle(fontFamily: 'Sora', 
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: AppColores.azulClaro, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}


