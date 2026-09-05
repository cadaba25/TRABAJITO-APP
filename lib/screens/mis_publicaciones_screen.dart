import 'package:flutter/material.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
import '../services/api/api_excepciones.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import 'detalle_trabajo_screen.dart';
import 'publicar_trabajo_screen.dart';

/// Publicaciones propias del contratista (`GET /api/trabajos/mios`).
///
/// **Lo que se puede hacer aquí cambió con la migración al backend** y no por
/// gusto: el servidor no expone forma de editar ni de borrar un trabajo, y un
/// trabajo cerrado no se puede reabrir. Ver `PublicacionService`. La pantalla
/// lo dice en vez de ofrecer botones que fallarían.
class MisPublicacionesScreen extends StatefulWidget {
  final Usuario usuario;
  const MisPublicacionesScreen({super.key, required this.usuario});

  @override
  State<MisPublicacionesScreen> createState() => _MisPublicacionesScreenState();
}

class _MisPublicacionesScreenState extends State<MisPublicacionesScreen> {
  final _servicio = PublicacionService();

  List<Publicacion> _publicaciones = const [];
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
      final lista = await _servicio.misPublicaciones();
      if (!mounted) return;
      setState(() {
        _publicaciones = lista;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _publicaciones = const [];
        _cargando = false;
      });
    }
  }

  /// Cierra la publicación: deja de recibir postulaciones y las que hubiera
  /// vivas quedan rechazadas (lo hace el servidor).
  ///
  /// **No se puede deshacer**: el backend no sabe reabrir un trabajo cerrado,
  /// así que se avisa antes, no después.
  Future<void> _cerrar(Publicacion p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar la publicación?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Dejará de recibir postulaciones y las pendientes se rechazarán.\n\n'
            'No se puede volver a abrir: tendrías que publicarla de nuevo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.error,
                minimumSize: const Size(100, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final ok = await ejecutarConCarga(
        context, () => _servicio.cerrarPublicacion(p.id),
        exito: 'Publicación cerrada');
    if (ok && mounted) await _cargar();
  }

  /// Antes esto borraba el documento de Firestore. El backend no lo permite —y
  /// con razón: de un trabajo cuelgan postulaciones, un chat, evidencias y a
  /// veces dinero—. Se explica y se ofrece lo que sí se puede hacer.
  Future<void> _eliminar(Publicacion p) async {
    final cerrar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Las publicaciones no se borran',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(MensajesError.sinBorradoDeTrabajo),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Entendido')),
          if (p.estado == EstadosTrabajo.activo)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.error,
                  minimumSize: const Size(100, 40)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrarla'),
            ),
        ],
      ),
    );
    if (cerrar == true && mounted) await _cerrar(p);
  }

  Future<void> _nuevaPublicacion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicarTrabajoScreen(usuario: widget.usuario),
      ),
    );
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis publicaciones',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaPublicacion,
        backgroundColor: AppColores.acento,
        foregroundColor: AppColores.blanco,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Publicar',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _cuerpo(oscuro),
    );
  }

  Widget _cuerpo(bool oscuro) {
    if (_cargando && _publicaciones.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColores.acento));
    }
    return RefreshIndicator(
      color: AppColores.acento,
      onRefresh: _cargar,
      child: _publicaciones.isEmpty
          // El `RefreshIndicator` necesita algo desplazable para dispararse;
          // sin esto no se podría reintentar con la lista vacía.
          ? ListView(children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: _error != null ? _estadoError(oscuro) : _estadoVacio(oscuro),
              ),
            ])
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: _publicaciones.length,
              itemBuilder: (context, i) => _tarjeta(_publicaciones[i], oscuro),
            ),
    );
  }

  Widget _estadoError(bool oscuro) {
    final error = _error;
    final mensaje =
        error is ExcepcionApi ? error.mensaje : MensajesError.errorGeneral;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColores.grisMedio),
            const SizedBox(height: 14),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: textoSec, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Desliza hacia abajo para reintentar',
                style: TextStyle(fontSize: 12, color: AppColores.grisMedio)),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(Publicacion p, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final activo = p.estado == EstadosTrabajo.activo;
    // Cerrar solo es posible antes de que el trabajo inicie (ADR-0007).
    // Después el servidor responde 409, así que no se ofrece el botón.
    final sePuedeCerrar = const [
      EstadosTrabajo.activo,
      EstadosTrabajo.asignado,
      EstadosTrabajo.acordado,
    ].contains(p.estado);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DetalleTrabajoScreen(publicacion: p, usuario: widget.usuario),
          ),
        );
        if (mounted) await _cargar();
      },
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
                  p.titulo,
                  style: TextStyle(
                      color: textoPrincipal,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3),
                ),
              ),
              const SizedBox(width: 8),
              // Badge de estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (activo ? AppColores.exito : AppColores.grisMedio)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  // Los estados ya no son dos: el backend tiene diez
                  // (ADR-0007). Enseñar "Cerrado" para un trabajo en progreso
                  // sería mentir, así que se usa la etiqueta real.
                  EstadosTrabajo.etiqueta(p.estado),
                  style: TextStyle(
                      color: activo ? AppColores.exito : AppColores.grisMedio,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            p.descripcion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textoSec, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: textoSec),
              const SizedBox(width: 4),
              Text(p.tiempoRelativo,
                  style: TextStyle(color: textoSec, fontSize: 12)),
              if (p.presupuesto.isNotEmpty) ...[
                const Spacer(),
                Text(p.presupuesto,
                    style: const TextStyle(
                        color: AppColores.acento,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: borde),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  // Sin `onPressed` el botón queda desactivado, que es la
                  // forma honesta de decir "esto ya no se puede": antes ponía
                  // "Reabrir" y no había forma de reabrir nada.
                  onPressed: sePuedeCerrar ? () => _cerrar(p) : null,
                  icon: Icon(Icons.lock_outline_rounded,
                      size: 18, color: sePuedeCerrar ? textoSec : null),
                  label: Text(sePuedeCerrar ? 'Cerrar' : 'Ya no se puede cerrar',
                      style: TextStyle(
                          color: sePuedeCerrar ? textoSec : null, fontSize: 13)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _eliminar(p),
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColores.error),
                  label: const Text('Eliminar',
                      style: TextStyle(color: AppColores.error)),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _estadoVacio(bool oscuro) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.post_add_rounded, size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text(
            'Todavía no has publicado nada.\n¡Crea tu primera publicación!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textoSec, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
