import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../nucleo/tema/colores_por_tema.dart';

/// Desplegable con el mismo aspecto que [CustomTextField].
class CustomDropdown extends StatelessWidget {
  final String label;
  final String? valor;
  final List<String> opciones;
  final void Function(String?) alCambiar;
  final String? Function(String?)? validador;
  final IconData? icono;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.valor,
    required this.opciones,
    required this.alCambiar,
    this.validador,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: valor,
      validator: validador,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icono != null
            ? Icon(icono, color: colorTextoSuave(context), size: 20)
            : null,
      ),
      items: opciones.map((op) => DropdownMenuItem(
        value: op,
        child: Text(op,
            style: TextStyle(fontSize: 14, color: colorTextoFuerte(context))),
      )).toList(),
      onChanged: alCambiar,
      icon: Icon(LucideIcons.chevronDown, color: colorTextoSuave(context)),
      dropdownColor: colorSuperficie(context),
      isExpanded: true,
    );
  }
}
