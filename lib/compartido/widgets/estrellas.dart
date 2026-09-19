import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../nucleo/tema/app_colores.dart';

/// Muestra una calificación con estrellas y, opcionalmente, el total de reseñas.
class Estrellas extends StatelessWidget {
  final double valor;      // 0..5
  final int total;         // número de reseñas
  final double tamano;
  final Color? colorTexto;
  final bool mostrarTexto;

  const Estrellas({
    super.key,
    required this.valor,
    this.total = 0,
    this.tamano = 16,
    this.colorTexto,
    this.mostrarTexto = true,
  });

  @override
  Widget build(BuildContext context) {
    final texto = colorTexto ?? AppColores.grisTexto;
    if (mostrarTexto && total == 0) {
      return Text('Sin calificaciones',
          style: TextStyle(color: texto, fontSize: tamano * 0.8));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final llena = i < valor.floor();
          final media = !llena && i < valor;
          return Icon(
            media ? LucideIcons.starHalf : LucideIcons.star,
            // Lucide es un set de solo trazo: no hay una "estrella rellena"
            // distinta de la "vacía" (a diferencia de Material, que sí traía
            // glifos de relleno y contorno separados). Sin este color, una
            // calificación de 0 estrellas se vería IGUAL que una de 5: la
            // señal de "llena" pasa a llevarla el color, no el glifo.
            color: (llena || media) ? AppColores.dorado : AppColores.grisMedio,
            size: tamano,
          );
        }),
        if (mostrarTexto) ...[
          const SizedBox(width: 6),
          Text('${valor.toStringAsFixed(1)} ($total)',
              style: TextStyle(
                  color: texto, fontSize: tamano * 0.8, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}
