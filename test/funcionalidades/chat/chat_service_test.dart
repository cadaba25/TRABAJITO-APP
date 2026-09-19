// Tarea 053: ChatService contra la API. Los JSON siguen el contrato del reporte
// 054 (ChatRoom/Mensaje como entidades, `contenido`/`creadoEn`, tipo en
// MAYÚSCULAS, nulls), NO copiados de un servidor en vivo.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trabajito/funcionalidades/chat/datos/chat_service.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/configuracion_api.dart';

import '../../api/ayudas_api.dart';

const idChat = 'c1111111-1111-4111-8111-111111111111';
const idOtro = 'c2222222-2222-4222-8222-222222222222';
const idTrabajo = 'a3333333-3333-4333-8333-333333333333';

Map<String, dynamic> chatJson({
  String id = idChat,
  String ultimo = 'Hola',
  String fecha = '2026-09-18T19:27:32.101Z',
  bool pagoAcordado = false,
}) =>
    {
      'id': id,
      'trabajoId': idTrabajo,
      'tituloTrabajo': 'Pintar fachada',
      'empleadorId': 'emp-1',
      'empleadorNombre': 'Ana Pérez',
      'trabajadorId': 'tra-1',
      'trabajadorNombre': 'Luis Mejía',
      'ultimoMensaje': ultimo,
      'fechaUltimoMensaje': fecha,
      'pagoMonto': 0,
      'pagoPropuestoPor': null,
      'pagoAcordado': pagoAcordado,
      'tiempoValor': null,
      'tiempoPropuestoPor': null,
      'tiempoAcordado': false,
    };

Future<(ChatService, EspiaHttp)> montar(
    Future<http.Response> Function(http.Request p) responder) async {
  final espia = EspiaHttp();
  final (cliente, _) = await clienteConSesion(
    clienteFalso(espia, responder),
    sesion: sesionDePrueba(),
  );
  ApiClient.fijarInstancia(cliente);
  addTearDown(() => ApiClient.fijarInstancia(null));
  return (ChatService(), espia);
}

