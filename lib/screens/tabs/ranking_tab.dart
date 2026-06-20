import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../utils/constantes.dart';

/// Pestaña "Ranking semanal": clasificación de profesionales por
/// cantidad de trabajos completados.
class RankingTab extends StatelessWidget {
  const RankingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final auth = AuthService();

    return StreamBuilder<List<Usuario>>(
      stream: auth.streamTrabajadores(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColores.acento));
        }
        // Solo usuarios válidos y activos (evita perfiles borrados/incompletos).
        final lista = (snapshot.data ?? [])
            .where((u) =>
                u.registroCompleto &&
                u.estado == 'activo' &&
                u.nombreCorto.trim().isNotEmpty)
            .toList()
          ..sort((a, b) {
            final cmp = b.trabajosCompletados.compareTo(a.trabajosCompletados);
            if (cmp != 0) return cmp;
            return a.nombreCompleto
                .toLowerCase()
                .compareTo(b.nombreCompleto.toLowerCase());
          });

        if (lista.isEmpty) {
          return _estadoVacio(oscuro);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: lista.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _cabecera(oscuro);
            final pos = index; // 1-based
            return _fila(lista[index - 1], pos, oscuro);
          },
        );
      },
    );
  }

  Widget _cabecera(bool oscuro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColores.principal, AppColores.azulProfesional],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColores.acento.withOpacity(0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: AppColores.acento, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Ranking semanal',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Los profesionales más destacados',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(Usuario u, int pos, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final esPodio = pos <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: esPodio ? _colorPodio(pos).withOpacity(0.6) : borde,
            width: esPodio ? 1.5 : 1),
      ),
      child: Row(
        children: [
          // Posición / medalla
          SizedBox(
            width: 34,
            child: esPodio
                ? Icon(Icons.emoji_events_rounded,
                    color: _colorPodio(pos), size: 26)
                : Text('$pos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: textoSec,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColores.acento.withOpacity(0.15),
            child: Text(
              u.iniciales,
              style: const TextStyle(
                  color: AppColores.acento,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              u.nombreCompleto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: textoPrincipal,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${u.trabajosCompletados} ${u.trabajosCompletados == 1 ? 'trabajo' : 'trabajos'}',
            style: const TextStyle(
                color: AppColores.acento,
                fontSize: 13,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Color _colorPodio(int pos) {
    switch (pos) {
      case 1: return const Color(0xFFFFD700); // oro
      case 2: return const Color(0xFFB0B7C3); // plata
      case 3: return const Color(0xFFCD7F32); // bronce
      default: return AppColores.grisMedio;
    }
  }

  Widget _estadoVacio(bool oscuro) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text(
            'Aún no hay profesionales en el ranking.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textoSec, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
