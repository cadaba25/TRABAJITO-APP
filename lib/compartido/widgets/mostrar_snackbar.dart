import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../nucleo/tema/app_colores.dart';

/// El aviso corto de abajo, en verde o en rojo. Unico sitio donde la app
/// construye un `SnackBar`: si cambia el aspecto, cambia aqui.
void mostrarSnackBar(BuildContext context, String mensaje, {bool esError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            esError ? LucideIcons.circleAlert : LucideIcons.circleCheck,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(mensaje)),
        ],
      ),
      backgroundColor: esError ? AppColores.error : AppColores.exito,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: esError ? 4 : 3),
    ),
  );
}
