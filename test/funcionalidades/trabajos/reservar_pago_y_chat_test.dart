// Tarea 053: `DetalleTrabajoScreen` obtiene el acuerdo del chat REST
// (`GET /api/chats/trabajo/{id}`) antes de depositar, y abre el chat por el id
// del TRABAJO (el del chat es un UUID propio).
//
// Ojo: el backend NO valida el acuerdo (reporte 054, brecha 1; lo arregla la
// tarea 055). Estos tests fijan lo que hace el CLIENTE: no llamar a
// `reservar-pago` si el chat no está acordado por las dos partes, y mandar
// exactamente `pagoMonto`/`tiempoValor` cuando sí.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/modelos/publicacion.dart';
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/funcionalidades/chat/pantallas/chat_screen.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/detalle_trabajo_screen.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/configuracion_api.dart';
import 'package:trabajito/nucleo/inyeccion/proveedores.dart';

import '../../api/ayudas_api.dart';
import '../chat/chat_service_test.dart' show chatJson, idChat;

const _idTrabajo = 'trab-1';

final _empleador = Usuario(
  uid: 'emp-1',
  tipoUsuario: 'empleador',
  nombres: 'Marta',
  apellidos: 'Contratista',
  correo: 'marta@trabajito.test',
  fechaRegistro: DateTime(2026, 1, 1),
  rol: 'empleador',
);

Map<String, dynamic> _trabajo(String estado) => {
      'id': _idTrabajo,
      'empleadorId': 'emp-1',
      'autorNombre': 'Marta Contratista',
      'titulo': 'Instalar cerco',
      'descripcion': 'Cerco de malla en el patio',
      'categoria': 'Construcción',
      'departamento': 'Francisco Morazán',
      'ciudad': 'Tegucigalpa',
      'zona': 'Col. Kennedy',
      'presupuesto': 'L. 2500',
      'plazo': 'Corto plazo',
      'estado': estado,
      'trabajadorAsignadoId': 'tra-1',
      'trabajadorAsignadoNombre': 'Luis Mejía',
      'montoAcordado': 0,
      'tiempoAcordado': null,
      'pagoRetenido': false,
      'entregado': false,
      'pagoLiberado': false,
      'correccionSolicitada': false,
      'calificadoPorEmpleador': false,
      'calificadoPorTrabajador': false,
      'creadoEn': DateTime.now().toUtc().toIso8601String(),
    };

Map<String, dynamic> _chat({bool pago = true, bool tiempo = true}) => {
      ...chatJson(),
      'pagoMonto': 150,
      'pagoPropuestoPor': 'tra-1',
      'pagoAcordado': pago,
      'tiempoValor': '3 días',
      'tiempoPropuestoPor': 'tra-1',
      'tiempoAcordado': tiempo,
    };

void main() {
  tearDown(() => ApiClient.fijarInstancia(null));

  /// [chat] `null` = el servidor responde 404 (aún no hay chat).
  Future<EspiaHttp> montar(
    WidgetTester tester, {
    required Map<String, dynamic>? chat,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final espia = EspiaHttp();
    final (cliente, _) = await clienteConSesion(
      clienteFalso(espia, (http.Request p) async {
        if (p.url.path == RutasApi.chatDeTrabajo(_idTrabajo)) {
          return chat == null
              ? respuestaError(404, 'Sin chat')
              : respuestaJson(chat, 200);
        }
        if (p.url.path == RutasApi.reservarPago(_idTrabajo)) {
          return respuestaJson(_trabajo('ACORDADO'), 200);
        }
        if (p.url.path == RutasApi.chat(idChat) ||
            p.url.path == RutasApi.mensajesDe(idChat) ||
            p.url.path == RutasApi.chatLeido(idChat)) {
          return respuestaJson(
              p.url.path == RutasApi.chat(idChat) ? chatJson() : [], 200);
        }
        if (p.url.path == RutasApi.trabajo(_idTrabajo)) {
          return respuestaJson(_trabajo('ASIGNADO'), 200);
        }
        if (p.url.path == RutasApi.evidenciasDe(_idTrabajo)) {
          return respuestaJson([], 200);
        }
        return respuestaError(404, 'ruta inesperada ${p.url.path}');
      }),
      sesion: sesionDePrueba(),
    );
    ApiClient.fijarInstancia(cliente);
    await tester.pumpWidget(MultiProvider(
      providers: proveedoresDeLaApp(),
      child: MaterialApp(
        home: DetalleTrabajoScreen(
          publicacion: Publicacion.desdeJson(_trabajo('ASIGNADO')),
          usuario: _empleador,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return espia;
  }

  const boton = 'Confirmar acuerdo y depositar pago';

  testWidgets('con pago y tiempo acordados deposita el monto y tiempo del chat',
      (tester) async {
    final espia = await montar(tester, chat: _chat());
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();

    final post = espia.ultimaA(RutasApi.reservarPago(_idTrabajo));
    expect(post.method, 'POST');
    expect(jsonDecode(post.body), {'monto': 150, 'tiempo': '3 días'});
    expect(espia.llamadasA(RutasApi.chatDeTrabajo(_idTrabajo)), 1);
  });

  testWidgets('pago sin aceptar: no deposita y lo explica', (tester) async {
    final espia = await montar(tester, chat: _chat(pago: false));
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();

    expect(espia.llamadasA(RutasApi.reservarPago(_idTrabajo)), 0);
    expect(find.textContaining('acuerden el pago'), findsOneWidget);
  });

  testWidgets('tiempo sin aceptar: no deposita y lo explica', (tester) async {
    final espia = await montar(tester, chat: _chat(tiempo: false));
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();

    expect(espia.llamadasA(RutasApi.reservarPago(_idTrabajo)), 0);
    expect(find.textContaining('acuerden el tiempo'), findsOneWidget);
  });

  testWidgets('sin chat (404) tampoco deposita', (tester) async {
    final espia = await montar(tester, chat: null);
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();

    expect(espia.llamadasA(RutasApi.reservarPago(_idTrabajo)), 0);
    expect(find.textContaining('acuerden el pago'), findsOneWidget);
  });

  testWidgets('Abrir chat resuelve el chat por el id del trabajo',
      (tester) async {
    final espia = await montar(tester, chat: _chat());
    await tester.tap(find.text('Abrir chat'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(espia.llamadasA(RutasApi.chatDeTrabajo(_idTrabajo)), 1);
    // El ChatScreen usa el UUID del chat, no el del trabajo.
    expect(espia.llamadasA(RutasApi.chat(idChat)), greaterThanOrEqualTo(1));

    await tester.pumpWidget(const SizedBox()); // cancela el sondeo
  });

  testWidgets('Abrir chat sin chat todavía avisa en vez de abrir uno vacío',
      (tester) async {
    await montar(tester, chat: null);
    await tester.tap(find.text('Abrir chat'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsNothing);
    expect(find.textContaining('aún no está disponible'), findsOneWidget);
  });
}
