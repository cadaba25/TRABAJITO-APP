import 'package:flutter/material.dart';

import '../../nucleo/movimiento/app_movimiento.dart';
import '../../nucleo/movimiento/movimiento_accesible.dart';

/// Feedback al tacto para elementos pulsables que hoy usan `GestureDetector`
/// desnudo (ADR-0015, punto 2): las tarjetas del feed, "mis publicaciones" y
/// postulantes.
///
/// Encoge el hijo a `0.97` en `onTapDown` y vuelve a `1.0` en
/// `onTapUp`/`onTapCancel`, con [AppMovimiento.microFeedback] y
/// `Curves.easeOut`. Pasa por [duracionMov], así que con
/// `MediaQuery.disableAnimations` no hay escala y `onTap` sigue funcionando
/// igual.
///
/// **No envuelve `ElevatedButton`/`OutlinedButton`**: Material ya les da su
/// propio feedback (ADR-0015, punto 2). Es solo para lo que hoy no tiene
/// ninguno.
class PulsaConEscala extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PulsaConEscala({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<PulsaConEscala> createState() => _PulsaConEscalaState();
}

class _PulsaConEscalaState extends State<PulsaConEscala> {
  bool _presionado = false;

  void _fijarPresionado(bool valor) {
    if (_presionado == valor) return;
    setState(() => _presionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _fijarPresionado(true),
      onTapUp: (_) => _fijarPresionado(false),
      onTapCancel: () => _fijarPresionado(false),
      child: AnimatedScale(
        scale: _presionado ? 0.97 : 1.0,
        duration: duracionMov(context, AppMovimiento.microFeedback),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
