import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../nucleo/tema/app_colores.dart';
import '../../nucleo/tema/colores_por_tema.dart';

/// Pregunta con dos botones excluyentes (Si / No).
class BotonesSiNo extends StatelessWidget {
  final bool? valorActual;
  final void Function(bool) alCambiar;
  final String pregunta;

  const BotonesSiNo({
    super.key,
    required this.valorActual,
    required this.alCambiar,
    required this.pregunta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pregunta,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorTextoFuerte(context),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _boton(context, true, 'Sí'),
            const SizedBox(width: 12),
            _boton(context, false, 'No'),
          ],
        ),
      ],
    );
  }

  Widget _boton(BuildContext context, bool valor, String texto) {
    final seleccionado = valorActual == valor;
    return GestureDetector(
      onTap: () => alCambiar(valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? AppColores.acento : colorSuperficie(context),
          border: Border.all(
            color: seleccionado ? AppColores.acento : AppColores.grisMedio,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (seleccionado) ...[
              const Icon(LucideIcons.check, color: Colors.white, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              texto,
              style: TextStyle(
                color: seleccionado ? Colors.white : colorTextoFuerte(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
