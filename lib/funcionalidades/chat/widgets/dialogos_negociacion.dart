import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo para proponer el tiempo: cantidad + unidad (horas/días/…).
/// Devuelve `"3 días"` o `null` si se cancela.
class DialogoTiempo extends StatefulWidget {
  const DialogoTiempo({super.key});

  @override
  State<DialogoTiempo> createState() => _DialogoTiempoState();
}

class _DialogoTiempoState extends State<DialogoTiempo> {
  final _ctrl = TextEditingController();
  String _unidad = 'días';
  static const _unidades = ['horas', 'días', 'semanas', 'meses'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Proponer plazo',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _unidad,
            items: _unidades
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _unidad = v ?? 'días'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            final n = int.tryParse(_ctrl.text.trim());
            if (n == null || n <= 0) return;
            Navigator.pop(context, '$n $_unidad');
          },
          child: const Text('Proponer'),
        ),
      ],
    );
  }
}

/// Diálogo para proponer el pago total. Devuelve el monto (> 0) o `null`.
class DialogoPago extends StatefulWidget {
  const DialogoPago({super.key});

  @override
  State<DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<DialogoPago> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Proponer pago total',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'Pago total (Lempiras)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final n = double.tryParse(_ctrl.text.trim());
            if (n == null || n <= 0) return;
            Navigator.pop(context, n);
          },
          child: const Text('Proponer'),
        ),
      ],
    );
  }
}
