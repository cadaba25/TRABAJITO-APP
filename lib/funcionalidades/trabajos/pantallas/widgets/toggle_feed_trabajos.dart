import 'package:flutter/material.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/movimiento/app_movimiento.dart';
import '../../../../nucleo/movimiento/movimiento_accesible.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Alternador sutil del feed de "Trabajos" para el contratista: todos los
/// trabajos / solo mis publicaciones.
///
/// Extraído de `trabajos_tab.dart` en la tarea 027 B-2b. El estado (`_soloMias`)
/// y la recarga viven en el `State` de la pestaña; aquí solo se despacha el
/// cambio.
class ToggleFeedTrabajos extends StatelessWidget {
  final bool soloMias;
  final ValueChanged<bool> onCambia;

  const ToggleFeedTrabajos({
    super.key,
    required this.soloMias,
    required this.onCambia,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppEspaciado.lg, AppEspaciado.md, AppEspaciado.lg, 0),
      child: Row(
        children: [
          _Boton(
              texto: 'Trabajos',
              activo: !soloMias,
              onTap: () => onCambia(false)),
          const SizedBox(width: AppEspaciado.sm),
          _Boton(
              texto: 'Mis publicaciones',
              activo: soloMias,
              onTap: () => onCambia(true)),
        ],
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  final String texto;
  final bool activo;
  final VoidCallback onTap;
  const _Boton({
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: duracionMov(context, AppMovimiento.chico),
        curve: curvaMov(context, AppMovimiento.estandar),
        padding:
            const EdgeInsets.symmetric(horizontal: AppEspaciado.lg, vertical: AppEspaciado.sm),
        decoration: BoxDecoration(
          color: activo
              ? AppColores.acento.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadios.chip),
        ),
        child: Text(texto,
            style: Theme.of(context).textTheme.cuerpoChico.copyWith(
                fontWeight: FontWeight.w700,
                color: activo ? AppColores.acento : colorTextoSuave(context))),
      ),
    );
  }
}
