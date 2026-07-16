import 'package:flutter/material.dart';
import '../models/postulacion.dart';
import '../models/usuario.dart';
import '../services/postulacion_service.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import 'detalle_trabajo_screen.dart';

/// Postulaciones enviadas por el trabajador y su estado.
class MisPostulacionesScreen extends StatefulWidget {
  final Usuario usuario;
  const MisPostulacionesScreen({super.key, required this.usuario});

  @override
  State<MisPostulacionesScreen> createState() => _MisPostulacionesScreenState();
}

class _MisPostulacionesScreenState extends State<MisPostulacionesScreen> {
  final _postService = PostulacionService();
  final _pubService = PublicacionService();

  Future<void> _abrir(Postulacion p) async {
    final pub = await _pubService.obtenerPublicacion(p.idPublicacion);
    if (!mounted) return;
    if (pub == null) {
      mostrarSnackBar(context, 'Esta publicación ya no está disponible',
          esError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetalleTrabajoScreen(publicacion: pub, usuario: widget.usuario),
      ),
    );
  }

  Future<void> _retirar(Postulacion p) async {
    await ejecutarConCarga(context, () => _postService.retirar(p.id),
        exito: 'Postulación retirada');
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis postulaciones',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: StreamBuilder<List<Postulacion>>(
        stream: _postService.streamMisPostulaciones(widget.usuario.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColores.acento));
          }
          final lista = snap.data ?? [];
          if (lista.isEmpty) {
            return _estadoVacio(oscuro);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: lista.length,
            itemBuilder: (context, i) => _tarjeta(lista[i], oscuro),
          );
        },
      ),
    );
  }

  Widget _tarjeta(Postulacion p, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;

    return GestureDetector(
      onTap: () => _abrir(p),
      child: Container(
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
                    p.tituloPublicacion.isEmpty
                        ? 'Trabajo'
                        : p.tituloPublicacion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: textoPrincipal,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                _badge(p.estado),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: textoSec),
                const SizedBox(width: 4),
                Text(p.tiempoRelativo,
                    style: TextStyle(color: textoSec, fontSize: 12)),
                const Spacer(),
                if (p.estado == EstadosPostulacion.pendiente)
                  TextButton(
                    onPressed: () => _retirar(p),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32)),
                    child: const Text('Retirar',
                        style: TextStyle(color: AppColores.error, fontSize: 13)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String estado) {
    Color color = AppColores.advertencia;
    String texto = 'Pendiente';
    if (estado == EstadosPostulacion.aceptada) {
      color = AppColores.verde; texto = 'Aceptada';
    } else if (estado == EstadosPostulacion.rechazada) {
      color = AppColores.error; texto = 'Rechazada';
    } else if (estado == EstadosPostulacion.retirada) {
      color = AppColores.grisMedio; texto = 'Retirada';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _estadoVacio(bool oscuro) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.send_outlined, size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text('Todavía no te has postulado a ningún trabajo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textoSec, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
