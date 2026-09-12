import 'package:flutter/material.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/tema/app_colores.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';

/// Tarjeta seleccionable "Persona" / "Empresa" del paso 1 del registro de
/// empleador. Extraída de `registro_empleador_screen.dart` (ADR-0016,
/// tarea 033) como `_TarjetaTipo`.
class TarjetaTipoEmpleador extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  const TarjetaTipoEmpleador({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppEspaciado.lg),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColores.acento.withValues(alpha: 0.10)
              : colorSuperficie(context),
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          border: Border.all(
            color: seleccionado ? AppColores.acento : colorBorde(context),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono,
                color: seleccionado ? AppColores.acento : AppColores.grisMedio,
                size: 26),
            const SizedBox(height: AppEspaciado.md),
            Text(
              titulo,
              style: Theme.of(context).textTheme.subtitulo.copyWith(
                  color:
                      seleccionado ? AppColores.acento : colorTextoFuerte(context)),
            ),
            const SizedBox(height: AppEspaciado.xs),
            Text(
              descripcion,
              style: Theme.of(context)
                  .textTheme
                  .cuerpoChico
                  .copyWith(color: colorTextoSuave(context)),
            ),
          ],
        ),
      ),
    );
  }
}
