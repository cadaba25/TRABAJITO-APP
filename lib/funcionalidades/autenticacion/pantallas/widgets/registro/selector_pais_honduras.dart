import 'package:flutter/material.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/tema/app_colores.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';

/// Selector "Honduras / Fuera del país (Pronto)" de los formularios de
/// registro. Antes existía duplicado byte a byte como `_SelectorPaisLocal`
/// (empleador) y `_SelectorPaisLocalTrab` (trabajador) — un solo widget
/// compartido al aplicar los tokens de ADR-0016 (tarea 033).
class SelectorPaisHonduras extends StatelessWidget {
  final VoidCallback alTocarFuera;
  const SelectorPaisHonduras({super.key, required this.alTocarFuera});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación',
            style: Theme.of(context).textTheme.cuerpoChico.copyWith(
                fontWeight: FontWeight.w600,
                color: colorTextoFuerte(context))),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: AppEspaciado.md, horizontal: AppEspaciado.md),
                decoration: BoxDecoration(
                  color: AppColores.acento.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadios.campo),
                  border: Border.all(color: AppColores.acento, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColores.acento, size: 16),
                    const SizedBox(width: AppEspaciado.sm),
                    Flexible(
                      child: Text('Honduras',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.cuerpo.copyWith(
                              color: AppColores.acento,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppEspaciado.md),
            Expanded(
              child: GestureDetector(
                onTap: alTocarFuera,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppEspaciado.md, horizontal: AppEspaciado.md),
                  decoration: BoxDecoration(
                    color: colorSuperficie(context),
                    borderRadius: BorderRadius.circular(AppRadios.campo),
                    border: Border.all(color: colorBorde(context), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text('Fuera del país',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .etiqueta
                                .copyWith(color: AppColores.grisMedio)),
                      ),
                      const SizedBox(width: AppEspaciado.sm),
                      Text('Pronto',
                          style: Theme.of(context)
                              .textTheme
                              .etiqueta
                              .copyWith(color: AppColores.grisMedio)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
