import 'package:flutter/material.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Diálogo del reclamo a soporte: la única salida de un trabajo ya iniciado
/// que no termina de común acuerdo (ADR-0007).
///
/// Extraído de `detalle_trabajo_screen.dart` en la tarea 035 (ADR-0016).
/// Devuelve `(motivo, descripcion)` si se pulsa "Enviar" (ambos ya
/// recortados con `trim()`, el motivo puede venir vacío: la validación de
/// "no vacío" la sigue haciendo quien llama, exactamente igual que antes de
/// extraer el diálogo), o `null` si se cancela/descarta.
Future<(String motivo, String descripcion)?> mostrarDialogoReclamarProblema(
    BuildContext context) {
  return showDialog<(String, String)>(
    context: context,
    builder: (_) => const _DialogoReclamarProblema(),
  );
}

class _DialogoReclamarProblema extends StatefulWidget {
  const _DialogoReclamarProblema();

  @override
  State<_DialogoReclamarProblema> createState() =>
      _DialogoReclamarProblemaState();
}

class _DialogoReclamarProblemaState extends State<_DialogoReclamarProblema> {
  final _motivoCtrl = TextEditingController();
  final _detalleCtrl = TextEditingController();

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _detalleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
      title: Text('Reportar un problema',
          style: tt.subtitulo.copyWith(color: colorTextoFuerte(context))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'El pago quedará retenido hasta que soporte revise el caso. '
            'Ni tú ni la otra parte podrán moverlo mientras tanto.',
            style: tt.cuerpoChico.copyWith(color: colorTextoSuave(context)),
          ),
          const SizedBox(height: AppEspaciado.md),
          TextField(
            controller: _motivoCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Motivo *'),
          ),
          const SizedBox(height: AppEspaciado.sm),
          TextField(
            controller: _detalleCtrl,
            maxLines: 3,
            decoration:
                const InputDecoration(labelText: 'Cuéntanos qué pasó'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColores.error),
          onPressed: () => Navigator.pop(
              context, (_motivoCtrl.text.trim(), _detalleCtrl.text.trim())),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
