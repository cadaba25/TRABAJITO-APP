import 'package:flutter/material.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import 'publicar_trabajo_screen.dart';

/// Pantalla donde el empleador ve y gestiona sus propias publicaciones:
/// cerrar/reabrir y eliminar.
class MisPublicacionesScreen extends StatefulWidget {
  final Usuario usuario;
  const MisPublicacionesScreen({super.key, required this.usuario});

  @override
  State<MisPublicacionesScreen> createState() => _MisPublicacionesScreenState();
}

class _MisPublicacionesScreenState extends State<MisPublicacionesScreen> {
  final _servicio = PublicacionService();

  Future<void> _alternarEstado(Publicacion p) async {
    final nuevo = p.estado == 'activo' ? 'cerrado' : 'activo';
    final error = await _servicio.actualizarEstado(p.id, nuevo);
    if (!mounted) return;
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
    } else {
      mostrarSnackBar(context,
          nuevo == 'cerrado' ? 'Publicación cerrada' : 'Publicación reabierta');
    }
  }

  Future<void> _eliminar(Publicacion p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar publicación?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Esta acción no se puede deshacer.'),
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final error = await _servicio.eliminarPublicacion(p.id);
    if (!mounted) return;
    mostrarSnackBar(context, error ?? 'Publicación eliminada', esError: error != null);
  }

  Future<void> _nuevaPublicacion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicarTrabajoScreen(usuario: widget.usuario),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis publicaciones',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaPublicacion,
        backgroundColor: AppColores.acento,
        foregroundColor: AppColores.blanco,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Publicar',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<Publicacion>>(
        stream: _servicio.streamMisPublicaciones(widget.usuario.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColores.acento));
          }
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return _estadoVacio(oscuro);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: posts.length,
            itemBuilder: (context, i) => _tarjeta(posts[i], oscuro),
          );
        },
      ),
    );
  }

  Widget _tarjeta(Publicacion p, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final activo = p.estado == 'activo';

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
          Row(
            children: [
              Expanded(
                child: Text(
                  p.titulo,
                  style: TextStyle(
                      color: textoPrincipal,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3),
                ),
              ),
              const SizedBox(width: 8),
              // Badge de estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (activo ? AppColores.exito : AppColores.grisMedio)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  activo ? 'Activo' : 'Cerrado',
                  style: TextStyle(
                      color: activo ? AppColores.exito : AppColores.grisMedio,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            p.descripcion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textoSec, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: textoSec),
              const SizedBox(width: 4),
              Text(p.tiempoRelativo,
                  style: TextStyle(color: textoSec, fontSize: 12)),
              if (p.presupuesto.isNotEmpty) ...[
                const Spacer(),
                Text(p.presupuesto,
                    style: const TextStyle(
                        color: AppColores.acento,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: borde),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _alternarEstado(p),
                  icon: Icon(
                      activo
                          ? Icons.lock_outline_rounded
                          : Icons.lock_open_rounded,
                      size: 18,
                      color: textoSec),
                  label: Text(activo ? 'Cerrar' : 'Reabrir',
                      style: TextStyle(color: textoSec)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _eliminar(p),
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColores.error),
                  label: const Text('Eliminar',
                      style: TextStyle(color: AppColores.error)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio(bool oscuro) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.post_add_rounded, size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text(
            'Todavía no has publicado nada.\n¡Crea tu primera publicación!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textoSec, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
