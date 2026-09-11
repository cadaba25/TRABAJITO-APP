import 'package:flutter/material.dart';

import '../../../../nucleo/movimiento/app_movimiento.dart';
import '../../../../nucleo/movimiento/movimiento_accesible.dart';

/// Entrada escalonada de la **primera** carga del feed (ADR-0015, fase 4).
///
/// Cada tarjeta entra con fundido + una subida de 8 px, con un retraso de
/// `40 ms * `[indice] respecto a la anterior (stagger). El retraso se expresa
/// como un [Interval] dentro de la duración total de un único
/// `TweenAnimationBuilder`, no con un `Future.delayed` aparte: así la
/// animación corre desde el primer frame y `pumpAndSettle` la espera entera
/// sin tiempos de espera frágiles en los tests.
///
/// Quien la usa decide hasta qué índice se aplica (el tope de 6 de ADR-0015
/// vive en `fila_feed.dart`, no aquí) y cuándo — esta pieza no sabe si es la
/// primera carga, un `_cargarMas` o un deslizar para refrescar.
///
/// Con `MediaQuery.disableAnimations` no hay retraso ni animación: el hijo
/// aparece de inmediato, sin envoltorio.
class EntradaEscalonada extends StatelessWidget {
  final int indice;
  final Widget child;

  const EntradaEscalonada({
    super.key,
    required this.indice,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (context.prefiereMenosMovimiento) return child;

    final retraso = Duration(milliseconds: 40 * indice);
    final duracionTotal = retraso + AppMovimiento.medio;
    final fraccionRetraso =
        retraso.inMicroseconds / duracionTotal.inMicroseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duracionTotal,
      curve: Interval(fraccionRetraso, 1.0, curve: AppMovimiento.entrada),
      builder: (context, valor, hijo) {
        return Opacity(
          opacity: valor,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - valor)),
            child: hijo,
          ),
        );
      },
      child: child,
    );
  }
}
