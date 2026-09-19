import '../../../compartido/modelos/json_utiles.dart';

/// Un movimiento del libro de saldo (`GET /api/cartera/movimientos`).
///
/// Campos reales de la entidad `MovimientoCartera` del backend (se devuelve
/// tal cual, sin DTO): `id`, `usuarioId`, `tipo` (RECARGA, RETIRO, RETENCION,
/// LIBERACION, REEMBOLSO), `monto` (negativo = débito), `saldoResultante`,
/// `trabajoId`, `descripcion`, `creadoEn`.
class MovimientoCartera {
  final String id;
  final String tipo;
  final double monto;
  final double saldoResultante;
  final String trabajoId;
  final String descripcion;
  final DateTime fecha;

  const MovimientoCartera({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.saldoResultante,
    this.trabajoId = '',
    this.descripcion = '',
    required this.fecha,
  });

  factory MovimientoCartera.desdeJson(Map<String, dynamic> json) =>
      MovimientoCartera(
        id: textoJson(json['id']),
        tipo: textoJson(json['tipo']),
        monto: decimalJson(json['monto']),
        saldoResultante: decimalJson(json['saldoResultante']),
        trabajoId: textoJson(json['trabajoId']),
        descripcion: textoJson(json['descripcion']),
        fecha: fechaJson(json['creadoEn']),
      );
}
