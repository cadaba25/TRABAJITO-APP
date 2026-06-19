import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/inicio_screen.dart';
import 'screens/login_screen.dart';
import 'utils/constantes.dart';

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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColores.azul, Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.work_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              AppTextos.nombreApp,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
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


