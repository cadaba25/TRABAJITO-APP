import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../compartido/datos/datos_empleador.dart';
import '../../../../compartido/widgets/custom_textfield.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Campo "Tarifa en Lempiras" + el selector de unidad (día / hora / semana /
/// contratación completa).
///
/// Reemplaza desde la tarea 039 el campo único "Pago por hora en Lempiras"
/// que asumía la unidad a mano (`'L. $monto/hora'` fijo). Mismo lenguaje
/// visual que ya usa "Plazo de contratación" en la misma pantalla
/// (`ChoiceChip` en un `Wrap`), para no meter un segundo tipo de selector en
/// el mismo formulario.
///
/// Compartido entre `publicar_trabajo_screen.dart` y
/// `editar_trabajo_screen.dart` (esta última no puede guardar — ver su propio
/// docstring — pero mantiene el mismo formulario para no confundir a quien
/// la abre).
class SelectorTarifa extends StatelessWidget {
  final TextEditingController controller;
  final String unidad;
  final ValueChanged<String> onUnidadCambia;

  const SelectorTarifa({
    super.key,
    required this.controller,
    required this.unidad,
    required this.onUnidadCambia,
  });

  /// Arma el mismo `presupuesto: String` de siempre — texto libre de
  /// principio a fin, tanto en `Publicacion.presupuesto` como en lo que
  /// recibe el backend; esto no cambia ningún contrato.
  ///
  /// `'L. 150/hora'`, `'L. 150/día'`, `'L. 5000/semana'`, o, para
  /// "contratación completa" (formato elegido para esta tarea, no hay uno
  /// previo que igualar), `'L. 20000 (contratación)'`. Vacío si no se puso
  /// monto: el campo nunca fue obligatorio.
  static String formatearPresupuesto(String monto, String unidad) {
    if (monto.isEmpty) return '';
    if (unidad == 'contratación completa') return 'L. $monto (contratación)';
    return 'L. $monto/$unidad';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: controller,
          label: 'Tarifa en Lempiras (opcional)',
          hint: 'Solo el monto, p. ej. 150',
          iconoInicio: Icons.payments_outlined,
          tipoTeclado: TextInputType.number,
          formateadores: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: AppEspaciado.sm),
        Text('Se cobra por',
            style: Theme.of(context)
                .textTheme
                .cuerpoChico
                .copyWith(fontWeight: FontWeight.w600, color: colorTextoFuerte(context))),
        const SizedBox(height: AppEspaciado.sm),
        Wrap(
          spacing: AppEspaciado.sm,
          runSpacing: AppEspaciado.sm,
          children: DatosEmpleador.unidadesTarifa.map((u) {
            final activo = unidad == u;
            return ChoiceChip(
              label: Text(u),
              selected: activo,
              onSelected: (_) => onUnidadCambia(u),
              labelStyle: Theme.of(context).textTheme.cuerpoChico.copyWith(
                  color: activo ? Colors.white : colorTextoFuerte(context),
                  fontWeight: FontWeight.w600),
              selectedColor: AppColores.acento,
              backgroundColor: colorSuperficie(context),
              side: BorderSide(
                  color: activo ? AppColores.acento : colorBorde(context)),
            );
          }).toList(),
        ),
      ],
    );
  }
}
