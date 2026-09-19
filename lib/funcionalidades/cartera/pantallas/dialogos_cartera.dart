import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo de "Recargar saldo". Devuelve el monto, o `null` si se cancela.
Future<double?> pedirMontoRecarga(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Recargar saldo',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'Monto en Lempiras'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            final n = double.tryParse(ctrl.text.trim());
            if (n == null || n <= 0) return;
            Navigator.pop(ctx, n);
          },
          child: const Text('Recargar'),
        ),
      ],
    ),
  );
}

/// Datos que pide el diálogo de "Agregar tarjeta".
typedef DatosTarjeta = ({String numero, String titular, String vencimiento});

/// Diálogo de "Agregar tarjeta". `null` si se cancela.
Future<DatosTarjeta?> pedirDatosTarjeta(BuildContext context) {
  final numCtrl = TextEditingController();
  final titCtrl = TextEditingController();
  final vencCtrl = TextEditingController();
  return showDialog<DatosTarjeta>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Agregar tarjeta',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: numCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            decoration: const InputDecoration(labelText: 'Número de tarjeta'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titCtrl,
            decoration: const InputDecoration(labelText: 'Titular'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: vencCtrl,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: 'Vencimiento (MM/AA)'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, (
            numero: numCtrl.text,
            titular: titCtrl.text,
            vencimiento: vencCtrl.text,
          )),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
