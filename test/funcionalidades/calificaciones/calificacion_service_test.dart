// Tarea 052: CalificacionService contra la API. JSON según
// `CalificacionResponse` / `CalificacionController` (código Java), no de un
// servidor en vivo.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/funcionalidades/calificaciones/datos/calificacion_service.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/configuracion_api.dart';

import '../../api/ayudas_api.dart';

Map<String, dynamic> _cal(String id, String creadoEn, {int estrellas = 5}) => {
      'id': id,
      'trabajoId': 't-1',
      'autorId': 'a-1',
      'receptorId': 'r-1',
      'rolCalificado': 'TRABAJADOR',
      'estrellas': estrellas,
      'comentario': 'Bien',
      'creadoEn': creadoEn,
    };

Future<(CalificacionService, EspiaHttp)> montar(
    Future<dynamic> Function() responder) async {
  final espia = EspiaHttp();
  final (cliente, _) = await clienteConSesion(
    clienteFalso(espia, (p) async => await responder()),
    sesion: sesionDePrueba(),
  );
  ApiClient.fijarInstancia(cliente);
  addTearDown(() => ApiClient.fijarInstancia(null));
  return (CalificacionService(), espia);
}

void main() {
  test('calificar manda solo trabajoId, estrellas y comentario', () async {
    final (s, espia) =
        await montar(() async => respuestaJson(_cal('c-1', '2026-09-10T00:00:00Z'), 200));
    final err =
        await s.calificar(idTrabajo: 't-1', estrellas: 4, comentario: 'Bien');
    expect(err, isNull);
    final p = espia.ultimaA(RutasApi.calificaciones);
    expect(p.method, 'POST');
    expect(jsonDecode(p.body),
        {'trabajoId': 't-1', 'estrellas': 4, 'comentario': 'Bien'});
  });

  test('un 409 ("Ya calificaste este trabajo") llega tal cual', () async {
    final (s, _) = await montar(
        () async => respuestaError(409, 'Ya calificaste este trabajo'));
    expect(await s.calificar(idTrabajo: 't-1', estrellas: 5),
        'Ya calificaste este trabajo');
  });

  test('listarDe pide /usuario/{id}, mapea y ordena de la más nueva', () async {
    final (s, espia) = await montar(() async => respuestaJson([
          _cal('vieja', '2026-09-01T00:00:00Z', estrellas: 3),
          _cal('nueva', '2026-09-09T00:00:00Z'),
        ], 200));
    final l = await s.listarDe('r-1');
    expect(l.map((c) => c.id), ['nueva', 'vieja']);
    expect(l.first.rolCalificado, 'TRABAJADOR');
    expect(l.first.deNombre, '', reason: 'el backend no manda el nombre');
    expect(espia.peticiones.single.url.path,
        RutasApi.calificacionesDe('r-1'));
    expect(espia.peticiones.single.url.queryParameters, isEmpty);
  });

  test('listarDe con rol manda ?rol=', () async {
    final (s, espia) = await montar(() async => respuestaJson([], 200));
    await s.listarDe('r-1', rol: 'EMPLEADOR');
    expect(espia.peticiones.single.url.queryParameters, {'rol': 'EMPLEADOR'});
  });
}
