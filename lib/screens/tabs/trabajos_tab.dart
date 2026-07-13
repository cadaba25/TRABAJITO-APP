import 'package:flutter/material.dart';
import '../../models/publicacion.dart';
import '../../models/usuario.dart';
import '../../services/publicacion_service.dart';
import '../../utils/constantes.dart';
import '../../widgets/custom_textfield.dart';
import '../detalle_trabajo_screen.dart';

/// Pestaña "Trabajos": feed de scroll infinito con las publicaciones reales.
class TrabajosTab extends StatefulWidget {
  final Usuario usuario;
  const TrabajosTab({super.key, required this.usuario});

  @override
  State<TrabajosTab> createState() => _TrabajosTabState();
}

class _TrabajosTabState extends State<TrabajosTab> {
  final _pubService = PublicacionService();
  final _scrollCtrl = ScrollController();
  int _limite = 20;
  int _ultimoConteo = 0;
  bool _soloMias = false;
  String _busqueda = '';
  String _plazoFiltro = '';

  // Memo del stream: solo se recrea si cambian _soloMias o _limite
  // (la búsqueda/plazo filtran en cliente, sin re-suscribir).
  Stream<List<Publicacion>>? _cacheStream;
  bool? _cacheSoloMias;
  int? _cacheLimite;

  Stream<List<Publicacion>> _obtenerStream(bool esEmpleador) {
    if (_cacheStream == null ||
        _cacheSoloMias != _soloMias ||
        _cacheLimite != _limite) {
      _cacheSoloMias = _soloMias;
      _cacheLimite = _limite;
      _cacheStream = (esEmpleador && _soloMias)
          ? _pubService.streamMisPublicaciones(widget.usuario.uid)
          : _pubService.streamPublicaciones(limite: _limite);
    }
    return _cacheStream!;
  }

  bool _coincide(Publicacion p) {
    if (_plazoFiltro.isNotEmpty && p.plazo != _plazoFiltro) return false;
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
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_alHacerScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _alHacerScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 400 &&
        _ultimoConteo >= _limite) {
      setState(() => _limite += 10);
    }
  }

  void _abrirDetalle(Publicacion p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleTrabajoScreen(publicacion: p, usuario: widget.usuario),
      ),
    );
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
                ? AppColores.acento.withOpacity(0.15)
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
            color: activo ? AppColores.acento.withOpacity(0.15) : Colors.transparent,
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
          boton('Trabajos', !_soloMias, () => setState(() => _soloMias = false)),
          const SizedBox(width: 6),
          boton('Mis publicaciones', _soloMias,
              () => setState(() => _soloMias = true)),
        ],
      ),
    );
  }

  Widget _feed(bool oscuro, bool esEmpleador) {
    return StreamBuilder<List<Publicacion>>(
      stream: _obtenerStream(esEmpleador),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColores.acento));
        }
        if (snapshot.hasError) {
          return _mensajeVacio(oscuro,
              icono: Icons.cloud_off_outlined,
              texto: 'No se pudieron cargar las publicaciones');
        }
        final crudos = snapshot.data ?? [];
        _ultimoConteo = crudos.length;
        final posts = crudos.where(_coincide).toList();

        return ListView.builder(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: posts.isEmpty ? 2 : posts.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _encabezado(esEmpleador);
            if (posts.isEmpty) return _estadoVacio(oscuro, esEmpleador);
            return _tarjetaPost(posts[index - 1], oscuro, esEmpleador);
          },
        );
      },
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
              backgroundColor: Colors.white.withOpacity(0.18),
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
                        color: Colors.white.withOpacity(0.75), fontSize: 12),
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
                backgroundColor: AppColores.acento.withOpacity(0.15),
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
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
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
        color: color.withOpacity(0.12),
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
