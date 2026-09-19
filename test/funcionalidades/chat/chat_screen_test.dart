// Tarea 053: ChatScreen y ChatsTab con ChatService inyectado, contra un
// backend falso. Se comprueba el sondeo (incremental con `desde`, sin
// duplicados, cancelado en dispose, pausado en segundo plano) y las reglas de
// la negociación que la pantalla pinta.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/funcionalidades/chat/datos/chat.dart';
import 'package:trabajito/funcionalidades/chat/pantallas/chat_screen.dart';
import 'package:trabajito/funcionalidades/chat/pantallas/chats_tab.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/configuracion_api.dart';
import 'package:trabajito/nucleo/inyeccion/proveedores.dart';

import '../../api/ayudas_api.dart';
import 'chat_service_test.dart' show chatJson, idChat, idOtro;

Usuario usuario(String uid, String rol) => Usuario(
      uid: uid,
      tipoUsuario: rol,
      nombres: 'Nombre',
      apellidos: 'Apellido',
      correo: 'x@trabajito.test',
      fechaRegistro: DateTime(2026, 1, 1),
      rol: rol,
    );

Map<String, dynamic> msg(String id, String texto, String de, String creadoEn,
        {String tipo = 'TEXTO'}) =>
    {
      'id': id,
      'chatId': idChat,
      'deUid': de,
      'tipo': tipo,
      'contenido': texto,
      'leido': false,
      'creadoEn': creadoEn,
    };

