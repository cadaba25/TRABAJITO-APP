import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/postulacion.dart';
import '../../../compartido/modelos/publicacion.dart';
import '../../perfil/datos/perfil_service.dart';
import '../datos/postulacion_service.dart';
import '../../trabajos/datos/publicacion_service.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../compartido/widgets/cambio_de_estado.dart';
import '../../../compartido/widgets/ejecutar_con_carga.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../perfil/pantallas/detalle_trabajador_screen.dart';
import 'widgets/cabecera_postulantes.dart';
import 'widgets/estados_postulantes.dart';
import 'widgets/tarjeta_postulante.dart';

/// Bandeja de postulantes de una publicación (vista del contratador).
///
/// `GET /api/postulaciones?trabajoId=...` **solo responde al dueño del
/// trabajo**; a cualquier otro le da 403. Antes eran dos streams de Firestore
/// anidados: ahora se piden el trabajo y sus postulantes de una vez, y se
/// vuelven a pedir al deslizar o después de elegir a alguien.
class PostulantesScreen extends StatefulWidget {
  final Publicacion publicacion;
  const PostulantesScreen({super.key, required this.publicacion});

  @override
  State<PostulantesScreen> createState() => _PostulantesScreenState();
}

class _PostulantesScreenState extends State<PostulantesScreen> {
  late final _postService = context.read<PostulacionService>();
  late final _pubService = context.read<PublicacionService>();
  late final _perfilService = context.read<PerfilService>();

  late Publicacion _publicacion = widget.publicacion;
  List<Postulacion> _postulantes = const [];
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
      // En paralelo: el trabajo (para saber si sigue activo y a quién se
      // asignó) y sus postulantes.
      final resultados = await Future.wait([
        _pubService.recargarPublicacion(widget.publicacion.id),
        _postService.postulantesDe(widget.publicacion.id),
      ]);
      if (!mounted) return;
      setState(() {
        _publicacion = resultados[0] as Publicacion;
        _postulantes = resultados[1] as List<Postulacion>;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  Future<void> _verPerfil(String uid) async {
    final u = await _perfilService.obtenerUsuarioPorUid(uid);
    if (!mounted) return;
    if (u == null) {
      mostrarSnackBar(context, 'No se pudo cargar el perfil', esError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalleTrabajadorScreen(usuario: u)),
    );
  }

  /// Elegir a un postulante. Lo hace **el servidor en una transacción**:
  /// asigna el trabajo, deja esta postulación aceptada, rechaza las demás y
  /// crea el chat. En Firestore eso lo cosía el cliente a mano.
  Future<void> _seleccionar(Publicacion pub, Postulacion p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Seleccionar a este trabajador?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Se asignará el trabajo a ${p.nombreTrabajador}, se rechazarán las '
            'demás postulaciones y se abrirá el chat con él.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seleccionar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final ok = await ejecutarConCarga(
        context, () => _postService.aceptar(p.id),
        exito: '¡Trabajador asignado!');
    if (ok && mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Postulantes',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: _cuerpo(oscuro),
    );
  }

  Widget _cuerpo(bool oscuro) {
    final cargandoInicial =
        _cargando && _postulantes.isEmpty && _error == null;
    return CambioDeEstado(
      child: cargandoInicial
          ? const Center(
              key: ValueKey('cargando'),
              child: CircularProgressIndicator(color: AppColores.acento))
          : _listaConEstado(oscuro),
    );
  }

  Widget _listaConEstado(bool oscuro) {
    final pub = _publicacion;
    return RefreshIndicator(
      key: const ValueKey('feed'),
      color: AppColores.acento,
      onRefresh: _cargar,
      child: CambioDeEstado(
        child: _postulantes.isEmpty
            ? ListView(key: const ValueKey('vacio-o-error'), children: [
                CabeceraPostulantes(
                    publicacion: pub, numeroPostulantes: 0, oscuro: oscuro),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _error != null
                      ? EstadoErrorPostulantes(error: _error, oscuro: oscuro)
                      : EstadoVacioPostulantes(oscuro: oscuro),
                ),
              ])
            : ListView.builder(
                key: const ValueKey('contenido'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _postulantes.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return CabeceraPostulantes(
                        publicacion: pub,
                        numeroPostulantes: _postulantes.length,
                        oscuro: oscuro);
                  }
                  return _tarjeta(pub, _postulantes[i - 1], oscuro);
                },
              ),
      ),
    );
  }

  Widget _tarjeta(Publicacion pub, Postulacion p, bool oscuro) {
    return TarjetaPostulante(
      publicacion: pub,
      postulacion: p,
      oscuro: oscuro,
      onVerPerfil: () => _verPerfil(p.uidTrabajador),
      onSeleccionar: () => _seleccionar(pub, p),
    );
  }
}
