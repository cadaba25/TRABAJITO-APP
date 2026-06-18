import 'package:flutter/material.dart';
import '../utils/constantes.dart';
import 'registro/registro_trabajador_screen.dart';
import 'registro/registro_empleador_screen.dart';

/// Pantalla de bienvenida al registro
/// El usuario elige si busca trabajo o quiere contratar
class BienvenidaRegistroScreen extends StatelessWidget {
  const BienvenidaRegistroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColores.azulOscuro),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── LOGO ───────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColores.azul, AppColores.azulOscuro],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.work_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    AppTextos.nombreApp,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColores.azulOscuro,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── TÍTULO ─────────────────────────────────
              const Text(
                '¡Hola!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColores.azul,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '¿Qué te trae a Trabajito?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColores.azulOscuro,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 32),

              // ── OPCIÓN: BUSCO TRABAJO ──────────────────
              _TarjetaOpcion(
                titulo: 'Busco trabajo',
                descripcion:
                    'Te ayudamos a encontrar las oportunidades que mejor se ajusten a tu perfil y objetivos.',
                icono: Icons.search_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroTrabajadorScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ── OPCIÓN: BUSCO CONTRATAR ────────────────
              _TarjetaOpcion(
                titulo: 'Busco contratar',
                descripcion:
                    'Te ayudamos a conectar con los mejores profesionales de Honduras de acuerdo a tus necesidades.',
                icono: Icons.business_center_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroEmpleadorScreen(),
                    ),
                  );
                },
              ),

              const Spacer(),

              // ── PIE ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿Ya tienes una cuenta? ',
                      style: TextStyle(color: AppColores.grisTexto)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Inicia sesión',
                      style: TextStyle(
                        color: AppColores.azul,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaOpcion extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final VoidCallback onTap;
  final bool proximamente;

  const _TarjetaOpcion({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.onTap,
    this.proximamente = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColores.blanco,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: proximamente ? AppColores.grisClaro : AppColores.azul,
            width: 1.5,
          ),
          boxShadow: proximamente
              ? []
              : [
                  BoxShadow(
                    color: AppColores.azul.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: proximamente
                    ? AppColores.grisClaro
                    : AppColores.azul.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icono,
                color: proximamente ? AppColores.grisMedio : AppColores.azul,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: proximamente
                              ? AppColores.grisMedio
                              : AppColores.azul,
                        ),
                      ),
                      if (proximamente) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColores.grisClaro,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Pronto',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColores.grisMedio,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: TextStyle(
                      fontSize: 13,
                      color: proximamente
                          ? AppColores.grisMedio
                          : AppColores.grisTexto,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!proximamente)
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColores.azul),
          ],
        ),
      ),
    );
  }
}
