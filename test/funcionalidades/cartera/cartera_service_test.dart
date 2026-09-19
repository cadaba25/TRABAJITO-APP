// Tarea 052: CarteraService contra la API. Los JSON son los que produce el
// código Java (`TarjetaResponse`, entidad `MovimientoCartera`, `PagoController`
// y `docs/api.md`), NO copiados de un servidor en vivo: no hay acceso a la VM
// desde este entorno.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/funcionalidades/cartera/datos/cartera_service.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/configuracion_api.dart';

import '../../api/ayudas_api.dart';

const _idTarjeta = 'b7e1c9a0-1d2e-4f3a-8b4c-5d6e7f8a9b0c';

Future<(CarteraService, EspiaHttp)> montar(
    Future<dynamic> Function(String metodo, String ruta) responder) async {
  final espia = EspiaHttp();
  final (cliente, _) = await clienteConSesion(
    clienteFalso(espia, (p) async {
      final r = await responder(p.method, p.url.path);
      return r;
    }),
    sesion: sesionDePrueba(),
  );
  ApiClient.fijarInstancia(cliente);
  addTearDown(() => ApiClient.fijarInstancia(null));
  return (CarteraService(), espia);
}

void main() {
  test('listarTarjetas mapea TarjetaResponse', () async {
    final (s, espia) = await montar((m, r) async => respuestaJson([
          {
            'id': _idTarjeta,
            'marca': 'Visa',
            'ultimos4': '4242',
            'titular': 'Ana Qa',
            'vencimiento': '12/28',
          }
        ], 200));
    final l = await s.listarTarjetas();
    expect(l, hasLength(1));
    expect(l.first.id, _idTarjeta);
    expect(l.first.marca, 'Visa');
    expect(l.first.ultimos4, '4242');
    expect(espia.peticiones.single.method, 'GET');
    expect(espia.rutas.single, RutasApi.tarjetas);
  });

  test('agregarTarjeta manda numero limpio, titular y vencimiento', () async {
    final (s, espia) = await montar((m, r) async => respuestaJson({
          'id': _idTarjeta,
          'marca': 'Visa',
          'ultimos4': '4242',
          'titular': 'Ana',
          'vencimiento': '12/28',
        }, 201));
    final err = await s.agregarTarjeta(
        numero: '4242 4242 4242 4242', titular: ' Ana ', vencimiento: '12/28');
    expect(err, isNull);
    final p = espia.ultimaA(RutasApi.tarjetas);
    expect(p.method, 'POST');
    expect(jsonDecode(p.body), {
      'numero': '4242424242424242',
      'titular': 'Ana',
      'vencimiento': '12/28',
      'marca': 'Visa',
    });
  });

  test('agregarTarjeta rechaza en el cliente un número de menos de 13 dígitos',
      () async {
    final (s, espia) = await montar((m, r) async => respuestaJson({}, 201));
    final err = await s.agregarTarjeta(
        numero: '1234', titular: 'Ana', vencimiento: '12/28');
    expect(err, 'Número de tarjeta inválido');
    expect(espia.peticiones, isEmpty);
  });

  test('agregarTarjeta devuelve el mensaje del servidor si falla (400 campos)',
      () async {
    final (s, _) = await montar((m, r) async => respuestaError(
        400, 'Datos inválidos',
        campos: {'titular': 'Ingresa el nombre del titular'}));
    final err = await s.agregarTarjeta(
        numero: '4242424242424242', titular: '', vencimiento: '12/28');
    expect(err, 'Ingresa el nombre del titular');
  });

  test('eliminarTarjeta hace DELETE por id, sin uid', () async {
    final (s, espia) = await montar((m, r) async => respuestaJson(null, 200));
    expect(await s.eliminarTarjeta(_idTarjeta), isNull);
    expect(espia.peticiones.single.method, 'DELETE');
    expect(espia.rutas.single, RutasApi.tarjeta(_idTarjeta));
  });

  test('eliminarTarjeta ajena (403) devuelve el mensaje', () async {
    final (s, _) = await montar(
        (m, r) async => respuestaError(403, 'Esa tarjeta no es tuya'));
    expect(await s.eliminarTarjeta(_idTarjeta), 'Esa tarjeta no es tuya');
  });

  test('recargarSaldo manda {monto} a /api/cartera/recargar', () async {
    final (s, espia) = await montar((m, r) async => respuestaJson(150.0, 200));
    expect(await s.recargarSaldo(100), isNull);
    final p = espia.ultimaA(RutasApi.recargar);
    expect(p.method, 'POST');
    expect(jsonDecode(p.body), {'monto': 100.0});
  });

  test('movimientos mapea la entidad MovimientoCartera', () async {
    final (s, _) = await montar((m, r) async => respuestaJson([
          {
            'id': 'm-1',
            'usuarioId': 'u-1',
            'tipo': 'RECARGA',
            'monto': 100.00,
            'saldoResultante': 100.00,
            'trabajoId': null,
            'descripcion': 'Recarga de saldo',
            'creadoEn': '2026-09-10T15:00:00Z',
          },
          {
            'id': 'm-2',
            'tipo': 'RETENCION',
            'monto': -40.5,
            'saldoResultante': 59.5,
            'trabajoId': 't-1',
          }
        ], 200));
    final l = await s.movimientos();
    expect(l, hasLength(2));
    expect(l[0].tipo, 'RECARGA');
    expect(l[0].monto, 100.0);
    expect(l[0].trabajoId, '');
    expect(l[1].monto, -40.5);
    expect(l[1].saldoResultante, 59.5);
    expect(l[1].trabajoId, 't-1');
  });
}
