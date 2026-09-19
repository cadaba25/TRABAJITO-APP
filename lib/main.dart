import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'funcionalidades/inicio/pantallas/inicio_screen.dart';
import 'funcionalidades/autenticacion/pantallas/login_screen.dart';
import 'funcionalidades/autenticacion/datos/auth_service.dart';
import 'nucleo/inyeccion/proveedores.dart';
import 'nucleo/sesion/sesion_usuario.dart';
import 'nucleo/tema/app_colores.dart';
import 'nucleo/tema/app_tema.dart';
import 'nucleo/tema/notificador_tema.dart';
import 'nucleo/textos/app_textos.dart';
import 'compartido/widgets/logo_trabajito.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
  // El mismo `AuthService` que acaba de restaurar la sesión es el que se
  // reparte a las pantallas (ADR-0014). Antes cada una construía el suyo.
  runApp(TrabajitApp(auth: auth));
}

/// Deja claro que el `Future` se lanza y no se espera. Evita el aviso del
/// analizador sin tener que importar `dart:async` entero.
void unawaited(Future<void> futuro) {
  futuro.catchError((Object e) => debugPrint('Fallo al restaurar sesión: $e'));
}

class TrabajitApp extends StatelessWidget {
  const TrabajitApp({super.key, this.auth});

  /// Servicio de autenticación que verá toda la app. `main()` pasa el mismo que
  /// ya usó para restaurar la sesión; si no se pasa ninguno (tests de arranque)
  /// la raíz de composición construye uno perezosamente.
  final AuthService? auth;

  @override
  Widget build(BuildContext context) {
    // El `MultiProvider` va por ENCIMA de `MaterialApp` a propósito: las
    // pantallas que se abren con `Navigator.push` se construyen bajo el
    // `Navigator`, o sea dentro de `MaterialApp`, y desde ahí tienen que poder
    // seguir leyendo los servicios.
    return MultiProvider(
      providers: proveedoresDeLaApp(auth: auth),
      child: ValueListenableBuilder<bool>(
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
      ),
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


