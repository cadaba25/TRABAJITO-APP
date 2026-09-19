import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../autenticacion/datos/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../../compartido/widgets/boton_destructivo.dart';
import '../../../compartido/widgets/boton_icono.dart';
import '../../../compartido/widgets/boton_texto.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/sesion/sesion_usuario.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import '../../../nucleo/tema/notificador_tema.dart';
import '../../../nucleo/textos/app_textos.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import '../../trabajos/pantallas/publicar_trabajo_screen.dart';
import '../../../screens/tabs/chats_tab.dart';
import '../../perfil/pantallas/perfil_tab.dart';
import '../../perfil/pantallas/ranking_tab.dart';
import '../../perfil/pantallas/trabajadores_tab.dart';
import '../../trabajos/pantallas/trabajos_tab.dart';

/// Pantalla principal con navegación inferior:
/// Trabajos · Trabajadores · Ranking semanal.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  /// Inyectado por `provider` (ADR-0014). `context.read` es válido en
  /// `initState`, que es donde se usa por primera vez (contador de no leídos).
  late final AuthService _authService = context.read<AuthService>();
  Usuario? _usuario;

  /// El perfil que se está enseñando se restauró del dispositivo y no se pudo
  /// confirmar contra el servidor (`EstadoSesion.avisoSinConexion`). La
  /// pestaña Perfil lo avisa y ofrece recargar; ver la tarea 023.
  bool _perfilSinConfirmar = false;
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
    final tt = Theme.of(context).textTheme;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
        title: Text('¿Cerrar sesión?',
            style: tt.subtitulo.copyWith(color: colorTextoFuerte(ctx))),
        content: Text('Se cerrará tu sesión actual.',
            style: tt.cuerpo.copyWith(color: colorTextoSuave(ctx))),
        actions: [
          BotonTexto(
            texto: 'Cancelar',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          BotonDestructivo(
            texto: 'Salir',
            onPressed: () => Navigator.pop(ctx, true),
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
        if (estado.usuario != null) {
          _usuario = estado.usuario;
          _perfilSinConfirmar = estado.avisoSinConexion;
        }
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
      case 4:
        cuerpo = PerfilTab(
            usuario: usuario, datosSinConfirmar: _perfilSinConfirmar);
        break;
      default: cuerpo = TrabajosTab(usuario: usuario);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _indice == 0 ? AppTextos.nombreApp : _titulos[_indice],
          style: Theme.of(context).textTheme.titulo,
        ),
        actions: [
          BotonIcono(
            onPressed: _alternarTema,
            icono: oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
          ),
          BotonIcono(
            onPressed: _cerrarSesion,
            icono: Icons.logout_rounded,
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
              label: Text('Publicar',
                  style: Theme.of(context)
                      .textTheme
                      .cuerpo
                      .copyWith(fontWeight: FontWeight.w700)),
            )
          : null,
      body: cuerpo,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indice,
        onTap: (i) => setState(() => _indice = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: superficie,
        // Tiñe el ícono seleccionado (las etiquetas están ocultas): mismo
        // contraste corregido que el resto sobre `superficie` clara (tarea
        // 051); en modo oscuro sigue siendo el dorado normal.
        selectedItemColor: colorAcentoTexto(context),
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
