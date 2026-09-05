import 'package:flutter/material.dart';
import '../../models/publicacion.dart';
import '../../models/usuario.dart';
import '../../services/api/api_excepciones.dart';
import '../../services/postulacion_service.dart';
import '../../services/publicacion_service.dart';
import '../../utils/constantes.dart';
import '../../widgets/custom_textfield.dart';
import '../detalle_trabajo_screen.dart';

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
  final _pubService = PublicacionService();
  final _postService = PostulacionService();
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
        _barraBusqueda(oscuro),
        if (esEmpleador) _filtro(oscuro),
        Expanded(child: _feed(oscuro, esEmpleador)),
      ],
    );
  }

  Widget _barraBusqueda(bool oscuro) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            style: TextStyle(color: colorTextoFuerte(context)),
            decoration: InputDecoration(
              hintText: 'Buscar trabajos u oficios…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: IconButton(
                onPressed: _abrirFiltros,
                icon: Icon(Icons.tune_rounded,
                    color: (_categoriaFiltro.isNotEmpty || _deptoFiltro.isNotEmpty)
                        ? AppColores.acento
                        : AppColores.grisMedio),
                tooltip: 'Filtros',
              ),
              isDense: true,
              filled: true,
              fillColor: oscuro ? AppColores.superficieOscura : AppColores.blanco,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                    color: oscuro ? AppColores.bordeOscuro : AppColores.grisClaro),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                    color: oscuro ? AppColores.bordeOscuro : AppColores.grisClaro),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filtroPlazo('Todos', ''),
                ...DatosEmpleador.plazos.map((p) => _filtroPlazo(p, p)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFiltros() {
    String cat = _categoriaFiltro;
    String depto = _deptoFiltro;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: oscuro ? AppColores.superficieOscura : AppColores.blanco,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text('Filtros',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorTextoFuerte(context))),
              ),
              const SizedBox(height: 16),
              CustomDropdown(
                label: 'Categoría',
                valor: cat.isEmpty ? null : cat,
                opciones: DatosEmpleador.sectores,
                icono: Icons.category_outlined,
                alCambiar: (v) => setSheet(() => cat = v ?? ''),
              ),
              const SizedBox(height: 14),
              CustomDropdown(
                label: 'Departamento',
                valor: depto.isEmpty ? null : depto,
                opciones: DatosHonduras.departamentos,
                icono: Icons.map_outlined,
                alCambiar: (v) => setSheet(() => depto = v ?? ''),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _categoriaFiltro = '';
                          _deptoFiltro = '';
                          _plazoFiltro = '';
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _categoriaFiltro = cat;
                          _deptoFiltro = depto;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtroPlazo(String texto, String valor) {
    final activo = _plazoFiltro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _plazoFiltro = valor),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: activo
                ? AppColores.acento.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: activo ? AppColores.acento : AppColores.grisMedio),
          ),
          child: Text(texto,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activo ? AppColores.acento : colorTextoSuave(context))),
        ),
      ),
    );
  }

  // Toggle sutil: Trabajos (todos) / Mis publicaciones (solo del contratista).
  Widget _filtro(bool oscuro) {
    Widget boton(String texto, bool activo, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: activo ? AppColores.acento.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(texto,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: activo ? AppColores.acento : colorTextoSuave(context))),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          boton('Trabajos', !_soloMias, () {
            if (_soloMias) {
              setState(() => _soloMias = false);
              _cargar();
            }
          }),
          const SizedBox(width: 6),
          boton('Mis publicaciones', _soloMias, () {
            if (!_soloMias) {
              setState(() => _soloMias = true);
              _cargar();
            }
          }),
        ],
      ),
    );
  }

  Widget _feed(bool oscuro, bool esEmpleador) {
    if (_cargando && _publicaciones.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColores.acento));
    }

    final posts = _publicaciones.where(_coincide).toList();
    // El indicador de "cargando más" es una fila más al final de la lista.
    final extra = (_cargandoMas || _hayMas) && !_soloMias ? 1 : 0;

    return RefreshIndicator(
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
          if (index == 0) return _encabezado(esEmpleador);
          if (posts.isEmpty) {
            // Con Firestore un fallo se quedaba en una lista vacía y el
            // usuario leía "aún no hay trabajos", que era falso. Contra HTTP
            // el error se puede distinguir y se debe enseñar.
            return _error != null
                ? _estadoError(oscuro)
                : _estadoVacio(oscuro, esEmpleador);
          }
          if (index == posts.length + 1) return _pieDeCarga();
          return _tarjetaPost(posts[index - 1], oscuro, esEmpleador);
        },
      ),
    );
  }

  Widget _pieDeCarga() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
              color: AppColores.acento, strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _estadoError(bool oscuro) {
    final error = _error;
    final mensaje =
        error is ExcepcionApi ? error.mensaje : MensajesError.errorGeneral;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          _mensajeVacio(oscuro,
              icono: Icons.cloud_off_outlined, texto: mensaje),
          const SizedBox(height: 8),
          const Text('Desliza hacia abajo para reintentar',
              style: TextStyle(fontSize: 12, color: AppColores.grisMedio)),
        ],
      ),
    );
  }

  Widget _encabezado(bool esEmpleador) {
    final nombre = widget.usuario.nombreVisible;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
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
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Text(
                widget.usuario.iniciales,
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
                        color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPost(Publicacion p, bool oscuro, bool esEmpleador) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;

    return GestureDetector(
      onTap: () => _abrirDetalle(p),
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
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColores.acento.withValues(alpha: 0.15),
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (p.categoria.isNotEmpty)
                _chip(p.categoria, AppColores.acento),
              if (p.plazo.isNotEmpty)
                _chip(p.plazo, AppColores.azulProfesional),
            ],
          ),
          if (p.categoria.isNotEmpty || p.plazo.isNotEmpty)
            const SizedBox(height: 10),
          Text(
            p.titulo,
            style: TextStyle(
                color: textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          Text(
            p.descripcion,
            style: TextStyle(color: textoSec, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
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
          SizedBox(
            width: double.infinity,
            child: (!esEmpleador && _postuladas.contains(p.id))
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        foregroundColor: AppColores.verde,
                        side: const BorderSide(color: AppColores.verde)),
                    onPressed: () => _abrirDetalle(p),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Ya te postulaste'),
                  )
                : OutlinedButton(
                    style:
                        OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                    onPressed: () => _abrirDetalle(p),
                    child: Text(esEmpleador ? 'Ver detalles' : 'Postularme'),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _chip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

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
