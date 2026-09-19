import 'package:flutter/widgets.dart';

import 'app_movimiento.dart';

/// Respeta `MediaQuery.disableAnimations` (ADR-0015, punto 5).
///
/// **Todo widget animado de la app pasa por aquí** en vez de usar su
/// `Duration`/`Curve` directamente. `disableAnimations` es la señal de
/// "reducir movimiento" del sistema operativo (Android: Ajustes >
/// Accesibilidad > Quitar animaciones; iOS: Reduce Motion). ADR-0015 pide
/// "más suave, no cero" — por eso [duracionMov] colapsa a
/// [Duration.zero] (instantáneo, no ausente) y [curvaMov] cae a un fundido
/// lineal simple en vez de desaparecer la transición.
///
/// Un widget animado sin pasar por aquí no pasa revisión (ADR-0015 punto 5).
extension MovimientoAccesible on BuildContext {
  /// `true` si el sistema pide reducir movimiento.
  bool get prefiereMenosMovimiento =>
      MediaQuery.maybeOf(this)?.disableAnimations ?? false;
}

/// Duración a usar: [base] normalmente, [Duration.zero] si el sistema pide
/// reducir movimiento.
Duration duracionMov(BuildContext context, Duration base) {
  return context.prefiereMenosMovimiento ? Duration.zero : base;
}

/// Curva a usar: [base] normalmente, un fundido simple
/// ([AppMovimiento.estandar]) si el sistema pide reducir movimiento.
Curve curvaMov(BuildContext context, Curve base) {
  return context.prefiereMenosMovimiento ? AppMovimiento.estandar : base;
}
