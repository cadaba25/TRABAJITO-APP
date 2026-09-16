import 'package:flutter/material.dart';
import '../../../../compartido/datos/datos_empleador.dart';
import '../../../../compartido/datos/datos_honduras.dart';
import '../../../../compartido/widgets/boton_primario.dart';
import '../../../../compartido/widgets/boton_secundario.dart';
import '../../../../compartido/widgets/custom_dropdown.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

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
    // 24 no cae exacto en AppRadios: `chip` (20) es el más cercano de los
    // tres roles (mismo criterio que la píldora de búsqueda).
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadios.chip))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppEspaciado.xl, AppEspaciado.lg, AppEspaciado.xl, AppEspaciado.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text('Filtros',
                  style: Theme.of(ctx)
                      .textTheme
                      .subtitulo
                      .copyWith(color: colorTextoFuerte(ctx))),
            ),
            const SizedBox(height: AppEspaciado.lg),
            CustomDropdown(
              label: 'Categoría',
              valor: cat.isEmpty ? null : cat,
              opciones: DatosEmpleador.sectores,
              icono: Icons.category_outlined,
              alCambiar: (v) => setSheet(() => cat = v ?? ''),
            ),
            const SizedBox(height: AppEspaciado.md),
            CustomDropdown(
              label: 'Departamento',
              valor: depto.isEmpty ? null : depto,
              opciones: DatosHonduras.departamentos,
              icono: Icons.map_outlined,
              alCambiar: (v) => setSheet(() => depto = v ?? ''),
            ),
            const SizedBox(height: AppEspaciado.lg),
            Row(
              children: [
                Expanded(
                  child: BotonSecundario(
                    texto: 'Limpiar',
                    expandido: false,
                    onPressed: () {
                      onLimpiar();
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: AppEspaciado.md),
                Expanded(
                  child: BotonPrimario(
                    texto: 'Aplicar',
                    expandido: false,
                    onPressed: () {
                      onAplicar(cat, depto);
                      Navigator.pop(ctx);
                    },
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
