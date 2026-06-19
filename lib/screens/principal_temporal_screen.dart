import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';

/// Pantalla principal TEMPORAL mostrada tras completar el registro
/// o al iniciar sesión. Sirve como dashboard provisional mientras se
/// desarrollan las pantallas definitivas (publicar trabajos, buscar
/// profesionales, etc.). Se adapta según el rol del usuario.
class PrincipalTemporalScreen extends StatefulWidget {
  const PrincipalTemporalScreen({super.key});

  @override
  State<PrincipalTemporalScreen> createState() =>
      _PrincipalTemporalScreenState();
}

class _PrincipalTemporalScreenState extends State<PrincipalTemporalScreen> {
  final _authService = AuthService();

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColores.azulOscuro)),
        content: const Text('Se cerrará tu sesión actual.',
            style: TextStyle(color: AppColores.grisTexto)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.error,
              minimumSize: const Size(100, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar == true) await _authService.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: const Text(AppTextos.nombreApp,
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        backgroundColor: AppColores.azulOscuro,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout_rounded),
            tooltip: AppTextos.cerrarSesion,
          ),
        ],
      ),
      body: FutureBuilder<Usuario?>(
        future: _authService.obtenerUsuarioActual(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColores.azul));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _errorCarga();
          }
          return _contenido(snapshot.data!);
        },
      ),
    );
  }

  Widget _contenido(Usuario usuario) {
    final esEmpleador = usuario.esEmpleador;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // ── Banner de registro completado ──────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColores.exito.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColores.exito.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColores.exito, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    usuario.registroCompleto
                        ? '¡Registro completado con éxito!'
                        : 'Bienvenido de nuevo',
                    style: const TextStyle(
                        color: AppColores.azulOscuro,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tarjeta de bienvenida ──────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColores.azul, AppColores.azulOscuro],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColores.azul.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        usuario.iniciales,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        esEmpleador ? 'EMPLEADOR' : 'TRABAJADOR',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  esEmpleador ? '¡Hola!' : 'Bienvenido a Trabajito',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  usuario.nombreVisible,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  usuario.correo,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Acciones (próximamente) ────────────────────────
          Text(
            esEmpleador ? '¿Qué quieres hacer?' : 'Explora oportunidades',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColores.azulOscuro,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 16),

          if (esEmpleador) ...[
            _accion(Icons.post_add_rounded, 'Publicar un trabajo',
                'Crea una solicitud y recibe propuestas'),
            const SizedBox(height: 12),
            _accion(Icons.search_rounded, 'Buscar profesionales',
                'Encuentra el talento que necesitas'),
            const SizedBox(height: 12),
            _accion(Icons.assignment_outlined, 'Mis publicaciones',
                'Gestiona tus trabajos publicados'),
          ] else ...[
            _accion(Icons.work_outline_rounded, 'Buscar trabajos',
                'Encuentra oportunidades cerca de ti'),
            const SizedBox(height: 12),
            _accion(Icons.send_outlined, 'Mis postulaciones',
                'Revisa el estado de tus aplicaciones'),
            const SizedBox(height: 12),
            _accion(Icons.person_outline_rounded, 'Mi perfil',
                'Actualiza tu información y experiencia'),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _accion(IconData icono, String titulo, String descripcion) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Función disponible próximamente'),
            backgroundColor: AppColores.azulOscuro,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColores.grisClaro, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColores.azul.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: AppColores.azul, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColores.azulOscuro)),
                  const SizedBox(height: 2),
                  Text(descripcion,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.grisTexto,
                          height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColores.grisMedio),
          ],
        ),
      ),
    );
  }

  Widget _errorCarga() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 60, color: AppColores.grisMedio),
          const SizedBox(height: 16),
          const Text('No se pudieron cargar tus datos',
              style: TextStyle(
                  color: AppColores.grisTexto,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => setState(() {}),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
