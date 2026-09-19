import 'package:flutter/material.dart';

import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tema/colores_por_tema.dart';

/// Caja de texto + botón de enviar del chat. El servidor rechaza más de 2000
/// caracteres (400), así que se limita aquí también.
class BarraEnvio extends StatelessWidget {
  const BarraEnvio({super.key, required this.controlador, required this.onEnviar});

  final TextEditingController controlador;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: oscuro ? AppColores.superficieOscura : AppColores.blanco,
          border: Border(
              top: BorderSide(
                  color: oscuro ? AppColores.bordeOscuro : AppColores.grisClaro)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controlador,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onEnviar(),
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                buildCounter: (_,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                style: TextStyle(color: colorTextoFuerte(context)),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor:
                      (oscuro ? AppColores.fondoOscuro : AppColores.grisLienzo),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColores.acento),
              onPressed: onEnviar,
              icon: const Icon(Icons.send_rounded, color: AppColores.principal),
            ),
          ],
        ),
      ),
    );
  }
}
