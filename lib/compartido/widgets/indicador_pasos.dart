import 'package:flutter/material.dart';

import '../../nucleo/tema/app_colores.dart';
import '../../nucleo/tema/colores_por_tema.dart';

/// Barra de progreso de un formulario multipaso ("Paso 2/5").
/// La usan los dos registros.
class IndicadorPasos extends StatelessWidget {
  final int pasoActual;  // 1-based
  final int totalPasos;

  const IndicadorPasos({
    super.key,
    required this.pasoActual,
    required this.totalPasos,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paso $pasoActual/$totalPasos',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorTextoSuave(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(totalPasos, (i) {
            final completado = i < pasoActual;
            final activo = i == pasoActual - 1;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < totalPasos - 1 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: completado || activo
                      ? AppColores.acento
                      : colorBorde(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
