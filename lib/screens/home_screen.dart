import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Tarjeta de bienvenida
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
                        usuario.rol.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(AppTextos.saludo,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  usuario.nombreCompleto,
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
          // Información del usuario
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColores.grisClaro, width: 1.5),
            ),
            child: Column(
              children: [
                _fila(Icons.person_outline, 'Nombre', usuario.nombreCompleto),
                _divisor(),
                _fila(Icons.email_outlined, 'Correo', usuario.correo),
                if (usuario.telefono.isNotEmpty) ...[
                  _divisor(),
                  _fila(Icons.phone_outlined, 'Teléfono', usuario.telefono),
                ],
                if (usuario.departamento.isNotEmpty) ...[
                  _divisor(),
                  _fila(Icons.location_on_outlined, 'Ubicación',
                      '${usuario.ciudad.isNotEmpty ? '${usuario.ciudad}, ' : ''}${usuario.departamento}'),
                ],
                _divisor(),
                _fila(Icons.badge_outlined, 'Rol',
                    usuario.rol[0].toUpperCase() + usuario.rol.substring(1)),
                _divisor(),
                _fila(Icons.check_circle_outline, 'Estado',
                    usuario.estado[0].toUpperCase() + usuario.estado.substring(1),
                    colorValor: AppColores.exito),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String titulo, String valor, {Color? colorValor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, color: AppColores.azul, size: 20),
          const SizedBox(width: 12),
          Text(titulo,
              style: const TextStyle(
                  color: AppColores.grisTexto,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(valor,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: colorValor ?? AppColores.azulOscuro,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _divisor() => const Divider(
      height: 1, color: AppColores.grisClaro, indent: 16, endIndent: 16);

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
