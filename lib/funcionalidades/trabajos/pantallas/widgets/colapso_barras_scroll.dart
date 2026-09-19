import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../../../../nucleo/movimiento/app_movimiento.dart';
import '../../../../nucleo/movimiento/movimiento_accesible.dart';

/// Colapsa la altura de las barras fijas de `TrabajosTab`
/// (`BarraBusquedaTrabajos` y, para empleadores, `ToggleFeedTrabajos`) al
/// deslizar hacia abajo, y las restaura al deslizar hacia arriba o al llegar
/// al principio de la lista.
///
/// **Excepción puntual, no un patrón reutilizable.** Autorizada explícitamente
/// como cuarto punto de la lista cerrada "dónde SÍ" de ADR-0015 (adenda
/// 2026-09-12, `docs/decisions.md`) para corregir el "corte agresivo" que
/// reportó el dueño: el contenido de la lista pasaba por debajo del borde
/// inferior de esas dos barras, que no reaccionaban en absoluto al scroll. No
/// se replica en otra pantalla sin pasar otra vez por ese ADR.
///
/// Vive en su propio archivo solo para no hacer pasar `trabajos_tab.dart` de
/// las 300 líneas (ADR-0014) — no es un widget en sí, es el controlador que
/// alimenta el `sizeFactor` de un `SizeTransition` en la pantalla.
///
/// Por qué `SizeTransition` (envolviendo los widgets reales) y no quitarlos
/// del árbol al colapsar: `BarraBusquedaTrabajos` usa un `TextField` sin
/// `controller` propio (el texto de búsqueda vive en `TrabajosTab`, no en el
/// campo) — si el widget se desmontara al colapsar, se perdería lo que el
/// usuario ya había escrito en cuanto volviera a subir.
class ColapsoBarrasScroll {
  ColapsoBarrasScroll({required TickerProvider vsync})
      : controlador = AnimationController(
          vsync: vsync,
          duration: AppMovimiento.chico,
          value: 1,
        );

  /// `1` = barras a su altura completa, `0` = colapsadas. Se usa tal cual
  /// como `sizeFactor` de un `SizeTransition`.
  final AnimationController controlador;
  bool _visibles = true;

  void dispose() => controlador.dispose();

  /// Se llama desde el listener del `ScrollController` de la pantalla, con
  /// su posición actual.
  void alHacerScroll(BuildContext context, ScrollPosition pos) {
    // Siempre visibles arriba del todo: no hace falta deslizar hacia arriba
    // para recuperarlas si ya se llegó al principio de la lista.
    if (pos.pixels <= 0) {
      _mostrar(context, true);
      return;
    }
    switch (pos.userScrollDirection) {
      case ScrollDirection.reverse: // deslizando hacia abajo
        _mostrar(context, false);
        break;
      case ScrollDirection.forward: // deslizando hacia arriba
        _mostrar(context, true);
        break;
      case ScrollDirection.idle:
        break;
    }
  }

  void _mostrar(BuildContext context, bool visible) {
    if (visible == _visibles) return;
    _visibles = visible;
    // `duracionMov`/`curvaMov` (ADR-0015 punto 5): con reduced-motion el
    // colapso es instantáneo, no ausente.
    controlador.animateTo(
      visible ? 1 : 0,
      duration: duracionMov(context, AppMovimiento.chico),
      curve: curvaMov(context, AppMovimiento.estandar),
    );
  }
}
