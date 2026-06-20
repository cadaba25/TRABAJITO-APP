import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/inicio_screen.dart';
import 'screens/login_screen.dart';
import 'utils/constantes.dart';
import 'widgets/logo_trabajito.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp();
  runApp(const TrabajitApp());
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

class PantallaInicial extends StatelessWidget {
  const PantallaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PantallaCarga();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const InicioScreen();
        }
        return const LoginScreen();
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
              style: GoogleFonts.sora(
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


