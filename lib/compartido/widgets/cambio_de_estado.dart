import 'package:flutter/material.dart';

import '../../nucleo/movimiento/app_movimiento.dart';
import '../../nucleo/movimiento/movimiento_accesible.dart';

/// Fundido entre los estados de una lista (cargando/contenido/error/vacío),
/// ADR-0015 punto 3.
///
/// Envoltorio delgado sobre `AnimatedSwitcher` para no repetir los mismos
/// tres parámetros (duración, curva de entrada, curva de salida) en cada
/// pantalla que cambia de estado. Usa el `transitionBuilder` por defecto de
/// `AnimatedSwitcher` (solo fundido de opacidad, nada de slide) y pasa por
/// [duracionMov]/[curvaMov], así que con `MediaQuery.disableAnimations` el
/// cambio es instantáneo.
///
/// El [child] necesita una `Key` distinta por estado (el `AnimatedSwitcher`
/// la usa para saber que hay que hacer el fundido en vez de reconstruir el
/// mismo widget).
class CambioDeEstado extends StatelessWidget {
  final Widget child;
  const CambioDeEstado({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duracionMov(context, AppMovimiento.chico),
      switchInCurve: curvaMov(context, AppMovimiento.estandar),
      switchOutCurve: curvaMov(context, AppMovimiento.estandar),
      child: child,
    );
  }
}
