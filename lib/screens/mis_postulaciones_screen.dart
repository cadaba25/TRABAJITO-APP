import 'package:flutter/material.dart';
import '../models/postulacion.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
import '../services/api/api_excepciones.dart';
import '../services/postulacion_service.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import 'detalle_trabajo_screen.dart';

/// Postulaciones enviadas por el trabajador y su estado
/// (`GET /api/postulaciones/mias`).
///
/// **El título del trabajo hay que ir a buscarlo.** En Firestore viajaba
/// desnormalizado dentro de la postulación; la entidad de Postgres no lo
/// tiene, así que esta pantalla pide además cada trabajo. Es una petición por
/// postulación, y se dice claro en [_cargar] para que nadie lo copie a una
/// lista que sí pueda ser larga. La alternativa buena es que el backend añada
/// `tituloTrabajo` al DTO (anotado como pendiente en el reporte 026).
class MisPostulacionesScreen extends StatefulWidget {
  final Usuario usuario;
  const MisPostulacionesScreen({super.key, required this.usuario});

  @override
  State<MisPostulacionesScreen> createState() => _MisPostulacionesScreenState();
}

class _MisPostulacionesScreenState extends State<MisPostulacionesScreen> {
  final _postService = PostulacionService();
  final _pubService = PublicacionService();

  List<Postulacion> _postulaciones = const [];

  /// Trabajos de esas postulaciones, por id. Puede faltar alguno: que no se
  /// pueda leer un trabajo no debe dejar la lista entera sin enseñar.
  final Map<String, Publicacion> _trabajos = {};
  bool _cargando = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final lista = await _postService.misPostulaciones();
      // Una petición por trabajo, en paralelo. Aceptable porque la lista de
      // postulaciones de una persona es corta por naturaleza; si algún día
      // deja de serlo, esto hay que resolverlo en el servidor, no aquí.
      final ids = {for (final p in lista) p.idPublicacion}
        ..removeWhere((id) => id.isEmpty);
      final trabajos = await Future.wait(ids.map(_pubService.obtenerPublicacion));
      if (!mounted) return;
      setState(() {
        _postulaciones = lista;
        _trabajos
          ..clear()
          ..addEntries([
            for (final t in trabajos)
              if (t != null) MapEntry(t.id, t),
          ]);
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _postulaciones = const [];
        _cargando = false;
      });
    }
  }

  /// Título a enseñar: el del trabajo que se pudo leer, y si no, uno honesto.
  String _titulo(Postulacion p) {
    final trabajo = _trabajos[p.idPublicacion];
    if (trabajo != null && trabajo.titulo.isNotEmpty) return trabajo.titulo;
    if (p.tituloPublicacion.isNotEmpty) return p.tituloPublicacion;
    return 'Trabajo';
  }

  Future<void> _abrir(Postulacion p) async {
    final pub = _trabajos[p.idPublicacion] ??
        await _pubService.obtenerPublicacion(p.idPublicacion);
    if (!mounted) return;
    if (pub == null) {
      mostrarSnackBar(context, 'Esta publicación ya no está disponible',
          esError: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetalleTrabajoScreen(publicacion: pub, usuario: widget.usuario),
      ),
    );
    if (mounted) await _cargar();
  }

  Future<void> _retirar(Postulacion p) async {
    final ok = await ejecutarConCarga(context, () => _postService.retirar(p.id),
        exito: 'Postulación retirada');
    if (ok && mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis postulaciones',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: _cuerpo(oscuro),
    );
  }

  Widget _cuerpo(bool oscuro) {
    if (_cargando && _postulaciones.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColores.acento));
    }
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return RefreshIndicator(
      color: AppColores.acento,
      onRefresh: _cargar,
      child: _postulaciones.isEmpty
          ? ListView(children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: _error == null
                    ? _estadoVacio(oscuro)
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_rounded,
                                  size: 56, color: AppColores.grisMedio),
                              const SizedBox(height: 14),
                              Text(
                                _error is ExcepcionApi
                                    ? (_error as ExcepcionApi).mensaje
                                    : MensajesError.errorGeneral,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: textoSec,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              const Text('Desliza hacia abajo para reintentar',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColores.grisMedio)),
                            ],
                          ),
                        ),
                      ),
              ),
            ])
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _postulaciones.length,
              itemBuilder: (context, i) => _tarjeta(_postulaciones[i], oscuro),
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
                    _titulo(p),
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
        color: color.withValues(alpha: 0.15),
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
