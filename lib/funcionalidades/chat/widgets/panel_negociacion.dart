import 'package:flutter/material.dart';

import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import '../datos/chat.dart';

/// Panel superior del chat: estado del pago y del tiempo con sus acciones.
///
/// La primera propuesta la hace siempre el trabajador (el servidor lo exige:
/// 400 si no); por eso el empleador ve "Esperando al trabajador" mientras no
/// haya propuesta.
class PanelNegociacion extends StatelessWidget {
  const PanelNegociacion({
    super.key,
    required this.chat,
    required this.miUid,
    required this.esTrabajador,
    required this.onProponerPago,
    required this.onAceptarPago,
    required this.onProponerTiempo,
    required this.onAceptarTiempo,
  });

  final Chat chat;
  final String miUid;
  final bool esTrabajador;
  final VoidCallback onProponerPago;
  final VoidCallback onAceptarPago;
  final VoidCallback onProponerTiempo;
  final VoidCallback onAceptarTiempo;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;

    return Container(
      color: oscuro ? AppColores.superficieOscura : AppColores.blanco,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          _Fila(
            icono: Icons.payments_outlined,
            titulo: 'Pago',
            valor: chat.pagoMonto > 0
                ? 'L. ${chat.pagoMonto.toStringAsFixed(0)} / hora'
                : 'Sin propuesta',
            acordado: chat.pagoAcordado,
            pendiente: chat.pagoPendiente,
            sinPropuesta: chat.pagoPropuestoPor.isEmpty,
            propuestoPorMi: chat.pagoPropuestoPor == miUid,
            esTrabajador: esTrabajador,
            onProponer: onProponerPago,
            onAceptar: onAceptarPago,
          ),
          Divider(height: 16, color: borde),
          _Fila(
            icono: Icons.schedule_rounded,
            titulo: 'Tiempo',
            valor: chat.tiempoValor.isNotEmpty
                ? chat.tiempoValor
                : 'Sin propuesta',
            acordado: chat.tiempoAcordado,
            pendiente: chat.tiempoPendiente,
            sinPropuesta: chat.tiempoPropuestoPor.isEmpty,
            propuestoPorMi: chat.tiempoPropuestoPor == miUid,
            esTrabajador: esTrabajador,
            onProponer: onProponerTiempo,
            onAceptar: onAceptarTiempo,
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.acordado,
    required this.pendiente,
    required this.sinPropuesta,
    required this.propuestoPorMi,
    required this.esTrabajador,
    required this.onProponer,
    required this.onAceptar,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final bool acordado;
  final bool pendiente;
  final bool sinPropuesta;
  final bool propuestoPorMi;
  final bool esTrabajador;
  final VoidCallback onProponer;
  final VoidCallback onAceptar;

  @override
  Widget build(BuildContext context) {
    Widget accion;
    if (acordado) {
      accion = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColores.verde, size: 18),
          SizedBox(width: 4),
          Text('Acordado',
              style: TextStyle(
                  color: AppColores.verde,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      );
    } else if (sinPropuesta) {
      accion = esTrabajador
          ? _BotonMini('Proponer', AppColores.acento, onProponer)
          : Text('Esperando al trabajador',
              style: TextStyle(color: colorTextoSuave(context), fontSize: 12));
    } else if (pendiente && !propuestoPorMi) {
      accion = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BotonMini('Aceptar', AppColores.verde, onAceptar),
          const SizedBox(width: 6),
          _BotonMini('Contraproponer', AppColores.acento, onProponer),
        ],
      );
    } else {
      accion = Text('Esperando…',
          style: TextStyle(color: colorTextoSuave(context), fontSize: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icono, size: 18, color: AppColores.azulProfesional),
            const SizedBox(width: 8),
            Text(titulo,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: colorTextoFuerte(context))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                valor,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color:
                        acordado ? AppColores.verde : colorTextoFuerte(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: accion),
      ],
    );
  }
}

class _BotonMini extends StatelessWidget {
  const _BotonMini(this.texto, this.color, this.onTap);

  final String texto;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(texto,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}