void main() {
  tearDown(() => ApiClient.fijarInstancia(null));

  Future<EspiaHttp> montar(
    WidgetTester tester,
    Widget pantalla,
    Future<http.Response> Function(http.Request) responder,
  ) async {
    final espia = EspiaHttp();
    final (cliente, _) = await clienteConSesion(
        clienteFalso(espia, responder),
        sesion: sesionDePrueba());
    ApiClient.fijarInstancia(cliente);
    await tester.pumpWidget(MultiProvider(
      providers: proveedoresDeLaApp(),
      child: MaterialApp(home: pantalla),
    ));
    await tester.pumpAndSettle();
    return espia;
  }

  int llamadasMensajes(EspiaHttp e) =>
      e.peticiones
          .where((p) =>
              p.method == 'GET' && p.url.path == RutasApi.mensajesDe(idChat))
          .length;

  group('ChatScreen', () {
    final chat = Chat.desdeJson(chatJson());
    final trabajador = usuario('tra-1', 'trabajador');
    final empleador = usuario('emp-1', 'empleador');

    Future<http.Response> Function(http.Request) backend({
      Map<String, dynamic>? chatActual,
      List<Map<String, dynamic>> Function(http.Request p)? mensajes,
    }) =>
        (p) async {
          if (p.url.path == RutasApi.chat(idChat)) {
            return respuestaJson(chatActual ?? chatJson(), 200);
          }
          if (p.url.path == RutasApi.mensajesDe(idChat) && p.method == 'GET') {
            return respuestaJson(
                mensajes?.call(p) ??
                    [msg('m1', 'hola jefe', 'emp-1', '2026-09-18T19:00:00Z')],
                200);
          }
          if (p.url.path == RutasApi.chatLeido(idChat)) {
            return respuestaJson(null, 200);
          }
          return respuestaError(404, 'ruta inesperada ${p.url.path}');
        };

    testWidgets('carga los mensajes, marca leído y muestra el título',
        (tester) async {
      final espia = await montar(
          tester,
          ChatScreen(chat: chat, usuario: trabajador),
          backend());
      expect(find.text('hola jefe'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget); // el otro, en el título
      expect(espia.llamadasA(RutasApi.chatLeido(idChat)), 1);
    });

    testWidgets(
        'el sondeo pide solo lo nuevo (desde), sin duplicar mensajes ya vistos',
        (tester) async {
      final espia = await montar(
        tester,
        ChatScreen(chat: chat, usuario: trabajador),
        backend(mensajes: (p) {
          final desde = p.url.queryParameters['desde'];
          if (desde == null) {
            return [msg('m1', 'hola jefe', 'emp-1', '2026-09-18T19:00:00Z')];
          }
          // El servidor devuelve m1 otra vez (redondeo de microsegundos) y m2.
          return [
            msg('m1', 'hola jefe', 'emp-1', '2026-09-18T19:00:00Z'),
            msg('m2', 'llego a las 8', 'emp-1', '2026-09-18T19:01:00Z'),
          ];
        }),
      );
      expect(llamadasMensajes(espia), 1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final ultima = espia.peticiones.lastWhere((p) =>
          p.method == 'GET' && p.url.path == RutasApi.mensajesDe(idChat));
      expect(ultima.url.queryParameters['desde'], startsWith('2026-09-18T19:00:00'));
      expect(find.text('hola jefe'), findsOneWidget);
      expect(find.text('llego a las 8'), findsOneWidget);
    });

    testWidgets('al salir de la pantalla el Timer se cancela', (tester) async {
      final espia = await montar(
          tester, ChatScreen(chat: chat, usuario: trabajador), backend());
      final antes = llamadasMensajes(espia);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(llamadasMensajes(espia), antes);
    });

    testWidgets('en segundo plano no sondea y al volver pide al instante',
        (tester) async {
      final espia = await montar(
          tester, ChatScreen(chat: chat, usuario: trabajador), backend());
      final antes = llamadasMensajes(espia);

      // Las transiciones válidas de Flutter pasan por inactive y hidden.
      for (final e in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(e);
      }
      await tester.pump(const Duration(seconds: 30));
      expect(llamadasMensajes(espia), antes);

      for (final e in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(e);
      }
      await tester.pumpAndSettle();
      expect(llamadasMensajes(espia), antes + 1);
    });

    testWidgets('enviar hace POST con contenido y refresca', (tester) async {
      var enviado = false;
      final base = backend(mensajes: (p) => [
            msg('m1', 'hola jefe', 'emp-1', '2026-09-18T19:00:00Z'),
            if (enviado) msg('m2', 'ok, voy', 'tra-1', '2026-09-18T19:02:00Z'),
          ]);
      final espia = await montar(
        tester,
        ChatScreen(chat: chat, usuario: trabajador),
        (p) async {
          if (p.method == 'POST' && p.url.path == RutasApi.mensajesDe(idChat)) {
            enviado = true;
            return respuestaJson({}, 201);
          }
          return base(p);
        },
      );
      await tester.enterText(find.byType(TextField), 'ok, voy');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      final post = espia.peticiones.firstWhere(
          (p) => p.method == 'POST' && p.url.path == RutasApi.mensajesDe(idChat));
      expect(jsonDecode(post.body), {'contenido': 'ok, voy'});
      expect(find.text('ok, voy'), findsOneWidget);
    });

    testWidgets(
        'sin propuesta, el empleador espera al trabajador; el trabajador puede proponer',
        (tester) async {
      await montar(tester, ChatScreen(chat: chat, usuario: empleador),
          backend());
      expect(find.text('Esperando al trabajador'), findsNWidgets(2));
      expect(find.text('Proponer'), findsNothing);
    });

    testWidgets('el trabajador ve Proponer en pago y tiempo', (tester) async {
      await montar(tester, ChatScreen(chat: chat, usuario: trabajador),
          backend());
      expect(find.text('Proponer'), findsNWidgets(2));
    });

    testWidgets('propuesta del otro: se puede Aceptar, y llama a aceptar-pago',
        (tester) async {
      var aceptado = false;
      final propuesto = {
        ...chatJson(),
        'pagoMonto': 150,
        'pagoPropuestoPor': 'tra-1',
        'pagoAcordado': false,
      };
      final base = backend(chatActual: propuesto);
      final espia = await montar(
        tester,
        ChatScreen(chat: Chat.desdeJson(propuesto), usuario: empleador),
        (p) async {
          if (p.url.path == RutasApi.aceptarPago(idChat)) {
            aceptado = true;
            return respuestaJson({...propuesto, 'pagoAcordado': true}, 200);
          }
          if (aceptado && p.url.path == RutasApi.chat(idChat)) {
            return respuestaJson({...propuesto, 'pagoAcordado': true}, 200);
          }
          return base(p);
        },
      );
      expect(find.text('L. 150 / hora'), findsOneWidget);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(espia.llamadasA(RutasApi.aceptarPago(idChat)), 1);
      expect(find.text('Acordado'), findsOneWidget);
    });

    testWidgets('si la carga inicial falla enseña aviso y reintenta',
        (tester) async {
      var fallar = true;
      final base = backend();
      await montar(tester, ChatScreen(chat: chat, usuario: trabajador),
          (p) async => fallar ? respuestaError(500, 'boom') : base(p));
      expect(find.textContaining('No pudimos cargar'), findsOneWidget);

      fallar = false;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('hola jefe'), findsOneWidget);
    });
  });

  group('ChatsTab', () {
    final empleador = usuario('emp-1', 'empleador');

    Future<http.Response> Function(http.Request) backend(
            List<Map<String, dynamic>> chats) =>
        (p) async {
          if (p.url.path == RutasApi.chats) return respuestaJson(chats, 200);
          if (p.url.path == RutasApi.chatsNoLeidos) {
            return respuestaJson({
              'total': 2,
              'porChat': {idChat: 2},
            }, 200);
          }
          return respuestaError(404, 'ruta inesperada ${p.url.path}');
        };

    testWidgets('lista los chats con su contador de no leídos',
        (tester) async {
      await montar(tester, ChatsTab(usuario: empleador),
          backend([chatJson(ultimo: 'ya casi llego')]));
      expect(find.text('Luis Mejía'), findsOneWidget);
      expect(find.text('Pintar fachada'), findsOneWidget);
      expect(find.text('ya casi llego'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('sin chats explica cuándo se crean', (tester) async {
      await montar(tester, ChatsTab(usuario: empleador), backend([]));
      expect(find.textContaining('Se crean al seleccionar a un postulante'),
          findsOneWidget);
    });

    testWidgets('sondea la lista y refleja un chat nuevo', (tester) async {
      var chats = [chatJson()];
      final espia = await montar(tester, ChatsTab(usuario: empleador),
          (p) => backend(chats)(p));
      expect(find.text('Luis Mejía'), findsOneWidget);

      chats = [
        chatJson(),
        {
          ...chatJson(id: idOtro),
          'trabajadorNombre': 'María Paz',
        },
      ];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('María Paz'), findsOneWidget);
      expect(espia.llamadasA(RutasApi.chats), greaterThanOrEqualTo(2));
    });

    testWidgets('si falla la primera carga lo dice y no finge que no hay',
        (tester) async {
      await montar(tester, ChatsTab(usuario: empleador),
          (p) async => respuestaError(500, 'boom'));
      expect(find.textContaining('No pudimos cargar tus chats'),
          findsOneWidget);
      expect(find.textContaining('Se crean al seleccionar'), findsNothing);
    });

    testWidgets('dispose cancela el sondeo', (tester) async {
      final espia = await montar(
          tester, ChatsTab(usuario: empleador), backend([chatJson()]));
      final antes = espia.llamadasA(RutasApi.chats);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
      expect(espia.llamadasA(RutasApi.chats), antes);
    });
  });
}
