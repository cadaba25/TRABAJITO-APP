import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/publicacion.dart';
import '../../../compartido/modelos/usuario.dart';
import '../datos/publicacion_service.dart';
import '../../../nucleo/dominio/estados.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../compartido/widgets/boton_destructivo.dart';
import '../../../compartido/widgets/boton_texto.dart';
import '../../../compartido/widgets/cambio_de_estado.dart';
import '../../../compartido/widgets/ejecutar_con_carga.dart';
import 'detalle_trabajo_screen.dart';
import 'publicar_trabajo_screen.dart';
import 'widgets/estados_mis_publicaciones.dart';
import 'widgets/tarjeta_mi_publicacion.dart';

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
  late final _servicio = context.read<PublicacionService>();

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
        title: Text('¿Cerrar la publicación?', style: Theme.of(ctx).textTheme.subtitulo),
        content: const Text(
            'Dejará de recibir postulaciones y las pendientes se rechazarán.\n\n'
            'No se puede volver a abrir: tendrías que publicarla de nuevo.'),
        actions: [
          BotonTexto(
            texto: 'No',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          BotonDestructivo(
            texto: 'Cerrar',
            onPressed: () => Navigator.pop(ctx, true),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
        title: Text('Las publicaciones no se borran', style: Theme.of(ctx).textTheme.subtitulo),
        content: const Text(MensajesError.sinBorradoDeTrabajo),
        actions: [
          BotonTexto(
            texto: 'Entendido',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          if (p.estado == EstadosTrabajo.activo)
            BotonDestructivo(
              texto: 'Cerrarla',
              onPressed: () => Navigator.pop(ctx, true),
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
        title: Text('Mis publicaciones', style: Theme.of(context).textTheme.titulo),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaPublicacion,
        backgroundColor: AppColores.acento,
        foregroundColor: AppColores.blanco,
        icon: const Icon(Icons.add_rounded),
        label: Text('Publicar',
            style: Theme.of(context).textTheme.cuerpo.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: _cuerpo(oscuro),
    );
  }

  Widget _cuerpo(bool oscuro) {
    final cargandoInicial = _cargando && _publicaciones.isEmpty;
    return CambioDeEstado(
      child: cargandoInicial
          ? const Center(
              key: ValueKey('cargando'),
              child: CircularProgressIndicator(color: AppColores.acento))
          : _listaConEstado(oscuro),
    );
  }

  Widget _listaConEstado(bool oscuro) {
    return RefreshIndicator(
      key: const ValueKey('feed'),
      color: AppColores.acento,
      onRefresh: _cargar,
      child: CambioDeEstado(
        child: _publicaciones.isEmpty
            // El `RefreshIndicator` necesita algo desplazable para
            // dispararse; sin esto no se podría reintentar con la lista vacía.
            ? ListView(key: const ValueKey('vacio-o-error'), children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: _error != null
                      ? EstadoErrorMisPublicaciones(error: _error, oscuro: oscuro)
                      : EstadoVacioMisPublicaciones(oscuro: oscuro),
                ),
              ])
            : ListView.builder(
                key: const ValueKey('contenido'),
                physics: const AlwaysScrollableScrollPhysics(),
                // 90 (no un rol): hueco de la barra de navegación inferior.
                padding: const EdgeInsets.fromLTRB(
                    AppEspaciado.lg, AppEspaciado.lg, AppEspaciado.lg, 90),
                itemCount: _publicaciones.length,
                itemBuilder: (context, i) =>
                    _tarjeta(_publicaciones[i], oscuro),
              ),
      ),
    );
  }

  Widget _tarjeta(Publicacion p, bool oscuro) {
    return TarjetaMiPublicacion(
      publicacion: p,
      oscuro: oscuro,
      onAbrir: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DetalleTrabajoScreen(publicacion: p, usuario: widget.usuario),
          ),
        );
        if (mounted) await _cargar();
      },
      onCerrar: () => _cerrar(p),
      onEliminar: () => _eliminar(p),
    );
  }
}
