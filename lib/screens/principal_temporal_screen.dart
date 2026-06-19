import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';

/// Modelo temporal de una publicación del feed (trabajo / servicio).
/// Más adelante se reemplazará por datos reales desde Firestore.
class _Publicacion {
  final String autor;
  final String categoria;
  final String titulo;
  final String descripcion;
  final String ubicacion;
  final String presupuesto;
  final String tiempo;

  const _Publicacion({
    required this.autor,
    required this.categoria,
    required this.titulo,
    required this.descripcion,
    required this.ubicacion,
    required this.presupuesto,
    required this.tiempo,
  });
}

/// Pantalla principal TEMPORAL: feed de scroll infinito tipo red social
/// con publicaciones de trabajos/servicios en contenedores minimalistas.
/// Se adapta al modo claro/oscuro y permite alternarlo.
class PrincipalTemporalScreen extends StatefulWidget {
  const PrincipalTemporalScreen({super.key});

  @override
  State<PrincipalTemporalScreen> createState() =>
      _PrincipalTemporalScreenState();
}

class _PrincipalTemporalScreenState extends State<PrincipalTemporalScreen> {
  final _authService = AuthService();
  final _scrollCtrl = ScrollController();

  Usuario? _usuario;
  bool _cargandoUsuario = true;
  bool _cargandoMas = false;
  final List<_Publicacion> _posts = [];

  // Plantillas de ejemplo para generar el feed.
  static const List<_Publicacion> _plantillas = [
    _Publicacion(
      autor: 'María G.',
      categoria: 'Hogar y limpieza',
      titulo: 'Limpieza profunda de apartamento',
      descripcion:
          'Busco persona para limpieza profunda de apartamento de 2 habitaciones. Incluye cocina y baños.',
      ubicacion: 'Tegucigalpa, F.M.',
      presupuesto: 'L. 800',
      tiempo: 'hace 5 min',
    ),
    _Publicacion(
      autor: 'Carlos M.',
      categoria: 'Plomería',
      titulo: 'Reparación de fuga en cocina',
      descripcion:
          'Tengo una fuga debajo del fregadero. Necesito un plomero hoy mismo si es posible.',
      ubicacion: 'San Pedro Sula, Cortés',
      presupuesto: 'L. 500',
      tiempo: 'hace 20 min',
    ),
    _Publicacion(
      autor: 'Distribuidora El Sol',
      categoria: 'Transporte y mudanzas',
      titulo: 'Ayudante para mudanza el sábado',
      descripcion:
          'Necesitamos 2 personas para cargar y descargar mobiliario de oficina. Jornada de medio día.',
      ubicacion: 'La Ceiba, Atlántida',
      presupuesto: 'L. 1,200',
      tiempo: 'hace 1 h',
    ),
    _Publicacion(
      autor: 'Ana P.',
      categoria: 'Educación y tutorías',
      titulo: 'Clases de matemáticas para 9no grado',
      descripcion:
          'Busco tutor de matemáticas, 3 veces por semana, modalidad presencial o en línea.',
      ubicacion: 'Comayagua',
      presupuesto: 'L. 250/hora',
      tiempo: 'hace 2 h',
    ),
    _Publicacion(
      autor: 'José R.',
      categoria: 'Electricidad',
      titulo: 'Instalación de tomacorrientes',
      descripcion:
          'Necesito instalar 4 tomacorrientes nuevos y revisar el panel eléctrico de la casa.',
      ubicacion: 'Choloma, Cortés',
      presupuesto: 'L. 900',
      tiempo: 'hace 3 h',
    ),
    _Publicacion(
      autor: 'Cafetería Luna',
      categoria: 'Diseño y publicidad',
      titulo: 'Diseño de menú y logo',
      descripcion:
          'Cafetería nueva busca diseñador para identidad visual: logo, menú y redes sociales.',
      ubicacion: 'Tegucigalpa, F.M.',
      presupuesto: 'L. 3,000',
      tiempo: 'hace 5 h',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
    _posts.addAll(_generarLote());
    _scrollCtrl.addListener(_alHacerScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_alHacerScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuario() async {
    final u = await _authService.obtenerUsuarioActual();
    if (!mounted) return;
    setState(() {
      _usuario = u;
      _cargandoUsuario = false;
    });
  }

  void _alHacerScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 400 &&
        !_cargandoMas) {
      _cargarMas();
    }
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas) return;
    setState(() => _cargandoMas = true);
    await Future.delayed(const Duration(milliseconds: 700)); // simula red
    if (!mounted) return;
    setState(() {
      _posts.addAll(_generarLote());
      _cargandoMas = false;
    });
  }

