import 'package:flutter/material.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _Boton(
              texto: 'Trabajos',
              activo: !soloMias,
              onTap: () => onCambia(false)),
          const SizedBox(width: 6),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activo
              ? AppColores.acento.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(texto,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: activo ? AppColores.acento : colorTextoSuave(context))),
      ),
    );
  }
}
