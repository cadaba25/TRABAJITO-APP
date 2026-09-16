import 'package:flutter/material.dart';

import '../../nucleo/espaciado/app_espaciado.dart';
import '../../nucleo/tema/colores_por_tema.dart';

/// Botón de texto del sistema de diseño (`docs/design-system-frontend.md`
/// sección 6, tarea 050, ADR-0016 hallazgo 1). Envuelve [TextButton] con
/// altura mínima de 48 (`minimumSize: Size(0, 48)`, el target táctil de la
/// sección 9), que antes no tenían varios usos (`login_screen.dart`
/// "¿Olvidaste tu contraseña?" con `padding: EdgeInsets.zero` y sin mínimo).
///
/// **Color por defecto**: [colorAcentoTexto] — la misma variante WCAG-segura
/// que ya usaba `colorPrecio()`, no `AppColores.acento` crudo (blanco/dorado
/// da 1.63:1 en el botón primario del tema oscuro; esta pareja es texto, no
/// fondo, pero el criterio de "no usar el dorado crudo como texto sobre una
/// superficie clara" es el mismo). No tiene `expandido`: un enlace de texto
/// no ocupa el ancho completo.
class BotonTexto extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;

  /// Override puntual para los casos donde el enlace es semánticamente
  /// distinto del acento por defecto (p. ej. "Retirar"/"Eliminar" en rojo).
  /// `null` usa [colorAcentoTexto].
  final Color? color;

  const BotonTexto({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = color ?? colorAcentoTexto(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.sm),
        minimumSize: const Size(0, 48),
        foregroundColor: colorTexto,
      ),
      child: icono == null
          ? Text(texto)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 18),
                const SizedBox(width: AppEspaciado.xs),
                Text(texto),
              ],
            ),
    );
  }
}
