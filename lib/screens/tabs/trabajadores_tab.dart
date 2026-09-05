import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../services/api/api_excepciones.dart';
import '../../services/auth_service.dart';
import '../../utils/constantes.dart';
import '../../widgets/estrellas.dart';

/// Pestaña "Trabajadores": lista de profesionales registrados.
class TrabajadoresTab extends StatefulWidget {
  const TrabajadoresTab({super.key});

  @override
  State<TrabajadoresTab> createState() => _TrabajadoresTabState();
}

class _TrabajadoresTabState extends State<TrabajadoresTab> {
  final _authService = AuthService();

  /// Carga puntual en vez del stream de Firestore que había antes. Es la
  /// decisión del `tech-lead` para la fase 2 (ver tarea 018): sondear el
  /// servidor cada pocos segundos gastaría batería y datos móviles para
  /// enseñar una lista que apenas cambia. Se recarga al deslizar hacia abajo.
  late Future<List<Usuario>> _carga = _authService.listarTrabajadores();

  Future<void> _recargar() async {
    final futuro = _authService.listarTrabajadores();
    setState(() => _carga = futuro);
    // El `RefreshIndicator` mantiene la ruedita hasta que este `Future`
    // termina; sin esperarlo desaparecería antes de que llegue la respuesta.
    await futuro.catchError((_) => <Usuario>[]);
  }

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

  /// Habilidad o estudio principal para mostrar como subtítulo.
  String _especialidad(Usuario u) {
    if (u.experiencia.isNotEmpty) {
      final e = u.experiencia.first;
      if (e.puesto.isNotEmpty) return e.puesto;
      if (e.habilidades.isNotEmpty) return e.habilidades;
    }
    if (u.estudios.isNotEmpty && u.estudios.first.nivel.isNotEmpty) {
      return u.estudios.first.nivel;
    }
    return 'Profesional';
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Usuario>>(
      future: _carga,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColores.acento));
        }
        // Con Firestore un fallo de permisos se quedaba en un stream vacío y
        // el usuario veía "no hay trabajadores". Contra HTTP el error se puede
        // (y se debe) enseñar: `ExcepcionApi.mensaje` ya viene en español.
        if (snapshot.hasError) {
          return _estadoError(oscuro, snapshot.error!);
        }
        // Solo trabajadores válidos y activos (evita perfiles borrados/incompletos).
        final trabajadores = (snapshot.data ?? [])
            .where((u) =>
                u.registroCompleto &&
                u.estado == ValoresDefecto.estadoActivo &&
                u.nombreCorto.trim().isNotEmpty)
            .toList()
          ..sort((a, b) =>
              a.nombreCompleto.toLowerCase().compareTo(b.nombreCompleto.toLowerCase()));

        return RefreshIndicator(
          color: AppColores.acento,
          onRefresh: _recargar,
          child: trabajadores.isEmpty
              // El `RefreshIndicator` necesita un hijo desplazable para poder
              // dispararse; con la lista vacía hay que envolver el cartel en
              // uno o no se podría reintentar.
              ? ListView(children: [
                  SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: _estadoVacio(oscuro)),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: trabajadores.length,
                  itemBuilder: (context, i) => _tarjeta(trabajadores[i], oscuro),
                ),
        );
      },
    );
  }

  Widget _estadoError(bool oscuro, Object error) {
    final mensaje =
        error is ExcepcionApi ? error.mensaje : MensajesError.errorGeneral;
    return RefreshIndicator(
      color: AppColores.acento,
      onRefresh: _recargar,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 56, color: AppColores.grisMedio),
                    const SizedBox(height: 14),
                    Text(
                      mensaje,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: oscuro
                              ? AppColores.textoOscuro
                              : AppColores.texto),
                    ),
                    const SizedBox(height: 8),
                    Text('Desliza hacia abajo para reintentar',
                        style: TextStyle(
                            fontSize: 12, color: AppColores.grisMedio)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Usuario u, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final ubicacion = u.ciudad.isNotEmpty
        ? '${u.ciudad}, ${u.departamento}'
        : (u.departamento.isNotEmpty ? u.departamento : u.pais);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColores.acento.withOpacity(0.15),
            child: Text(
              u.iniciales,
              style: const TextStyle(
                  color: AppColores.acento,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.nombreCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: textoPrincipal,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  u.habilidades.isNotEmpty
                      ? u.habilidades.take(3).join(' · ')
                      : _especialidad(u),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColores.acento,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Estrellas(
                    valor: u.calificacionPromedio,
                    total: u.totalCalificaciones,
                    tamano: 13),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: textoSec),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        ubicacion.isEmpty ? 'Honduras' : ubicacion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textoSec, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _proximamente,
            icon: const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColores.grisMedio),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio(bool oscuro) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text(
            'Aún no hay trabajadores registrados.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textoSec, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
