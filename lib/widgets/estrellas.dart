import 'package:flutter/material.dart';
import '../utils/constantes.dart';

/// Muestra una calificación con estrellas y, opcionalmente, el total de reseñas.
class Estrellas extends StatelessWidget {
  final double valor;      // 0..5
  final int total;         // número de reseñas
  final double tamano;
  final Color? colorTexto;

  const Estrellas({
    super.key,
    required this.valor,
    this.total = 0,
    this.tamano = 16,
    this.colorTexto,
  });

  @override
  Widget build(BuildContext context) {
    final texto = colorTexto ?? AppColores.grisTexto;
    if (total == 0) {
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
            media
                ? Icons.star_half_rounded
                : (llena ? Icons.star_rounded : Icons.star_outline_rounded),
            color: AppColores.dorado,
            size: tamano,
          );
        }),
        const SizedBox(width: 6),
        Text('${valor.toStringAsFixed(1)} ($total)',
            style: TextStyle(
                color: texto, fontSize: tamano * 0.8, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
