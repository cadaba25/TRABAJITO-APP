import 'package:flutter/foundation.dart';

import '../../../compartido/modelos/tarjeta.dart';
import '../../../nucleo/api/api_client.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../../nucleo/api/configuracion_api.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import 'movimiento_cartera.dart';

/// Cartera **contra el backend propio** (`/api/cartera/**`). Migrado desde
/// Firestore en la tarea 052.
///
/// - `streamSaldo(uid)` desapareció: el saldo viene en `SesionUsuario`; tras
///   recargar, la pantalla llama a `PerfilService.recargarPerfil()`.
/// - `streamTarjetas(uid)` es ahora [listarTarjetas], carga puntual.
/// - `eliminarTarjeta(uid, id)` es ahora [eliminarTarjeta] `(id)`: el uid sale
///   del JWT.
///
/// Prototipo: sin pasarela de pago real. El número completo viaja una sola
/// vez en el alta y el servidor solo guarda los últimos 4 dígitos.
class CarteraService {
  CarteraService({ApiClient? cliente}) : _api = cliente ?? ApiClient.instancia;

  final ApiClient _api;

  /// Tarjetas propias. Lanza [ExcepcionApi] si falla.
  Future<List<Tarjeta>> listarTarjetas() async {
    final lista = await _lista(RutasApi.tarjetas);
    return [for (final t in lista) Tarjeta.desdeJson(t)];
  }

  /// Historial de movimientos propios. Lanza [ExcepcionApi] si falla.
  Future<List<MovimientoCartera>> movimientos() async {
    final lista = await _lista(RutasApi.movimientos);
    return [for (final m in lista) MovimientoCartera.desdeJson(m)];
  }

  /// Agrega una tarjeta. `null` si fue bien, o el texto del error.
  Future<String?> agregarTarjeta({
    required String numero,
    required String titular,
    required String vencimiento,
  }) {
    return _intentar(() async {
      final limpio = numero.replaceAll(RegExp(r'\s'), '');
      if (limpio.length < 13) return 'Número de tarjeta inválido';
      await _api.crear(RutasApi.tarjetas, cuerpo: {
        'numero': limpio,
        'titular': titular.trim(),
        'vencimiento': vencimiento.trim(),
        // Solo para el icono: si falta, el servidor la deduce igual.
        'marca': Tarjeta.marcaDesdeNumero(limpio),
      });
      return null;
    });
  }

  /// Borra una tarjeta propia (403 si es ajena, 404 si no existe).
  Future<String?> eliminarTarjeta(String id) {
    return _intentar(() async {
      await _api.eliminar(RutasApi.tarjeta(id));
      return null;
    });
  }

  /// Recarga saldo (simulado). El servidor responde el saldo nuevo, pero la
  /// fuente de verdad del saldo en pantalla es la sesión: recargar el perfil
  /// después.
  Future<String?> recargarSaldo(double monto) {
    return _intentar(() async {
      await _api.crear(RutasApi.recargar, cuerpo: {'monto': monto});
      return null;
    });
  }

  Future<List<Map<String, dynamic>>> _lista(String ruta) async {
    final json = await _api.obtener(ruta);
    if (json is! List) {
      throw RespuestaIlegible(detalle: 'Se esperaba una lista en $ruta');
    }
    return [
      for (final e in json)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  Future<String?> _intentar(Future<String?> Function() operacion) async {
    try {
      return await operacion();
    } on ExcepcionApi catch (e) {
      if (e.campos.isNotEmpty) return e.campos.values.first;
      return e.mensaje;
    } catch (e) {
      debugPrint('Fallo inesperado en CarteraService: $e');
      return MensajesError.errorGeneral;
    }
  }
}
