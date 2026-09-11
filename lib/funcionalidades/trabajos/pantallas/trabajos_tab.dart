import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/publicacion.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../postulaciones/datos/postulacion_service.dart';
import '../datos/publicacion_service.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../compartido/widgets/cambio_de_estado.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import 'detalle_trabajo_screen.dart';
import 'widgets/barra_busqueda_trabajos.dart';
import 'widgets/encabezado_feed.dart';
import 'widgets/estados_feed.dart';
import 'widgets/hoja_filtros_trabajos.dart';
import 'widgets/tarjeta_trabajo.dart';
import 'widgets/toggle_feed_trabajos.dart';

/// Pestaña "Trabajos": el feed de publicaciones.
///
/// **Ya no hay `Stream`.** Antes eran dos, de Firestore, que se refrescaban
/// solos y en los que "cargar más" significaba volver a pedirlo todo con un
/// límite mayor. Ahora es carga puntual contra `GET /api/trabajos`, que pagina
/// de verdad: se piden páginas y se van sumando, y se recarga deslizando hacia
/// abajo (decisión del `tech-lead` para la fase 2; ver tarea 018). Nada de
/// sondeo: el tiempo real se reserva para el chat.
class TrabajosTab extends StatefulWidget {
  final Usuario usuario;
  const TrabajosTab({super.key, required this.usuario});

  @override
  State<TrabajosTab> createState() => _TrabajosTabState();
}

class _TrabajosTabState extends State<TrabajosTab> {
  late final _pubService = context.read<PublicacionService>();
  late final _postService = context.read<PostulacionService>();
  final _scrollCtrl = ScrollController();

  /// Ids de trabajos a los que este trabajador ya se postuló. Se piden una vez
  /// (una sola petición para todo el feed) y se vuelven a pedir al recargar.
  final Set<String> _postuladas = {};

