import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/sesion_usuario.dart';
import '../utils/constantes.dart';
import 'publicar_trabajo_screen.dart';
import 'tabs/chats_tab.dart';
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
  late final Stream<int> _noLeidosStream;

  static const _titulos = ['Trabajos', 'Trabajadores', 'Chats', 'Ranking semanal', 'Perfil'];

  @override
  void initState() {
    super.initState();
    // El contador de no leídos sigue viniendo de Firestore: `chat_service` es
    // el último de la fila en la migración (fase 2b de ADR-0009).
    _noLeidosStream = ChatService().streamTotalNoLeidos(_authService.uidActual);
  }

  void _alternarTema() => notificadorTema.value = !notificadorTema.value;

  Widget _iconoChats(Widget icono) {
    return StreamBuilder<int>(
      stream: _noLeidosStream,
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return Badge(
          isLabelVisible: n > 0,
          backgroundColor: AppColores.acento,
          label: Text('$n', style: const TextStyle(color: Colors.white)),
          child: icono,
        );
      },
    );
  }

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
    // Antes esto era un `StreamBuilder` sobre el documento del usuario en
    // Firestore, que se refrescaba solo. Contra HTTP no hay documento en vivo:
    // el perfil vive en `sesionActual` y se recarga al arrancar y después de
    // cada edición (decisión del `tech-lead` para la fase 2: carga puntual en
    // vez de sondeo, ver la tarea 018).
    return ValueListenableBuilder<EstadoSesion>(
      valueListenable: sesionActual,
      builder: (context, estado, _) {
        _usuario = estado.usuario ?? _usuario;
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

    // Solo se construye la pestaña visible: reduce memoria y listeners de
    // Firestore activos (importante en dispositivos de bajos recursos y a escala).
    final Widget cuerpo;
    switch (_indice) {
      case 1: cuerpo = const TrabajadoresTab(); break;
      case 2: cuerpo = ChatsTab(usuario: usuario); break;
      case 3: cuerpo = const RankingTab(); break;
      case 4: cuerpo = PerfilTab(usuario: usuario); break;
      default: cuerpo = TrabajosTab(usuario: usuario);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _indice == 0 ? AppTextos.nombreApp : _titulos[_indice],
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
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
      body: cuerpo,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indice,
        onTap: (i) => setState(() => _indice = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: superficie,
        selectedItemColor: AppColores.acento,
        unselectedItemColor: AppColores.grisMedio,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            activeIcon: Icon(Icons.work_rounded),
            label: 'Trabajos',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Trabajadores',
          ),
          BottomNavigationBarItem(
            icon: _iconoChats(const Icon(Icons.forum_outlined)),
            activeIcon: _iconoChats(const Icon(Icons.forum_rounded)),
            label: 'Chats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events_rounded),
            label: 'Ranking',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