void main() {
  group('lecturas', () {
    test('misChats une la lista con no-leidos y ordena por último mensaje',
        () async {
      final (s, espia) = await montar((p) async {
        if (p.url.path == RutasApi.chats) {
          return respuestaJson([
            chatJson(fecha: '2026-09-18T10:00:00Z'),
            chatJson(id: idOtro, fecha: '2026-09-18T12:00:00Z'),
          ], 200);
        }
        if (p.url.path == RutasApi.chatsNoLeidos) {
          return respuestaJson({
            'total': 3,
            'porChat': {idChat: 2, idOtro: 1},
          }, 200);
        }
        return respuestaError(404, 'no');
      });
      final chats = await s.misChats();
      expect(chats.map((c) => c.id), [idOtro, idChat]);
      expect(chats.first.noLeidos, 1);
      expect(chats.last.noLeidos, 2);
      expect(chats.first.pagoPropuestoPor, ''); // null -> ''
      expect(espia.llamadasA(RutasApi.chatsNoLeidos), 1);
    });

    test('si no-leidos falla, la lista se devuelve igual con 0', () async {
      final (s, _) = await montar((p) async {
        if (p.url.path == RutasApi.chats) {
          return respuestaJson([chatJson()], 200);
        }
        return respuestaError(500, 'boom');
      });
      final chats = await s.misChats();
      expect(chats, hasLength(1));
      expect(chats.single.noLeidos, 0);
    });

    test('totalNoLeidos lee total', () async {
      final (s, _) = await montar((p) async =>
          respuestaJson({'total': 4, 'porChat': <String, int>{}}, 200));
      expect(await s.totalNoLeidos(), 4);
    });

    test('chatDeTrabajo usa el id del trabajo y devuelve null en 404',
        () async {
      final (s, espia) = await montar((p) async {
        if (p.url.path == RutasApi.chatDeTrabajo(idTrabajo)) {
          return respuestaJson(chatJson(), 200);
        }
        return respuestaError(404, 'sin chat');
      });
      final chat = await s.chatDeTrabajo(idTrabajo);
      expect(chat!.id, idChat);
      expect(chat.idPublicacion, idTrabajo);
      expect(await s.chatDeTrabajo('otro'), isNull);
      expect(espia.peticiones.first.method, 'GET');
    });

    test('mensajes sin desde no manda parámetro; con desde manda ISO en UTC',
        () async {
      final (s, espia) = await montar((p) async => respuestaJson([
            {
              'id': 'm1',
              'chatId': idChat,
              'deUid': 'tra-1',
              'tipo': 'TEXTO',
              'contenido': 'hola',
              'leido': false,
              'creadoEn': '2026-09-18T19:27:32.5Z',
            },
            {
              'id': 'm2',
              'deUid': 'emp-1',
              'tipo': 'SISTEMA',
              'contenido': 'Pago acordado: L. 150.00 / hora',
              'creadoEn': '2026-09-18T19:28:00Z',
            },
          ], 200));
      final todos = await s.mensajes(idChat);
      expect(espia.peticiones.last.url.queryParameters, isEmpty);
      expect(todos.map((m) => m.texto),
          ['hola', 'Pago acordado: L. 150.00 / hora']);
      expect(todos.first.esSistema, isFalse);
      expect(todos.last.esSistema, isTrue);

      await s.mensajes(idChat, desde: DateTime.utc(2026, 9, 18, 19, 27, 32));
      final desde = espia.peticiones.last.url.queryParameters['desde']!;
      expect(desde, startsWith('2026-09-18T19:27:32'));
      expect(desde, endsWith('Z'));
    });

    test('una respuesta que no es lista lanza en vez de fingir vacío',
        () async {
      final (s, _) = await montar((p) async => respuestaJson({'x': 1}, 200));
      expect(() => s.mensajes(idChat), throwsA(anything));
    });
  });

  group('acciones', () {
    test('enviarMensaje manda solo contenido (recortado) y no envía vacíos',
        () async {
      final (s, espia) = await montar((p) async => respuestaJson({}, 201));
      expect(await s.enviarMensaje(idChat, '   '), isNull);
      expect(espia.peticiones, isEmpty);
      expect(await s.enviarMensaje(idChat, '  hola  '), isNull);
      final p = espia.ultimaA(RutasApi.mensajesDe(idChat));
      expect(p.method, 'POST');
      expect(jsonDecode(p.body), {'contenido': 'hola'});
    });

    test('proponer/aceptar pago y tiempo pegan a su ruta con su cuerpo',
        () async {
      final (s, espia) =
          await montar((p) async => respuestaJson(chatJson(), 200));
      expect(await s.proponerPago(idChat, 150), isNull);
      expect(jsonDecode(espia.ultimaA(RutasApi.proponerPago(idChat)).body),
          {'monto': 150});
      expect(await s.aceptarPago(idChat), isNull);
      expect(espia.ultimaA(RutasApi.aceptarPago(idChat)).method, 'POST');
      expect(await s.proponerTiempo(idChat, '3 días'), isNull);
      expect(jsonDecode(espia.ultimaA(RutasApi.proponerTiempo(idChat)).body),
          {'tiempo': '3 días'});
      expect(await s.aceptarTiempo(idChat), isNull);
      expect(espia.llamadasA(RutasApi.aceptarTiempo(idChat)), 1);
    });

    test('el 400 del servidor llega tal cual (primera propuesta: trabajador)',
        () async {
      final (s, _) = await montar((p) async =>
          respuestaError(400, 'La primera propuesta la hace el trabajador'));
      expect(await s.proponerPago(idChat, 100),
          'La primera propuesta la hace el trabajador');
    });

    test('marcarLeido hace POST y nunca lanza', () async {
      final (s, espia) = await montar((p) async => respuestaError(500, 'x'));
      await s.marcarLeido(idChat);
      expect(espia.ultimaA(RutasApi.chatLeido(idChat)).method, 'POST');
    });
  });
}
