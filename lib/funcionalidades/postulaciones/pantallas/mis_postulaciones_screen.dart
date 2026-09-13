import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/postulacion.dart';
import '../../../compartido/modelos/publicacion.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../datos/postulacion_service.dart';
import '../../trabajos/datos/publicacion_service.dart';
import '../../../nucleo/dominio/estados.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import '../../../compartido/widgets/cambio_de_estado.dart';
import '../../../compartido/widgets/ejecutar_con_carga.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../compartido/widgets/pulsa_con_escala.dart';
import '../../trabajos/pantallas/detalle_trabajo_screen.dart';

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
  late final _postService = context.read<PostulacionService>();
  late final _pubService = context.read<PublicacionService>();

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
        title: Text('Mis postulaciones',
            style: Theme.of(context).textTheme.titulo),
      ),
      body: _cuerpo(oscuro),
    );
  }

  Widget _cuerpo(bool oscuro) {
    final cargandoInicial = _cargando && _postulaciones.isEmpty;
    return CambioDeEstado(
      child: cargandoInicial
          ? const Center(
              key: ValueKey('cargando'),
              child: CircularProgressIndicator(color: AppColores.acento))
          : _listaConEstado(oscuro),
    );
  }

  Widget _listaConEstado(bool oscuro) {
    final tt = Theme.of(context).textTheme;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return RefreshIndicator(
      key: const ValueKey('feed'),
      color: AppColores.acento,
      onRefresh: _cargar,
      child: CambioDeEstado(
        child: _postulaciones.isEmpty
            ? ListView(key: const ValueKey('vacio-o-error'), children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: _error == null
                      ? _estadoVacio(oscuro)
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppEspaciado.xxl),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_off_rounded,
                                    size: 56, color: AppColores.grisMedio),
                                const SizedBox(height: AppEspaciado.md),
                                Text(
                                  _error is ExcepcionApi
                                      ? (_error as ExcepcionApi).mensaje
                                      : MensajesError.errorGeneral,
                                  textAlign: TextAlign.center,
                                  style: tt.cuerpo.copyWith(
                                      color: textoSec,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: AppEspaciado.sm),
                                Text('Desliza hacia abajo para reintentar',
                                    style: tt.etiqueta
                                        .copyWith(color: AppColores.grisMedio)),
                              ],
                            ),
                          ),
                        ),
                ),
              ])
            : ListView.builder(
                key: const ValueKey('contenido'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppEspaciado.lg,
                    AppEspaciado.lg, AppEspaciado.lg, AppEspaciado.xl),
                itemCount: _postulaciones.length,
                itemBuilder: (context, i) =>
                    _tarjeta(_postulaciones[i], oscuro),
              ),
      ),
    );
  }

  Widget _tarjeta(Postulacion p, bool oscuro) {
    final tt = Theme.of(context).textTheme;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;

    return PulsaConEscala(
      onTap: () => _abrir(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppEspaciado.md),
        padding: const EdgeInsets.all(AppEspaciado.lg),
        decoration: BoxDecoration(
          color: superficie,
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
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
                    style: tt.cuerpo.copyWith(
                        color: textoPrincipal, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: AppEspaciado.sm),
                _badge(p.estado),
              ],
            ),
            const SizedBox(height: AppEspaciado.sm),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: textoSec),
                const SizedBox(width: AppEspaciado.xs),
                Text(p.tiempoRelativo, style: tt.etiqueta.copyWith(color: textoSec)),
                const Spacer(),
                if (p.estado == EstadosPostulacion.pendiente)
                  TextButton(
                    onPressed: () => _retirar(p),
                    style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppEspaciado.sm),
                        minimumSize: const Size(0, 32)),
                    child: Text('Retirar',
                        style: tt.cuerpoChico.copyWith(color: AppColores.error)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String estado) {
    final tt = Theme.of(context).textTheme;
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.md, vertical: AppEspaciado.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadios.chip),
      ),
      child: Text(texto,
          style: tt.etiqueta.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _estadoVacio(bool oscuro) {
    final tt = Theme.of(context).textTheme;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.send_outlined, size: 56, color: AppColores.grisMedio),
          const SizedBox(height: AppEspaciado.md),
          Text('Todavía no te has postulado a ningún trabajo.',
              textAlign: TextAlign.center,
              style: tt.cuerpo.copyWith(color: textoSec, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
