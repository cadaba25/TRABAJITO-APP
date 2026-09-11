import 'package:flutter/animation.dart';

/// Vocabulario de movimiento único de la app (ADR-0015).
///
/// **Ningún otro archivo declara un `Duration`/`Curve` de animación a mano.**
/// Si una pantalla necesita una duración o una curva que no está aquí, se
/// añade aquí primero — no se inventa en el sitio que la usa.
///
/// Los valores traducen los principios de las skills de diseño del repo
/// (`emil-design-eng`, `apple-design`) a Flutter: ver la tabla completa en
/// ADR-0015, `docs/decisions.md`.
abstract final class AppMovimiento {
  /// Feedback de pulsación (press-down de una tarjeta). 120 ms.
  static const Duration microFeedback = Duration(milliseconds: 120);

  /// Fundidos cortos: cambio de estado de una lista, flip de un chip. 180 ms.
  static const Duration chico = Duration(milliseconds: 180);

  /// Entradas con algo más de cuerpo: stagger del feed, estado de éxito.
  /// 240 ms.
  static const Duration medio = Duration(milliseconds: 240);

  /// Paneles y hojas grandes. 320 ms.
  static const Duration panel = Duration(milliseconds: 320);

  /// Curva de entrada/salida estándar para elementos que aparecen.
  static const Curve entrada = Curves.easeOutCubic;

  /// Curva para paneles (Material Design 3 "emphasized decelerate").
  ///
  /// ADR-0015 la llama "panel", igual que [panel] (la duración). Dart no
  /// permite dos miembros estáticos con el mismo nombre en la misma clase,
  /// así que aquí se distingue con el sufijo `Curva`.
  static const Curve panelCurva = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Curva neutra para fundidos entre estados.
  static const Curve estandar = Curves.easeInOut;

  /// Overshoot suave para el estado de éxito (equivale a "bounce 0.15").
  static const Curve exito = Curves.easeOutBack;
}
