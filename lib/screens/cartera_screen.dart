import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tarjeta.dart';
import '../models/usuario.dart';
import '../services/cartera_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';

/// Cartera: saldo en la app + tarjetas guardadas (tipo PedidosYa).
class CarteraScreen extends StatelessWidget {
  final Usuario usuario;
  const CarteraScreen({super.key, required this.usuario});

  CarteraService get _s => CarteraService();
  String get _uid => usuario.uid;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartera',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Saldo ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColores.principal, AppColores.azulProfesional],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo disponible',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 13)),
                const SizedBox(height: 6),
                StreamBuilder<double>(
                  stream: _s.streamSaldo(_uid),
                  builder: (context, snap) {
                    final saldo = snap.data ?? usuario.saldo;
                    return Text('L. ${saldo.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900));
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.dorado),
                    onPressed: () => _recargar(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Recargar saldo'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Text('Mis tarjetas',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: oscuro ? AppColores.textoOscuro : AppColores.texto)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _agregarTarjeta(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          StreamBuilder<List<Tarjeta>>(
            stream: _s.streamTarjetas(_uid),
            builder: (context, snap) {
              final tarjetas = snap.data ?? [];
              if (tarjetas.isEmpty) {
                return _vacio(context);
              }
              return Column(
                children: tarjetas.map((t) => _tarjeta(context, t, oscuro)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Prototipo: los pagos son simulados. En producción se procesan con '
            'una pasarela segura.',
            style: TextStyle(
                fontSize: 11,
                color: oscuro ? AppColores.grisMedio : AppColores.grisTexto),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(BuildContext context, Tarjeta t, bool oscuro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: oscuro ? AppColores.superficieOscura : AppColores.blanco,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: oscuro ? AppColores.bordeOscuro : AppColores.grisClaro,
            width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card_rounded,
              color: AppColores.azulProfesional, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.marca} •••• ${t.ultimos4}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                            oscuro ? AppColores.textoOscuro : AppColores.texto)),
                Text(
                  '${t.titular}${t.vencimiento.isNotEmpty ? ' · ${t.vencimiento}' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      color: oscuro ? AppColores.grisMedio : AppColores.grisTexto),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              final err = await _s.eliminarTarjeta(_uid, t.id);
              if (context.mounted && err != null) {
                mostrarSnackBar(context, err, esError: true);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColores.error, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _vacio(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Text('No tienes tarjetas guardadas.',
          style: TextStyle(
              color: oscuro ? AppColores.grisMedio : AppColores.grisTexto)),
    );
  }

  Future<void> _recargar(BuildContext context) async {
    final ctrl = TextEditingController();
    final monto = await showDialog<double>(
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
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
    if (monto == null) return;
    final err = await _s.recargarSaldo(_uid, monto);
    if (context.mounted) {
      mostrarSnackBar(context, err ?? 'Saldo recargado', esError: err != null);
    }
  }

  Future<void> _agregarTarjeta(BuildContext context) async {
    final numCtrl = TextEditingController();
    final titCtrl = TextEditingController();
    final vencCtrl = TextEditingController();
    final ok = await showDialog<bool>(
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
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await _s.agregarTarjeta(
      uid: _uid,
      numero: numCtrl.text,
      titular: titCtrl.text,
      vencimiento: vencCtrl.text,
    );
    if (context.mounted) {
      mostrarSnackBar(context, err ?? 'Tarjeta agregada', esError: err != null);
    }
  }
}
