import 'package:flutter/material.dart';
import '../../../../compartido/modelos/publicacion.dart';
import '../../../../compartido/modelos/usuario.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import 'fila_feed.dart';

/// La `ListView` paginada del feed de "Trabajos": deslizar para recargar,
/// paginar al llegar al final, y la fila extra de "cargando más".
///
/// Extraída de `trabajos_tab.dart` en la tarea 039 para no pasar de las 300
/// líneas (ADR-0014) al sumarle el colapso de barras al hacer scroll. Sin
/// estado propio: todo (`posts`, `_cargandoMas`, etc.) sigue viviendo en
/// `_TrabajosTabState`.
class ListaFeedTrabajos extends StatelessWidget {
  final ScrollController scrollCtrl;
  final List<Publicacion> posts;
  final Object? error;
  final bool oscuro;
  final bool esEmpleador;
  final Usuario usuario;
  final Set<String> postuladas;
  final bool animarPrimeraLista;
  final bool cargandoMas;
  final bool hayMas;
  final bool soloMias;
  final Future<void> Function() onRefresh;
  final ValueChanged<Publicacion> onAbrir;

  const ListaFeedTrabajos({
    super.key,
    required this.scrollCtrl,
    required this.posts,
    required this.error,
    required this.oscuro,
    required this.esEmpleador,
    required this.usuario,
    required this.postuladas,
    required this.animarPrimeraLista,
    required this.cargandoMas,
    required this.hayMas,
    required this.soloMias,
    required this.onRefresh,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    // El indicador de "cargando más" es una fila más al final de la lista.
    final extra = (cargandoMas || hayMas) && !soloMias ? 1 : 0;

    return RefreshIndicator(
      key: const ValueKey('feed'),
      color: AppColores.acento,
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollCtrl,
        // Deslizar para actualizar tiene que funcionar aunque el contenido
        // quepa entero en la pantalla (lista vacía, o un solo trabajo).
        physics: const AlwaysScrollableScrollPhysics(),
        // 90 (no un rol): hueco de la barra de navegación inferior.
        padding: const EdgeInsets.fromLTRB(
            AppEspaciado.lg, AppEspaciado.lg, AppEspaciado.lg, 90),
        itemCount: posts.isEmpty ? 2 : posts.length + 1 + extra,
        itemBuilder: (context, index) => FilaFeed(
          index: index,
          posts: posts,
          error: error,
          oscuro: oscuro,
          esEmpleador: esEmpleador,
          usuario: usuario,
          postuladas: postuladas,
          animarPrimeraLista: animarPrimeraLista,
          onAbrir: onAbrir,
        ),
      ),
    );
  }
}
