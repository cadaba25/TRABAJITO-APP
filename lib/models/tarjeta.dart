import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory Tarjeta.desdeFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Tarjeta(
      id: doc.id,
      marca: d['marca'] ?? 'Tarjeta',
      ultimos4: d['ultimos4'] ?? '',
      titular: d['titular'] ?? '',
      vencimiento: d['vencimiento'] ?? '',
    );
  }

  Map<String, dynamic> aFirestore() => {
    'marca': marca,
    'ultimos4': ultimos4,
    'titular': titular,
    'vencimiento': vencimiento,
    'fechaCreacion': Timestamp.now(),
  };
}