  /// Genera un lote de publicaciones reutilizando las plantillas.
  List<_Publicacion> _generarLote() {
    return List.generate(_plantillas.length,
        (i) => _plantillas[(_posts.length + i) % _plantillas.length]);
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Se cerrará tu sesión actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.error,
              minimumSize: const Size(100, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar == true) await _authService.cerrarSesion();
  }

  void _alternarTema() => notificadorTema.value = !notificadorTema.value;

  void _proximamente() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Función disponible próximamente'),
        backgroundColor: AppColores.principal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final esEmpleador = _usuario?.esEmpleador ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTextos.nombreApp,
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        actions: [
          IconButton(
            onPressed: _alternarTema,
            icon: Icon(oscuro
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
          ),
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout_rounded),
            tooltip: AppTextos.cerrarSesion,
          ),
        ],
      ),
      floatingActionButton: esEmpleador
          ? FloatingActionButton.extended(
              onPressed: _proximamente,
              backgroundColor: AppColores.acento,
              foregroundColor: AppColores.blanco,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Publicar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: _cargandoUsuario
          ? const Center(
              child: CircularProgressIndicator(color: AppColores.acento))
          : RefreshIndicator(
              color: AppColores.acento,
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 600));
                if (!mounted) return;
                setState(() {
                  _posts
                    ..clear()
                    ..addAll(_generarLote());
                });
              },
              child: ListView.builder(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                // header + posts + indicador de carga
                itemCount: _posts.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) return _encabezado(oscuro, esEmpleador);
                  if (index == _posts.length + 1) return _pieCarga();
                  return _tarjetaPost(_posts[index - 1], oscuro);
                },
              ),
            ),
    );
  }

  // ── ENCABEZADO ─────────────────────────────────────────────
  Widget _encabezado(bool oscuro, bool esEmpleador) {
    final nombre = _usuario?.nombreVisible ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColores.secundario, AppColores.principal],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  child: Text(
                    _usuario?.iniciales ?? '',
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
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── TARJETA DE PUBLICACIÓN ─────────────────────────────────
  Widget _tarjetaPost(_Publicacion p, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;

    return Container(
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
          // Autor + tiempo
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColores.acento.withOpacity(0.15),
                child: Text(
                  p.autor.isNotEmpty ? p.autor[0] : '?',
                  style: const TextStyle(
                      color: AppColores.acento,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.autor,
                  style: TextStyle(
                      color: textoPrincipal,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              Text(p.tiempo,
                  style: TextStyle(color: textoSec, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),

          // Chip de categoría
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColores.acento.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              p.categoria,
              style: const TextStyle(
                  color: AppColores.acento,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),

          // Título
          Text(
            p.titulo,
            style: TextStyle(
                color: textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),

          // Descripción
          Text(
            p.descripcion,
            style: TextStyle(color: textoSec, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),

          // Pie: ubicación + presupuesto
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: textoSec),
              const SizedBox(width: 4),
              Expanded(
                child: Text(p.ubicacion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textoSec, fontSize: 12)),
              ),
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

          // Acción
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: _proximamente,
              child: Text(
                (_usuario?.esEmpleador ?? false) ? 'Ver detalles' : 'Postularme',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── INDICADOR DE CARGA AL FINAL ────────────────────────────
  Widget _pieCarga() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          height: 26,
          width: 26,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColores.acento),
        ),
      ),
    );
  }
}
