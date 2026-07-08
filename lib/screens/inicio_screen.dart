import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import 'mis_publicaciones_screen.dart';
import 'publicar_trabajo_screen.dart';
import 'tabs/perfil_tab.dart';
import 'tabs/ranking_tab.dart';
import 'tabs/trabajadores_tab.dart';
import 'tabs/trabajos_tab.dart';

/// Pantalla principal con navegación inferior:
/// Trabajos · Trabajadores · Ranking semanal.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final _authService = AuthService();
  Usuario? _usuario;
  int _indice = 0;

  static const _titulos = ['Trabajos', 'Trabajadores', 'Ranking semanal', 'Perfil'];

  void _alternarTema() => notificadorTema.value = !notificadorTema.value;

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Se cerrará tu sesión actual.'),
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

  void _verMisPublicaciones() {
    if (_usuario == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MisPublicacionesScreen(usuario: _usuario!),
      ),
    );
  }

  void _publicarTrabajo() {
    if (_usuario == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicarTrabajoScreen(usuario: _usuario!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Usuario?>(
      stream: _authService.streamUsuarioActual(),
      builder: (context, snap) {
        _usuario = snap.data ?? _usuario;
        if (_usuario == null) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: AppColores.acento)),
          );
        }
        return _construir(context, _usuario!);
      },
    );
  }

  Widget _construir(BuildContext context, Usuario usuario) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final esEmpleador = usuario.esEmpleador;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;

    final tabs = [
      TrabajosTab(usuario: usuario),
      const TrabajadoresTab(),
      const RankingTab(),
      PerfilTab(usuario: usuario),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _indice == 0 ? AppTextos.nombreApp : _titulos[_indice],
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          if (esEmpleador)
            IconButton(
              onPressed: _verMisPublicaciones,
              icon: const Icon(Icons.assignment_outlined),
              tooltip: 'Mis publicaciones',
            ),
          IconButton(
            onPressed: _alternarTema,
            icon: Icon(
                oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
          ),
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout_rounded),
            tooltip: AppTextos.cerrarSesion,
          ),
        ],
      ),
      floatingActionButton: (esEmpleador && _indice == 0)
          ? FloatingActionButton.extended(
              onPressed: _publicarTrabajo,
              backgroundColor: AppColores.acento,
              foregroundColor: AppColores.blanco,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Publicar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: IndexedStack(index: _indice, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indice,
        onTap: (i) => setState(() => _indice = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: superficie,
        selectedItemColor: AppColores.acento,
        unselectedItemColor: AppColores.grisMedio,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            activeIcon: Icon(Icons.work_rounded),
            label: 'Trabajos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Trabajadores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events_rounded),
            label: 'Ranking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
