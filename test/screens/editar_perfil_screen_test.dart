// Regresión de la tarea 022 (revisión de QA de la migración).
//
// `EditarPerfilScreen` recibe un `Usuario` que puede NO venir de una lectura
// completa del perfil. Pasa de verdad: cuando la app arranca sin conexión,
// `AuthService.restaurarSesion()` entra con el perfil que se guardó junto a la
// sesión —el que devolvió el login—, y ese trae `habilidades`, `experiencia` y
// `estudios` a `null` (`cvCargado == false`) y puede estar viejo en todo lo
// demás.
//
// Reproducido en el emulador Pixel_6 el 2026-08-29 contra el backend real:
// con la app arrancada en modo avión y la red devuelta después, abrir "Editar
// perfil" y pulsar "Guardar cambios" **borró la presentación** que sí estaba
// en el servidor y **descartó en silencio** la habilidad que se acababa de
// escribir, enseñando igualmente "Perfil actualizado".
//
// Estos tests fijan las dos mitades del arreglo: si el perfil viene a medias
// se pide entero antes de dejar editar, y si no se puede pedir no se enseña
// el formulario.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trabajito/models/usuario.dart';
import 'package:trabajito/screens/editar_perfil_screen.dart';
import 'package:trabajito/services/api/api_client.dart';
import 'package:trabajito/services/api/configuracion_api.dart';
import 'package:trabajito/services/sesion_usuario.dart';

import '../api/ayudas_api.dart';

/// Perfil tal y como llega en la respuesta del login: sin las tres listas del
/// CV y con lo demás potencialmente viejo.
Map<String, dynamic> perfilDeLogin() => {
      'id': '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc',
      'correo': 'ana@trabajito.test',
      'nombres': 'Ana',
      'apellidos': 'QaVeintidos',
      'rol': 'TRABAJADOR',
      'telefono': '99887766',
      'presentacion': null,
      'activo': true,
      'registroCompleto': true,
      'habilidades': null,
      'experiencia': null,
      'estudios': null,
    };

/// Lo que devuelve `GET /api/auth/yo`: el perfil de verdad, con CV.
Map<String, dynamic> perfilCompleto() => {
      ...perfilDeLogin(),
      'presentacion': 'Plomera con 6 años de experiencia',
      'habilidades': ['Plomería', 'Electricidad'],
      'experiencia': const <Map<String, dynamic>>[],
      'estudios': const <Map<String, dynamic>>[],
    };

void main() {
  tearDown(() {
    ApiClient.fijarInstancia(null);
    sesionActual.salir();
  });

  Future<EspiaHttp> montar(
    WidgetTester tester, {
    required Future<http.Response> Function(http.Request) responder,
    required Usuario usuario,
  }) async {
    final espia = EspiaHttp();
    final (cliente, _) = await clienteConSesion(
      clienteFalso(espia, responder),
      sesion: sesionDePrueba(),
    );
    ApiClient.fijarInstancia(cliente);
    sesionActual.entrar(usuario);
    await tester.pumpWidget(
        MaterialApp(home: EditarPerfilScreen(usuario: usuario)));
    return espia;
  }

  testWidgets(
      'un perfil sin CV se completa contra el servidor antes de poder editarlo',
      (tester) async {
    final espia = await montar(
      tester,
      usuario: Usuario.desdeJson(perfilDeLogin()),
      responder: (peticion) async => peticion.url.path == RutasApi.yo
          ? respuestaJson(perfilCompleto(), 200)
          : respuestaError(404, 'ruta inesperada: ${peticion.url.path}'),
    );

    await tester.pumpAndSettle();

    expect(espia.llamadasA(RutasApi.yo), 1,
        reason: 'sin esta lectura el formulario trabaja con datos viejos');
    // La presentación real aparece en el campo: antes salía vacío y se
    // guardaba vacío encima de la buena.
    expect(find.text('Plomera con 6 años de experiencia'), findsOneWidget);
    // Y las habilidades reales están cargadas, así que guardarlas no las borra.
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Electricidad'), findsOneWidget);
  });

  testWidgets(
      'guardar con el perfil ya completo manda la presentación y las '
      'habilidades de verdad', (tester) async {
    final espia = await montar(
      tester,
      usuario: Usuario.desdeJson(perfilDeLogin()),
      responder: (peticion) async {
        if (peticion.url.path == RutasApi.yo) {
          return respuestaJson(perfilCompleto(), 200);
        }
        if (peticion.url.path == RutasApi.miPerfil) {
          return respuestaJson(perfilCompleto(), 200);
        }
        if (peticion.url.path == RutasApi.misHabilidades) {
          return respuestaJson({'habilidades': const <String>[]}, 200);
        }
        return respuestaError(404, 'ruta inesperada: ${peticion.url.path}');
      },
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    final put = espia.ultimaA(RutasApi.miPerfil);
    final cuerpo =
        jsonDecode(utf8.decode(put.bodyBytes)) as Map<String, dynamic>;
    expect(cuerpo['presentacion'], 'Plomera con 6 años de experiencia',
        reason: 'antes viajaba "" y borraba la presentación del servidor');

    final habilidades = jsonDecode(
        utf8.decode(espia.ultimaA(RutasApi.misHabilidades).bodyBytes)) as Map;
    expect(habilidades['habilidades'], ['Plomería', 'Electricidad']);
  });

  testWidgets(
      'si no se puede completar el perfil, no se enseña el formulario ni se '
      'guarda nada', (tester) async {
    final espia = await montar(
      tester,
      usuario: Usuario.desdeJson(perfilDeLogin()),
      responder: (_) async => throw http.ClientException('sin conexión'),
    );

    await tester.pumpAndSettle();

    expect(find.text('Guardar cambios'), findsNothing,
        reason: 'guardar aquí borraría datos buenos con campos vacíos');
    expect(find.textContaining('No pudimos cargar tu perfil completo'),
        findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(espia.llamadasA(RutasApi.miPerfil), 0);
    expect(espia.llamadasA(RutasApi.misHabilidades), 0);
  });

  testWidgets('un perfil que ya viene completo no gasta una lectura de más',
      (tester) async {
    final espia = await montar(
      tester,
      usuario: Usuario.desdeJson(perfilCompleto()),
      responder: (peticion) async =>
          respuestaError(404, 'no debería llamar a ${peticion.url.path}'),
    );

    await tester.pumpAndSettle();

    expect(espia.llamadasA(RutasApi.yo), 0);
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(find.text('Plomera con 6 años de experiencia'), findsOneWidget);
  });
}
