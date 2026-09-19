import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../compartido/modelos/tarjeta.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../../nucleo/sesion/sesion_usuario.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../perfil/datos/perfil_service.dart';
import '../datos/cartera_service.dart';
import 'dialogos_cartera.dart';

/// Cartera: saldo en la app + tarjetas guardadas (tipo PedidosYa).
///
/// Sin streams (tarea 052): el saldo se lee de la sesión y se refresca con
/// `PerfilService.recargarPerfil()`; las tarjetas se piden una vez y se
/// vuelven a pedir al deslizar para actualizar o tras cada cambio.
class CarteraScreen extends StatefulWidget {
  final Usuario usuario;
  const CarteraScreen({super.key, required this.usuario});

  @override
  State<CarteraScreen> createState() => _CarteraScreenState();
}

class _CarteraScreenState extends State<CarteraScreen> {
  late final CarteraService _cartera = context.read<CarteraService>();
  late final PerfilService _perfil = context.read<PerfilService>();

  List<Tarjeta>? _tarjetas;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Pide tarjetas y saldo. El saldo va sin esperar el resultado: si falla se
  /// queda el último conocido.
  Future<void> _cargar() async {
    _perfil.recargarPerfil();
    try {
      final lista = await _cartera.listarTarjetas();
      if (!mounted) return;
      setState(() {
        _tarjetas = lista;
        _errorCarga = null;
      });
    } on ExcepcionApi catch (e) {
      if (mounted) setState(() => _errorCarga = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorCarga = MensajesError.errorGeneral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartera',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: RefreshIndicator(
        color: AppColores.acento,
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _saldo(),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Mis tarjetas',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: oscuro
                            ? AppColores.textoOscuro
                            : AppColores.texto)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _agregarTarjeta,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _listaTarjetas(oscuro),
            const SizedBox(height: 24),
            Text(
              'Prototipo: los pagos son simulados. En producción se procesan '
              'con una pasarela segura.',
              style: TextStyle(
                  fontSize: 11,
                  color: oscuro ? AppColores.grisMedio : AppColores.grisTexto),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saldo() {
    return Container(
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
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          const SizedBox(height: 6),
          ValueListenableBuilder<EstadoSesion>(
            valueListenable: sesionActual,
            builder: (context, estado, _) {
              final saldo = estado.usuario?.saldo ?? widget.usuario.saldo;
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
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColores.dorado),
              onPressed: _recargar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Recargar saldo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaTarjetas(bool oscuro) {
    final tarjetas = _tarjetas;
    if (tarjetas == null && _errorCarga == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
            child: CircularProgressIndicator(color: AppColores.acento)),
      );
    }
    if (tarjetas == null) return _mensaje(_errorCarga!, oscuro);
    if (tarjetas.isEmpty) {
      return _mensaje('No tienes tarjetas guardadas.', oscuro);
    }
    return Column(
      children: tarjetas.map((t) => _tarjeta(t, oscuro)).toList(),
    );
  }

  Widget _mensaje(String texto, bool oscuro) => Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(texto,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: oscuro ? AppColores.grisMedio : AppColores.grisTexto)),
      );

  Widget _tarjeta(Tarjeta t, bool oscuro) {
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
            onPressed: () => _eliminar(t),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColores.error, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminar(Tarjeta t) async {
    final err = await _cartera.eliminarTarjeta(t.id);
    if (!mounted) return;
    if (err != null) {
      mostrarSnackBar(context, err, esError: true);
      return;
    }
    await _cargar();
  }

  Future<void> _recargar() async {
    final monto = await pedirMontoRecarga(context);
    if (monto == null) return;
    final err = await _cartera.recargarSaldo(monto);
    if (!mounted) return;
    mostrarSnackBar(context, err ?? 'Saldo recargado', esError: err != null);
    if (err == null) await _perfil.recargarPerfil();
  }

  Future<void> _agregarTarjeta() async {
    final datos = await pedirDatosTarjeta(context);
    if (datos == null) return;
    final err = await _cartera.agregarTarjeta(
      numero: datos.numero,
      titular: datos.titular,
      vencimiento: datos.vencimiento,
    );
    if (!mounted) return;
    mostrarSnackBar(context, err ?? 'Tarjeta agregada', esError: err != null);
    if (err == null) await _cargar();
  }
}
