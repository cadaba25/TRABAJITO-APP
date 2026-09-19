import 'package:flutter/material.dart';

import '../../../nucleo/tema/app_colores.dart';
import '../datos/chat.dart';

/// Burbuja de un mensaje: píldora centrada para los del sistema, burbuja a la
/// derecha (mía) o a la izquierda (del otro) para el texto.
class BurbujaMensaje extends StatelessWidget {
  const BurbujaMensaje({super.key, required this.mensaje, required this.miUid});

  final Mensaje mensaje;
  final String miUid;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    if (mensaje.esSistema) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColores.azulProfesional.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(mensaje.texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColores.azulProfesional,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      );
    }
    final mio = mensaje.deUid == miUid;
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: mio
              ? AppColores.acento
              : (oscuro ? AppColores.superficieOscura : AppColores.blanco),
          borderRadius: BorderRadius.circular(16),
          border: mio
              ? null
              : Border.all(
                  color: oscuro ? AppColores.bordeOscuro : AppColores.grisClaro),
        ),
        child: Text(mensaje.texto,
            style: TextStyle(
                color: mio
                    ? Colors.white
                    : (oscuro ? AppColores.textoOscuro : AppColores.texto),
                fontSize: 14,
                height: 1.3)),
      ),
    );
  }
}
