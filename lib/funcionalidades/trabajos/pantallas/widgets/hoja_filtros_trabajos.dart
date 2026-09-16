import 'package:flutter/material.dart';
import '../../../../compartido/datos/datos_empleador.dart';
import '../../../../compartido/datos/datos_honduras.dart';
import '../../../../compartido/widgets/custom_dropdown.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';

/// Hoja inferior de filtros del feed de "Trabajos" (categoría y departamento).
///
/// Extraída de `trabajos_tab.dart` en la tarea 027 B-2b. La hoja lleva su
/// propio estado local mientras está abierta (lo que el usuario va eligiendo);
/// al confirmar despacha el resultado a la pestaña, que es quien guarda los
/// filtros aplicados y recarga.
Future<void> abrirHojaFiltrosTrabajos(
  BuildContext context, {
  required String categoria,
  required String departamento,
  required void Function(String categoria, String departamento) onAplicar,
  required VoidCallback onLimpiar,
}) {
  var cat = categoria;
  var depto = departamento;
  final oscuro = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: oscuro ? AppColores.superficieOscura : AppColores.blanco,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text('Filtros',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colorTextoFuerte(context))),
            ),
            const SizedBox(height: 16),
            CustomDropdown(
              label: 'Categoría',
              valor: cat.isEmpty ? null : cat,
              opciones: DatosEmpleador.sectores,
              icono: Icons.category_outlined,
              alCambiar: (v) => setSheet(() => cat = v ?? ''),
            ),
            const SizedBox(height: 14),
            CustomDropdown(
              label: 'Departamento',
              valor: depto.isEmpty ? null : depto,
              opciones: DatosHonduras.departamentos,
              icono: Icons.map_outlined,
              alCambiar: (v) => setSheet(() => depto = v ?? ''),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      onLimpiar();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onAplicar(cat, depto);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
