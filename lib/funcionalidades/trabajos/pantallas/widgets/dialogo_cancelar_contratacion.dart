import 'package:flutter/material.dart';
import '../../../../compartido/widgets/boton_primario.dart';
import '../../../../compartido/widgets/boton_texto.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Diálogo de "¿qué hacemos con el trabajo?" al cancelar una contratación.
///
/// Extraído de `detalle_trabajo_screen.dart` en la tarea 035 (ADR-0016). El
/// backend exige elegir `reabrir` sin valor por defecto (400 si falta) — no
/// hay una opción razonable a asumir, por eso el diálogo obliga a elegir en
/// vez de preguntar "¿seguro?".
///
/// Devuelve `true` (volver a publicarlo al feed), `false` (cerrarlo) o
/// `null` si se elige "Mejor no" o se descarta el diálogo.
Future<bool?> mostrarDialogoCancelarContratacion(
  BuildContext context, {
  required String nombreTrabajador,
  required bool hayEscrow,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _DialogoCancelarContratacion(
        nombreTrabajador: nombreTrabajador, hayEscrow: hayEscrow),
  );
}

class _DialogoCancelarContratacion extends StatelessWidget {
  final String nombreTrabajador;
  final bool hayEscrow;
  const _DialogoCancelarContratacion({
    required this.nombreTrabajador,
    required this.hayEscrow,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
      title: Text('¿Qué hacemos con el trabajo?',
          style: tt.subtitulo.copyWith(color: colorTextoFuerte(context))),
      content: Text(
        'Se cancela la contratación de $nombreTrabajador.'
        '${hayEscrow ? '\n\nEl pago en garantía se te reembolsa entero.' : ''}'
        '\n\nElige qué pasa después:',
        style: tt.cuerpo.copyWith(color: colorTextoSuave(context)),
      ),
      actions: [
        BotonTexto(
          texto: 'Mejor no',
          onPressed: () => Navigator.pop(context),
        ),
        BotonTexto(
          texto: 'Cerrarlo',
          color: AppColores.error,
          onPressed: () => Navigator.pop(context, false),
        ),
        BotonPrimario(
          texto: 'Volver a publicarlo',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
