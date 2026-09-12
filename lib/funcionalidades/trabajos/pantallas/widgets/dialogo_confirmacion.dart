import 'package:flutter/material.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Diálogo de confirmación genérico (Sí/No).
///
/// Extraído de `detalle_trabajo_screen.dart` en la tarea 035 (ADR-0016; era
/// el método privado `_confirmar`). Hoy solo lo usa el trabajador para
/// rechazar una asignación, pero se mantiene genérico —no atado a
/// "rechazar"— tal como estaba en el archivo original.
///
/// Devuelve `true`/`false` según el botón pulsado, o `null` si se descarta
/// sin elegir (botón atrás o toque fuera del diálogo).
Future<bool?> mostrarDialogoConfirmacion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _DialogoConfirmacion(titulo: titulo, mensaje: mensaje),
  );
}

class _DialogoConfirmacion extends StatelessWidget {
  final String titulo;
  final String mensaje;
  const _DialogoConfirmacion({required this.titulo, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
      title: Text(titulo, style: tt.subtitulo.copyWith(color: colorTextoFuerte(context))),
      content: Text(mensaje, style: tt.cuerpo.copyWith(color: colorTextoSuave(context))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColores.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sí'),
        ),
      ],
    );
  }
}
