import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../nucleo/movimiento/app_movimiento.dart';
import '../../nucleo/movimiento/movimiento_accesible.dart';
import '../../nucleo/tema/app_colores.dart';

/// Cuánto se enseña el check de éxito antes de que la pantalla siga su curso
/// (ADR-0015, fase 6): un "presupuesto de delight", una vez por acción. No es
/// una duración de animación (no varía con `disableAnimations`): es una
/// pausa para que el usuario alcance a leerlo.
const Duration duracionExitoVisible = Duration(milliseconds: 700);

/// Check de éxito breve tras publicar un trabajo o postularse (ADR-0015,
/// fase 6, "la más discutible" — solo se usa donde no complica el flujo de
/// navegación).
///
/// Entra con un escalado de 0.6 a 1.0 y un overshoot suave
/// ([AppMovimiento.exito]). Con `MediaQuery.disableAnimations` aparece ya en
/// su tamaño final, sin escala: sigue siendo el mismo check.
class EstadoExito extends StatelessWidget {
  final String mensaje;
  const EstadoExito({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: duracionMov(context, AppMovimiento.medio),
            curve: curvaMov(context, AppMovimiento.exito),
            builder: (context, escala, hijo) =>
                Transform.scale(scale: escala, child: hijo),
            child: const Icon(LucideIcons.circleCheck,
                color: AppColores.exito, size: 72),
          ),
          const SizedBox(height: 16),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
