import 'package:cloud_firestore/cloud_firestore.dart';

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

  // ── API propia (backend Spring Boot) ────────────────────────
  // ATENCIÓN: **el backend no tiene tarjetas**. Se revisó
  // `backend/src/main/java/com/trabajito/modules/pagos/` el 2026-08-27: hay
  // `MovimientoCartera` (el libro de saldo) pero ninguna entidad, tabla ni
  // endpoint de tarjeta; `/api/cartera` solo expone `recargar` y `movimientos`.
  //
  // Estos dos métodos usan por tanto los mismos nombres de campo que
  // Firestore, como forma provisional. Cuando la fase 2 migre
  // `cartera_service.dart` habrá que decidir con `backend-agent` y
  // `security-agent` si las tarjetas se guardan en el backend o desaparecen
  // (hoy la cartera es un prototipo sin pasarela de pago real).
  //
  // Lo que NO cambia: aquí nunca viaja el número completo ni el CVV.

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