  final List<Publicacion> _publicaciones = [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = false;
  int _siguientePagina = 0;
  Object? _error;

  bool _soloMias = false;
  String _busqueda = '';
  String _plazoFiltro = '';
  String _categoriaFiltro = '';
  String _deptoFiltro = '';

  /// Primera carga o recarga completa. Deja la lista consistente incluso si
  /// falla: o hay datos, o hay un error que se puede reintentar deslizando.
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _leerPrimeraPagina();
      if (!mounted) return;
      setState(() {
        _publicaciones
          ..clear()
          ..addAll(lista);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e;
        _publicaciones.clear();
        _hayMas = false;
      });
    }
    await _cargarPostuladas();
  }

  Future<List<Publicacion>> _leerPrimeraPagina() async {
    if (_soloMias) {
      // `GET /api/trabajos/mios` no pagina: llega la lista entera.
      _hayMas = false;
      _siguientePagina = 0;
      return _pubService.misPublicaciones();
    }
    final pagina = await _pubService.listarFeed(pagina: 0);
    _hayMas = pagina.hayMas;
    _siguientePagina = 1;
    return pagina.elementos;
  }

  /// Página siguiente del feed, al llegar al final de la lista.
  Future<void> _cargarMas() async {
    if (_cargandoMas || !_hayMas || _soloMias) return;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await _pubService.listarFeed(pagina: _siguientePagina);
      if (!mounted) return;
      setState(() {
        // Sin este filtro, un trabajo publicado entre dos peticiones desplaza
        // la paginación y repite elementos: el mismo trabajo saldría dos veces
        // con dos claves de widget iguales.
        final vistos = _publicaciones.map((p) => p.id).toSet();
        _publicaciones
            .addAll(pagina.elementos.where((p) => !vistos.contains(p.id)));
        _hayMas = pagina.hayMas;
        _siguientePagina += 1;
        _cargandoMas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoMas = false;
        // No se borra lo que ya está en pantalla por no poder traer más: solo
        // se deja de ofrecer "cargar más" hasta la próxima recarga.
        _hayMas = false;
      });
      final mensaje =
          e is ExcepcionApi ? e.mensaje : MensajesError.errorGeneral;
      if (mounted) mostrarSnackBar(context, mensaje, esError: true);
    }
  }

  /// A qué trabajos ya se postuló. Solo tiene sentido para trabajadores.
  Future<void> _cargarPostuladas() async {
    if (widget.usuario.esEmpleador) return;
    try {
      final ids = await _postService.idsDeTrabajosPostulados();
      if (!mounted) return;
      setState(() => _postuladas
        ..clear()
        ..addAll(ids));
    } catch (e) {
      // Que falle esto no puede tumbar el feed: como mucho, una tarjeta dirá
      // "Postularme" cuando ya se postuló, y el servidor responderá 409.
      debugPrint('No se pudieron cargar las postulaciones propias: $e');
    }
  }

  bool _coincide(Publicacion p) {
    if (_plazoFiltro.isNotEmpty && p.plazo != _plazoFiltro) return false;
    if (_categoriaFiltro.isNotEmpty && p.categoria != _categoriaFiltro) return false;
    if (_deptoFiltro.isNotEmpty && p.departamento != _deptoFiltro) return false;
    if (_busqueda.trim().isEmpty) return true;
    final q = _busqueda.toLowerCase();
    return p.titulo.toLowerCase().contains(q) ||
        p.descripcion.toLowerCase().contains(q) ||
        p.categoria.toLowerCase().contains(q) ||
        p.ubicacion.toLowerCase().contains(q);
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_alHacerScroll);
    _cargar();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_alHacerScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _alHacerScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 400) {
      _cargarMas();
    }
  }

  /// Al volver del detalle se recarga: allí se puede haber publicado una
  /// postulación, aceptado a alguien o cerrado el trabajo, y sin stream nadie
  /// lo cuenta.
  Future<void> _abrirDetalle(Publicacion p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetalleTrabajoScreen(publicacion: p, usuario: widget.usuario),
      ),
    );
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final esEmpleador = widget.usuario.esEmpleador;

    return Column(
      children: [
        BarraBusquedaTrabajos(
          oscuro: oscuro,
          filtrosActivos:
              _categoriaFiltro.isNotEmpty || _deptoFiltro.isNotEmpty,
          plazoActivo: _plazoFiltro,
          onBusquedaCambia: (v) => setState(() => _busqueda = v),
          onPlazoCambia: (v) => setState(() => _plazoFiltro = v),
          onAbrirFiltros: _abrirFiltros,
        ),
        if (esEmpleador)
          ToggleFeedTrabajos(
            soloMias: _soloMias,
            onCambia: (v) {
              if (v == _soloMias) return;
              setState(() => _soloMias = v);
              _cargar();
            },
          ),
        Expanded(child: _feed(oscuro, esEmpleador)),
      ],
    );
  }

  void _abrirFiltros() {
    abrirHojaFiltrosTrabajos(
      context,
      categoria: _categoriaFiltro,
      departamento: _deptoFiltro,
      onLimpiar: () => setState(() {
        _categoriaFiltro = '';
        _deptoFiltro = '';
        _plazoFiltro = '';
      }),
      onAplicar: (cat, depto) => setState(() {
        _categoriaFiltro = cat;
        _deptoFiltro = depto;
      }),
    );
  }

  Widget _feed(bool oscuro, bool esEmpleador) {
    final cargandoInicial = _cargando && _publicaciones.isEmpty;
    return CambioDeEstado(
      child: cargandoInicial
          ? const Center(
              key: ValueKey('cargando'),
              child: CircularProgressIndicator(color: AppColores.acento))
          : _listaFeed(oscuro, esEmpleador),
    );
  }

  Widget _listaFeed(bool oscuro, bool esEmpleador) {
    final posts = _publicaciones.where(_coincide).toList();
    // El indicador de "cargando más" es una fila más al final de la lista.
    final extra = (_cargandoMas || _hayMas) && !_soloMias ? 1 : 0;

    return RefreshIndicator(
      key: const ValueKey('feed'),
      color: AppColores.acento,
      onRefresh: _cargar,
      child: ListView.builder(
        controller: _scrollCtrl,
        // Deslizar para actualizar tiene que funcionar aunque el contenido
        // quepa entero en la pantalla (lista vacía, o un solo trabajo).
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: posts.isEmpty ? 2 : posts.length + 1 + extra,
        itemBuilder: (context, index) {
          if (index == 0) {
            return EncabezadoFeed(
                usuario: widget.usuario, esEmpleador: esEmpleador);
          }
          if (posts.isEmpty) {
            return CambioDeEstado(
              child: _error != null
                  ? EstadoErrorFeed(
                      key: const ValueKey('error'), error: _error, oscuro: oscuro)
                  : EstadoVacioFeed(
                      key: const ValueKey('vacio'),
                      oscuro: oscuro,
                      esEmpleador: esEmpleador),
            );
          }
          if (index == posts.length + 1) return const PieDeCargaFeed();
          return TarjetaTrabajo(
            publicacion: posts[index - 1],
            oscuro: oscuro,
            esEmpleador: esEmpleador,
            yaPostulado: _postuladas.contains(posts[index - 1].id),
            onAbrir: () => _abrirDetalle(posts[index - 1]),
          );
        },
      ),
    );
  }
}
