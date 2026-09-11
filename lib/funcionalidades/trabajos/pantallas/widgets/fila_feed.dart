import 'package:flutter/material.dart';

import '../../../../compartido/modelos/publicacion.dart';
import '../../../../compartido/modelos/usuario.dart';
import '../../../../compartido/widgets/cambio_de_estado.dart';
import 'encabezado_feed.dart';
import 'entrada_escalonada.dart';
import 'estados_feed.dart';
import 'tarjeta_trabajo.dart';

/// Tope de tarjetas con entrada escalonada en la primera carga (ADR-0015).
const int topeEntradaEscalonada = 6;

/// Una fila del feed de "Trabajos", extraída de `trabajos_tab.dart` para no
/// pasar el techo de 300 líneas (ADR-0014). Decide qué se pinta en el índice
/// [index]: cabecera, el estado de error/vacío (con fundido vía
/// [CambioDeEstado]), el pie de "cargando más" o una tarjeta —con entrada
/// escalonada si [animarPrimeraLista] lo pide y sigue dentro del tope—.
class FilaFeed extends StatelessWidget {
  final int index;
  final List<Publicacion> posts;
  final Object? error;
  final bool oscuro;
  final bool esEmpleador;
  final Usuario usuario;
  final Set<String> postuladas;
  final bool animarPrimeraLista;
  final ValueChanged<Publicacion> onAbrir;

  const FilaFeed({
    super.key,
    required this.index,
    required this.posts,
    required this.error,
    required this.oscuro,
    required this.esEmpleador,
    required this.usuario,
    required this.postuladas,
    required this.animarPrimeraLista,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    if (index == 0) {
      return EncabezadoFeed(usuario: usuario, esEmpleador: esEmpleador);
    }
    if (posts.isEmpty) {
      return CambioDeEstado(
        child: error != null
            ? EstadoErrorFeed(
                key: const ValueKey('error'), error: error, oscuro: oscuro)
            : EstadoVacioFeed(
                key: const ValueKey('vacio'),
                oscuro: oscuro,
                esEmpleador: esEmpleador),
      );
    }
    if (index == posts.length + 1) return const PieDeCargaFeed();

    final posEnLista = index - 1;
    final publicacion = posts[posEnLista];
    final tarjeta = TarjetaTrabajo(
      publicacion: publicacion,
      oscuro: oscuro,
      esEmpleador: esEmpleador,
      yaPostulado: postuladas.contains(publicacion.id),
      onAbrir: () => onAbrir(publicacion),
    );
    // Stagger solo en la primera carga en frío, tope 6 (ADR-0015): al
    // paginar o recargar deslizando el resto de tarjetas ya no pasa por aquí.
    if (animarPrimeraLista && posEnLista < topeEntradaEscalonada) {
      return EntradaEscalonada(indice: posEnLista, child: tarjeta);
    }
    return tarjeta;
  }
}
