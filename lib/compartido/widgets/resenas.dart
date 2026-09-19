import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../compartido/modelos/calificacion.dart';
import '../../funcionalidades/calificaciones/datos/calificacion_service.dart';
import '../../nucleo/tema/app_colores.dart';
import '../../nucleo/tema/colores_por_tema.dart';
import 'estrellas.dart';

/// Resumen grande y estético del promedio de calificaciones (0 a 5).
class ResumenCalificacion extends StatelessWidget {
  final double valor;
  final int total;
  const ResumenCalificacion({super.key, required this.valor, required this.total});

  @override
  Widget build(BuildContext context) {
    final sinResenas = total == 0;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              sinResenas ? '—' : valor.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: AppColores.dorado,
                  height: 1),
            ),
            const SizedBox(height: 4),
            Text('de 5',
                style: TextStyle(fontSize: 11, color: colorTextoSuave(context))),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (i) {
                  final llena = i < valor.floor();
                  final media = !llena && i < valor;
                  return Icon(
                    media ? LucideIcons.starHalf : LucideIcons.star,
                    // Mismo motivo que en estrellas.dart: Lucide no tiene
                    // una "estrella rellena" distinta de la vacía, así que
                    // el color es lo único que distingue llena de vacía.
                    color: (llena || media)
                        ? AppColores.dorado
                        : AppColores.grisMedio,
                    size: 26,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                sinResenas
                    ? 'Aún sin reseñas'
                    : '$total ${total == 1 ? 'reseña' : 'reseñas'}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorTextoSuave(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sección de reseñas recibidas por un usuario (referencias).
///
/// Carga puntual contra `GET /api/calificaciones/usuario/{id}` (tarea 052):
/// sin stream. Si falla, lo dice en vez de fingir "sin reseñas".
class SeccionResenas extends StatefulWidget {
  final String uid;
  const SeccionResenas({super.key, required this.uid});

  @override
  State<SeccionResenas> createState() => _SeccionResenasState();
}

class _SeccionResenasState extends State<SeccionResenas> {
  late final Future<List<Calificacion>> _resenas =
      context.read<CalificacionService>().listarDe(widget.uid);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Calificacion>>(
      future: _resenas,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
                child: CircularProgressIndicator(color: AppColores.acento)),
          );
        }
        if (snap.hasError) {
          return Text('No pudimos cargar las reseñas.',
              style: TextStyle(color: colorTextoSuave(context), fontSize: 13));
        }
        final resenas = snap.data ?? [];
        if (resenas.isEmpty) {
          return Text('Todavía no tiene reseñas.',
              style: TextStyle(color: colorTextoSuave(context), fontSize: 13));
        }
        return Column(
          children: resenas.map((r) => _TarjetaResena(resena: r)).toList(),
        );
      },
    );
  }
}

class _TarjetaResena extends StatelessWidget {
  final Calificacion resena;
  const _TarjetaResena({required this.resena});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorSuperficie(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorBorde(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColores.acento.withOpacity(0.15),
                child: Text(
                  resena.deNombre.isNotEmpty
                      ? resena.deNombre[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColores.acento,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  resena.deNombre.isEmpty ? 'Anónimo' : resena.deNombre,
                  style: TextStyle(
                      color: colorTextoFuerte(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
              Estrellas(
                  valor: resena.estrellas.toDouble(),
                  tamano: 14,
                  mostrarTexto: false),
            ],
          ),
          if (resena.comentario.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(resena.comentario,
                style: TextStyle(
                    color: colorTextoSuave(context), fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
