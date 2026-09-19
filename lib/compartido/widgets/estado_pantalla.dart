import 'package:flutter/material.dart';

import '../../nucleo/espaciado/app_espaciado.dart';
import '../../nucleo/tema/colores_por_tema.dart';
import '../../nucleo/tipografia/app_tipografia.dart';
import 'boton_secundario.dart';

/// Pieza única para los estados "vacío" y "error" de una lista (tarea 055).
///
/// Antes cada pantalla dibujaba su propio icono gris suelto + una línea de
/// texto; ahora todas comparten: icono dentro de un círculo de superficie
/// alterna, [mensaje] (el qué), [detalle] opcional (el qué hacer) y un CTA
/// opcional ([etiquetaAccion] + [onAccion]). Solo presentación: el que la usa
/// decide qué hace la acción. El colorido sale de los roles de
/// `colores_por_tema.dart`, así que funciona igual en claro y oscuro.
class EstadoPantalla extends StatelessWidget {
  final IconData icono;
  final String mensaje;
  final String? detalle;
  final String? etiquetaAccion;
  final VoidCallback? onAccion;
  final IconData? iconoAccion;

  const EstadoPantalla({
    super.key,
    required this.icono,
    required this.mensaje,
    this.detalle,
    this.etiquetaAccion,
    this.onAccion,
    this.iconoAccion,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorSuperficieAlterna(context),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 40, color: colorTextoSuave(context)),
            ),
            const SizedBox(height: AppEspaciado.lg),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: tt.cuerpo.copyWith(
                color: colorTextoFuerte(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (detalle != null) ...[
              const SizedBox(height: AppEspaciado.sm),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: tt.etiqueta.copyWith(color: colorTextoSuave(context)),
              ),
            ],
            if (etiquetaAccion != null && onAccion != null) ...[
              const SizedBox(height: AppEspaciado.xl),
              BotonSecundario(
                texto: etiquetaAccion!,
                icono: iconoAccion,
                onPressed: onAccion,
                expandido: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
