import 'package:flutter/material.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import 'publicar_trabajo_screen.dart';

/// Pantalla principal: feed de scroll infinito con las publicaciones de
/// trabajos/servicios reales (Firestore), en contenedores minimalistas.
/// Se adapta al modo claro/oscuro y permite alternarlo.
class PrincipalTemporalScreen extends StatefulWidget {
  const PrincipalTemporalScreen({super.key});

  @override
  State<PrincipalTemporalScreen> createState() =>
      _PrincipalTemporalScreenState();
}

class _PrincipalTemporalScreenState extends State<PrincipalTemporalScreen> {
  final _authService = AuthService();
  final _pubService = PublicacionService();
  final _scrollCtrl = ScrollController();

  Usuario? _usuario;
  bool _cargandoUsuario = true;
  int _limite = 20;
  int _ultimoConteo = 0;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
    _scrollCtrl.addListener(_alHacerScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_alHacerScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuario() async {
    final u = await _authService.obtenerUsuarioActual();
    if (!mounted) return;
    setState(() {
      _usuario = u;
      _cargandoUsuario = false;
    });
  }

  void _alHacerScroll() {
    // Si llegamos cerca del final y la página está completa (probablemente
    // hay más), pedimos más resultados aumentando el límite.
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 400 &&
        _ultimoConteo >= _limite) {
      setState(() => _limite += 10);
    }
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

  void _alternarTema() => notificadorTema.value = !notificadorTema.value;

  Future<void> _publicarTrabajo() async {
    if (_usuario == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicarTrabajoScreen(usuario: _usuario!),
      ),
    );
    // El stream del feed se actualiza solo; no hace falta recargar.
  }

  void _proximamente() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Función disponible próximamente'),
        backgroundColor: AppColores.principal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final esEmpleador = _usuario?.esEmpleador ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTextos.nombreApp,
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        actions: [
          IconButton(
            onPressed: _alternarTema,
            icon: Icon(oscuro
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
          ),
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout_rounded),
            tooltip: AppTextos.cerrarSesion,
          ),
        ],
      ),
      floatingActionButton: esEmpleador
          ? FloatingActionButton.extended(
              onPressed: _publicarTrabajo,
              backgroundColor: AppColores.acento,
              foregroundColor: AppColores.blanco,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Publicar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: _cargandoUsuario
          ? const Center(
              child: CircularProgressIndicator(color: AppColores.acento))
          : StreamBuilder<List<Publicacion>>(
              stream: _pubService.streamPublicaciones(limite: _limite),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColores.acento));
                }
                if (snapshot.hasError) {
                  return _mensajeVacio(oscuro,
                      icono: Icons.cloud_off_outlined,
                      texto: 'No se pudieron cargar las publicaciones');
                }
                final posts = snapshot.data ?? [];
                _ultimoConteo = posts.length;

                return ListView.builder(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: posts.isEmpty ? 2 : posts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _encabezado(esEmpleador);
                    if (posts.isEmpty) return _estadoVacio(oscuro, esEmpleador);
                    return _tarjetaPost(posts[index - 1], oscuro);
                  },
                );
              },
            ),
    );
  }

  // ── ENCABEZADO ─────────────────────────────────────────────
  Widget _encabezado(bool esEmpleador) {
    final nombre = _usuario?.nombreVisible ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColores.secundario, AppColores.principal],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withOpacity(0.18),
              child: Text(
                _usuario?.iniciales ?? '',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800),
                  ),
                  Text(
                    esEmpleador
                        ? 'Publica un trabajo y recibe propuestas'
                        : 'Descubre nuevas oportunidades',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TARJETA DE PUBLICACIÓN ─────────────────────────────────
  Widget _tarjetaPost(Publicacion p, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final esEmpleador = _usuario?.esEmpleador ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Autor + tiempo
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColores.acento.withOpacity(0.15),
                child: Text(
                  p.autor.isNotEmpty ? p.autor[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColores.acento,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.autor.isEmpty ? 'Anónimo' : p.autor,
                  style: TextStyle(
                      color: textoPrincipal,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              Text(p.tiempoRelativo,
                  style: TextStyle(color: textoSec, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),

          // Chip de categoría
          if (p.categoria.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColores.acento.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                p.categoria,
                style: const TextStyle(
                    color: AppColores.acento,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Título
          Text(
            p.titulo,
            style: TextStyle(
                color: textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),

          // Descripción
          Text(
            p.descripcion,
            style: TextStyle(color: textoSec, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),

          // Pie: ubicación + presupuesto
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: textoSec),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    p.ubicacion.isEmpty ? 'Honduras' : p.ubicacion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textoSec, fontSize: 12)),
              ),
              if (p.presupuesto.isNotEmpty)
                Text(
                  p.presupuesto,
                  style: const TextStyle(
                      color: AppColores.acento,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Acción
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: _proximamente,
              child: Text(esEmpleador ? 'Ver detalles' : 'Postularme'),
            ),
          ),
        ],
      ),
    );
  }

  // ── ESTADO VACÍO ───────────────────────────────────────────
  Widget _estadoVacio(bool oscuro, bool esEmpleador) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: _mensajeVacio(
        oscuro,
        icono: Icons.inbox_outlined,
        texto: esEmpleador
            ? 'Aún no hay publicaciones.\n¡Publica el primer trabajo!'
            : 'Aún no hay trabajos publicados.\nVuelve pronto.',
      ),
    );
  }

  Widget _mensajeVacio(bool oscuro,
      {required IconData icono, required String texto}) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textoSec, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
