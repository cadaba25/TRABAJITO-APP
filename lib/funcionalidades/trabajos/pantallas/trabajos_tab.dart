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
import 'widgets/colapso_barras_scroll.dart';
import 'widgets/hoja_filtros_trabajos.dart';
import 'widgets/lista_feed_trabajos.dart';
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

class _TrabajosTabState extends State<TrabajosTab>
    with SingleTickerProviderStateMixin {
  late final _pubService = context.read<PublicacionService>();
  late final _postService = context.read<PostulacionService>();
  final _scrollCtrl = ScrollController();

  /// Colapsa `BarraBusquedaTrabajos`/`ToggleFeedTrabajos` al hacer scroll
  /// (adenda 2026-09-12 a ADR-0015, tarea 039). Ver docstring de la clase.
  late final _colapsoBarras = ColapsoBarrasScroll(vsync: this);

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

  /// `true` mientras no se haya completado ninguna carga: la siguiente que
  /// termine es "la primera" y se anima con stagger (ADR-0015). Una vez
  /// gastada, ni recargar deslizando ni el toggle "Mis publicaciones" la
  /// vuelven a activar.
  bool _esPrimeraCarga = true;

  /// `true` solo durante el build que sigue a la primera carga: es lo que lee
  /// `_listaFeed` para decidir si envuelve las tarjetas en
  /// [EntradaEscalonada]. No hace falta apagarlo después: `EntradaEscalonada`
  /// no se reanima si ya se mostró (ver su propio estado).
  bool _animarPrimeraLista = false;

  /// Primera carga o recarga completa. Deja la lista consistente incluso si
  /// falla: o hay datos, o hay un error que se puede reintentar deslizando.
  Future<void> _cargar() async {
    if (!mounted) return;
    final esLaPrimera = _esPrimeraCarga;
    _esPrimeraCarga = false;
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
        _animarPrimeraLista = esLaPrimera;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e;
        _publicaciones.clear();
        _hayMas = false;
        _animarPrimeraLista = false;
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
    _colapsoBarras.dispose();
    super.dispose();
  }

  void _alHacerScroll() {
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _cargarMas();
    }
    _colapsoBarras.alHacerScroll(context, pos);
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
        SizeTransition(
          sizeFactor: _colapsoBarras.controlador,
          axisAlignment: -1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
            ],
          ),
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
          : ListaFeedTrabajos(
              scrollCtrl: _scrollCtrl,
              posts: _publicaciones.where(_coincide).toList(),
              error: _error,
              oscuro: oscuro,
              esEmpleador: esEmpleador,
              usuario: widget.usuario,
              postuladas: _postuladas,
              animarPrimeraLista: _animarPrimeraLista,
              cargandoMas: _cargandoMas,
              hayMas: _hayMas,
              soloMias: _soloMias,
              onRefresh: _cargar,
              onAbrir: _abrirDetalle,
            ),
    );
  }
}
