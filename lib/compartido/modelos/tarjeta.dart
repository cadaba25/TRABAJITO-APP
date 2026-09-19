import 'json_utiles.dart';

/// Tarjeta guardada en la cartera del usuario.
/// Por seguridad solo se almacenan los últimos 4 dígitos (nunca el número
/// completo ni el CVV).
class Tarjeta {
  final String id;
  final String marca;       // 'Visa' | 'Mastercard' | 'Tarjeta'
  final String ultimos4;
  final String titular;
  final String vencimiento; // MM/AA

  const Tarjeta({
    this.id = '',
    required this.marca,
    required this.ultimos4,
    required this.titular,
    required this.vencimiento,
  });

  /// Deduce la marca a partir del primer dígito del número.
  static String marcaDesdeNumero(String numero) {
    final n = numero.replaceAll(RegExp(r'\s'), '');
    if (n.startsWith('4')) return 'Visa';
    if (n.startsWith('5') || n.startsWith('2')) return 'Mastercard';
    if (n.startsWith('3')) return 'Amex';
    return 'Tarjeta';
  }

  /// `TarjetaResponse` del backend (`/api/cartera/tarjetas`): `id`, `marca`,
  /// `ultimos4`, `titular`, `vencimiento`. Nunca lleva el número completo ni
  /// el CVV.
  factory Tarjeta.desdeJson(Map<String, dynamic> json) => Tarjeta(
    id: textoJson(json['id']),
    marca: textoJson(json['marca'], 'Tarjeta'),
    ultimos4: textoJson(json['ultimos4']),
    titular: textoJson(json['titular']),
    vencimiento: textoJson(json['vencimiento']),
  );

  Map<String, dynamic> aJson() => {
    'marca': marca,
    'ultimos4': ultimos4,
    'titular': titular,
    'vencimiento': vencimiento,
  };
}
