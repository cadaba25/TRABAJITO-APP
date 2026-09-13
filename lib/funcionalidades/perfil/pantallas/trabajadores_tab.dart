import 'package:flutter/material.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../../nucleo/api/api_excepciones.dart';
import 'package:provider/provider.dart';
import '../datos/perfil_service.dart';
import '../../../nucleo/dominio/roles.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import '../../../compartido/widgets/estrellas.dart';
import '../../../compartido/widgets/pulsa_con_escala.dart';
import 'detalle_trabajador_screen.dart';

/// Pestaña "Trabajadores": lista de profesionales registrados.
class TrabajadoresTab extends StatefulWidget {
  const TrabajadoresTab({super.key});

  @override
  State<TrabajadoresTab> createState() => _TrabajadoresTabState();
}

class _TrabajadoresTabState extends State<TrabajadoresTab> {
  /// Inyectado por `provider` (ADR-0014). `context.read` es válido en
  /// `initState`; se resuelve ahí, en la primera carga.
  late final PerfilService _perfilService = context.read<PerfilService>();

  /// Carga puntual en vez del stream de Firestore que había antes. Es la
  /// decisión del `tech-lead` para la fase 2 (ver tarea 018): sondear el
  /// servidor cada pocos segundos gastaría batería y datos móviles para
  /// enseñar una lista que apenas cambia. Se recarga al deslizar hacia abajo.
  late Future<List<Usuario>> _carga;

  @override
  void initState() {
    super.initState();
    _carga = _perfilService.listarTrabajadores();
  }

  Future<void> _recargar() async {
    final futuro = _perfilService.listarTrabajadores();
    setState(() => _carga = futuro);
    // El `RefreshIndicator` mantiene la ruedita hasta que este `Future`
    // termina; sin esperarlo desaparecería antes de que llegue la respuesta.
    await futuro.catchError((_) => <Usuario>[]);
  }

  void _verPerfil(Usuario u) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalleTrabajadorScreen(usuario: u)),
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
                  // El 90 (reserva para no quedar bajo el `BottomNavigationBar`)
                  // se deja literal: no es un hueco entre elementos.
                  padding: const EdgeInsets.fromLTRB(
                      AppEspaciado.lg, AppEspaciado.lg, AppEspaciado.lg, 90),
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
    final tt = Theme.of(context).textTheme;
    return RefreshIndicator(
      color: AppColores.acento,
      onRefresh: _recargar,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppEspaciado.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 56, color: AppColores.grisMedio),
                    // 14 se deja literal: caso suelto de redondeo entre `md`
                    // y `lg` ya documentado por 031/035.
                    const SizedBox(height: 14),
                    Text(
                      mensaje,
                      textAlign: TextAlign.center,
                      style: tt.cuerpo.copyWith(
                          color: oscuro
                              ? AppColores.textoOscuro
                              : AppColores.texto,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppEspaciado.sm),
                    Text('Desliza hacia abajo para reintentar',
                        style: tt.etiqueta.copyWith(color: AppColores.grisMedio)),
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
    final tt = Theme.of(context).textTheme;
    final ubicacion = u.ciudad.isNotEmpty
        ? '${u.ciudad}, ${u.departamento}'
        : (u.departamento.isNotEmpty ? u.departamento : u.pais);

    return PulsaConEscala(
      onTap: () => _verPerfil(u),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppEspaciado.md),
        padding: const EdgeInsets.all(AppEspaciado.lg),
        decoration: BoxDecoration(
          color: superficie,
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          border: Border.all(color: borde, width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColores.acento.withValues(alpha: 0.15),
              child: Text(
                u.iniciales,
                style: tt.subtitulo.copyWith(
                    color: AppColores.acento, fontWeight: FontWeight.w800),
              ),
            ),
            // 14 se deja literal: caso suelto de redondeo entre `md` y `lg`.
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.nombreCompleto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.cuerpo.copyWith(
                        color: textoPrincipal, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppEspaciado.xs),
                  Text(
                    u.habilidades.isNotEmpty
                        ? u.habilidades.take(3).join(' · ')
                        : _especialidad(u),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.etiqueta.copyWith(
                        color: AppColores.acento, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppEspaciado.xs),
                  Estrellas(
                      valor: u.calificacionPromedio,
                      total: u.totalCalificaciones,
                      tamano: 13),
                  const SizedBox(height: AppEspaciado.xs),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: textoSec),
                      const SizedBox(width: AppEspaciado.xs),
                      Expanded(
                        child: Text(
                          ubicacion.isEmpty ? 'Honduras' : ubicacion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.etiqueta.copyWith(color: textoSec),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColores.grisMedio),
          ],
        ),
      ),
    );
  }

  Widget _estadoVacio(bool oscuro) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 56, color: AppColores.grisMedio),
          // 14 se deja literal: caso suelto de redondeo entre `md` y `lg`.
          const SizedBox(height: 14),
          Text(
            'Aún no hay trabajadores registrados.',
            textAlign: TextAlign.center,
            style: tt.cuerpo.copyWith(color: textoSec, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
