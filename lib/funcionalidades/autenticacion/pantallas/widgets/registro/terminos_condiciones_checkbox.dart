import 'package:flutter/material.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/tema/app_colores.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';

/// Checkbox "Acepto las Condiciones de servicio y la Política de
/// privacidad" del paso 1 de ambos registros (antes duplicado idéntico en
/// los dos archivos).
class TerminosCondicionesCheckbox extends StatelessWidget {
  final bool aceptado;
  final ValueChanged<bool> alCambiar;

  const TerminosCondicionesCheckbox({
    super.key,
    required this.aceptado,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final estiloTexto =
        Theme.of(context).textTheme.cuerpoChico.copyWith(color: colorTextoSuave(context));
    final estiloEnlace = estiloTexto.copyWith(
        color: AppColores.acento, fontWeight: FontWeight.w600);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: aceptado,
          onChanged: (v) => alCambiar(v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppEspaciado.md),
            child: RichText(
              text: TextSpan(
                style: estiloTexto,
                children: [
                  const TextSpan(text: 'Acepto las '),
                  TextSpan(
                      text: 'Condiciones de servicio', style: estiloEnlace),
                  const TextSpan(text: ' y la '),
                  TextSpan(
                      text: 'Política de privacidad', style: estiloEnlace),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
