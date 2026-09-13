import 'package:flutter/material.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../../nucleo/api/api_excepciones.dart';
import 'package:provider/provider.dart';
import '../datos/perfil_service.dart';
import '../../../nucleo/dominio/roles.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';

/// Pestaña "Ranking semanal": clasificación de profesionales por
/// cantidad de trabajos completados.
///
/// Antes se alimentaba de `streamTrabajadores()`, un stream de Firestore con
/// todos los usuarios de rol trabajador, y ordenaba en memoria. Ahora el orden
/// lo hace el servidor: `GET /api/usuarios/ranking` devuelve los 50
/// trabajadores activos con más trabajos completados. Se conserva la
/// ordenación local porque sigue haciendo falta para desempatar por nombre.
class RankingTab extends StatefulWidget {
  const RankingTab({super.key});

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  /// Inyectado por `provider` (ADR-0014). `context.read` es válido en
  /// `initState`; se resuelve ahí, en la primera carga.
  late final PerfilService _perfilService = context.read<PerfilService>();

  /// Carga puntual + deslizar para actualizar, la decisión del `tech-lead`
  /// para la fase 2 (ver tarea 018): un ranking no cambia de un segundo a
  /// otro y sondear el servidor gastaría batería y datos para nada.
  late Future<List<Usuario>> _carga;

  @override
  void initState() {
    super.initState();
    _carga = _perfilService.listarTrabajadores();
  }

  Future<void> _recargar() async {
    final futuro = _perfilService.listarTrabajadores();
    setState(() => _carga = futuro);
    await futuro.catchError((_) => <Usuario>[]);
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Usuario>>(
      future: _carga,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColores.acento));
        }
        // Contra Firestore un fallo se veía como una lista vacía; contra HTTP
        // el error se puede enseñar, y el mensaje ya viene en español.
        if (snapshot.hasError) {
          return _envolverParaRecargar(
              _estadoError(oscuro, snapshot.error!), context);
        }
        // Solo usuarios válidos y activos (evita perfiles borrados/incompletos).
        final lista = (snapshot.data ?? [])
            .where((u) =>
                u.registroCompleto &&
                u.estado == ValoresDefecto.estadoActivo &&
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
          return _envolverParaRecargar(_estadoVacio(oscuro), context);
        }

        return RefreshIndicator(
          color: AppColores.acento,
          onRefresh: _recargar,
          child: ListView.builder(
            // El 90 (reserva para no quedar bajo el `BottomNavigationBar`) se
            // deja literal: no es un hueco entre elementos.
            padding: const EdgeInsets.fromLTRB(
                AppEspaciado.lg, AppEspaciado.lg, AppEspaciado.lg, 90),
            itemCount: lista.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _cabecera(oscuro);
              final pos = index; // 1-based
              return _fila(lista[index - 1], pos, oscuro);
            },
          ),
        );
      },
    );
  }

  /// El `RefreshIndicator` solo se dispara sobre algo desplazable: un cartel
  /// suelto no se puede arrastrar, así que hay que meterlo en un `ListView` o
  /// el usuario se quedaría sin forma de reintentar.
  Widget _envolverParaRecargar(Widget hijo, BuildContext context) {
    return RefreshIndicator(
      color: AppColores.acento,
      onRefresh: _recargar,
      child: ListView(children: [
        SizedBox(
            height: MediaQuery.of(context).size.height * 0.7, child: hijo),
      ]),
    );
  }

  Widget _estadoError(bool oscuro, Object error) {
    final mensaje =
        error is ExcepcionApi ? error.mensaje : MensajesError.errorGeneral;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppEspaciado.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColores.grisMedio),
            // 14 se deja literal: caso suelto de redondeo entre `md` y `lg`
            // ya documentado por 031/035.
            const SizedBox(height: 14),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: tt.cuerpo.copyWith(
                    color:
                        oscuro ? AppColores.textoOscuro : AppColores.texto)),
            const SizedBox(height: AppEspaciado.sm),
            Text('Desliza hacia abajo para reintentar',
                style: tt.etiqueta.copyWith(color: AppColores.grisMedio)),
          ],
        ),
      ),
    );
  }

  Widget _cabecera(bool oscuro) {
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppEspaciado.lg),
      padding: const EdgeInsets.all(AppEspaciado.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColores.principal, AppColores.azulProfesional],
        ),
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColores.acento.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(AppRadios.campo),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: AppColores.acento, size: 26),
          ),
          // 14 se deja literal: caso suelto de redondeo entre `md` y `lg`.
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ranking semanal',
                    style: tt.subtitulo
                        .copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppEspaciado.xs),
                Text('Los profesionales más destacados',
                    style: tt.etiqueta.copyWith(color: Colors.white70)),
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
    final tt = Theme.of(context).textTheme;
    final esPodio = pos <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: AppEspaciado.md),
      // El 14 horizontal se deja literal: caso suelto de redondeo entre `md`
      // y `lg`; el vertical sí coincide exacto con `md`.
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: AppEspaciado.md),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        border: Border.all(
            color: esPodio ? _colorPodio(pos).withValues(alpha: 0.6) : borde,
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
                    style: tt.subtitulo
                        .copyWith(color: textoSec, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: AppEspaciado.sm),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColores.acento.withValues(alpha: 0.15),
            child: Text(
              u.iniciales,
              style: tt.cuerpo
                  .copyWith(color: AppColores.acento, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Text(
              u.nombreCompleto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.cuerpo
                  .copyWith(color: textoPrincipal, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppEspaciado.sm),
          Text(
            '${u.trabajosCompletados} ${u.trabajosCompletados == 1 ? 'trabajo' : 'trabajos'}',
            style: tt.cuerpoChico
                .copyWith(color: AppColores.acento, fontWeight: FontWeight.w800),
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
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 56, color: AppColores.grisMedio),
          // 14 se deja literal: caso suelto de redondeo entre `md` y `lg`.
          const SizedBox(height: 14),
          Text(
            'Aún no hay profesionales en el ranking.',
            textAlign: TextAlign.center,
            style: tt.cuerpo.copyWith(color: textoSec, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
