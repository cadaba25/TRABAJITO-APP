import 'package:flutter/material.dart';
import '../models/postulacion.dart';
import '../models/publicacion.dart';
import '../services/api/api_excepciones.dart';
import '../services/auth_service.dart';
import '../services/postulacion_service.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import 'detalle_trabajador_screen.dart';

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
  final _postService = PostulacionService();
  final _pubService = PublicacionService();
  final _authService = AuthService();

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
    final u = await _authService.obtenerUsuarioPorUid(uid);
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
    if (_cargando && _postulantes.isEmpty && _error == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColores.acento));
    }
    final pub = _publicacion;
    return RefreshIndicator(
      color: AppColores.acento,
      onRefresh: _cargar,
      child: _postulantes.isEmpty
          ? ListView(children: [
              _cabecera(pub, 0, oscuro),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _error != null
                    ? _estadoError(oscuro)
                    : _estadoVacio(oscuro),
              ),
            ])
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _postulantes.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _cabecera(pub, _postulantes.length, oscuro);
                return _tarjeta(pub, _postulantes[i - 1], oscuro);
              },
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

  Widget _cabecera(Publicacion pub, int n, bool oscuro) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final asignado = pub.estado != EstadosTrabajo.activo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pub.titulo,
              style: TextStyle(
                  color: oscuro ? AppColores.textoOscuro : AppColores.texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            asignado
                ? 'Trabajo asignado a ${pub.nombreTrabajadorAsignado}'
                : '$n ${n == 1 ? 'postulante' : 'postulantes'}',
            style: TextStyle(color: textoSec, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Publicacion pub, Postulacion p, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final esElegido = pub.uidTrabajadorAsignado == p.uidTrabajador;
    final trabajoActivo = pub.estado == EstadosTrabajo.activo;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: esElegido ? AppColores.verde : borde,
            width: esElegido ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColores.acento.withValues(alpha: 0.15),
                child: Text(
                  p.nombreTrabajador.isNotEmpty
                      ? p.nombreTrabajador[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColores.acento, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombreTrabajador,
                        style: TextStyle(
                            color: textoPrincipal,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text('Postuló ${p.tiempoRelativo}',
                        style: TextStyle(color: textoSec, fontSize: 12)),
                  ],
                ),
              ),
              if (esElegido)
                const Icon(Icons.check_circle_rounded,
                    color: AppColores.verde, size: 22)
              else
                _badge(p.estado),
            ],
          ),
          const SizedBox(height: 12),
          // Mensaje del postulante destacado (o aviso si no dejó mensaje).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColores.acento.withValues(alpha: oscuro ? 0.10 : 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColores.acento.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 18, color: AppColores.acento.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.mensaje.isNotEmpty
                        ? p.mensaje
                        : 'No dejó un mensaje. Revisa su perfil.',
                    style: TextStyle(
                        color: p.mensaje.isNotEmpty ? textoPrincipal : textoSec,
                        fontSize: 13,
                        height: 1.4,
                        fontStyle: p.mensaje.isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _verPerfil(p.uidTrabajador),
                  child: const Text('Ver perfil'),
                ),
              ),
              const SizedBox(width: 10),
              if (trabajoActivo)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _seleccionar(pub, p),
                    child: const Text('Seleccionar'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String estado) {
    Color color = AppColores.grisMedio;
    String texto = 'Pendiente';
    if (estado == EstadosPostulacion.aceptada) {
      color = AppColores.verde; texto = 'Aceptada';
    } else if (estado == EstadosPostulacion.rechazada) {
      color = AppColores.error; texto = 'Rechazada';
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
          const Icon(Icons.inbox_outlined, size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text('Todavía no hay postulantes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textoSec, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
