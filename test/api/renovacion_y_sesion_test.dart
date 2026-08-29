import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/services/api/api_excepciones.dart';
import 'package:trabajito/services/api/configuracion_api.dart';
import 'package:trabajito/services/api/sesion_api.dart';

import 'ayudas_api.dart';

/// Regresión de la tarea 022 (revisión de QA de la migración).
///
/// El candado 3 de `ApiClient`: una renovación en vuelo NO puede sobrevivir a
/// la sesión que la pidió.
///
/// **Por qué importa y no es teórico.** `POST /api/auth/logout` del backend
/// revoca **solo el refresh token que se le presenta**
/// (`RefreshTokenService.revocar`), no la familia entera. Si el cliente
/// guardaba el par que devolvía un refresco lanzado *antes* del logout, en el
/// dispositivo quedaba una sesión que el servidor seguía aceptando: el
/// usuario pulsaba "cerrar sesión", la app volvía al login, y al siguiente
/// arranque `restaurarSesion()` lo metía otra vez dentro.
///
/// Reproducido el 2026-08-29 antes del arreglo: tras `cerrarSesion()`,
/// `haySesion` seguía en `true` y el almacén guardaba `refresh-1`.
void main() {
  group('ApiClient — una renovación no revive una sesión cerrada', () {
    test('cerrar sesión mientras se renueva deja el dispositivo SIN sesión',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          // Refresco lento: da tiempo a que el usuario pulse "salir".
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return respuestaJson(
              cuerpoSesion(token: 'token-1', refreshToken: 'refresh-1'), 200);
        }
        if (peticion.url.path == RutasApi.logout) {
          return respuestaJson(null, 204);
        }
        return respuestaError(401, 'No autenticado');
      });
      final (cliente, almacen) = await clienteConSesion(mock,
          sesion: sesionDePrueba(vida: const Duration(seconds: -1)));

      // Token caducado: esta petición dispara la renovación.
      final enCurso = cliente.obtener('/api/trabajos');
      // El usuario no espera: pulsa "cerrar sesión".
      await cliente.cerrarSesion();
      await expectLater(enCurso, throwsA(isA<SesionInvalida>()));
      // Margen para que el refresco lento termine y NO resucite nada.
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(cliente.haySesion, isFalse,
          reason: 'salir tiene que significar salir');
      expect(await almacen.leerSesion(), isNull,
          reason: 'el refresh token nuevo NO lo revocó el logout: guardarlo '
              'dejaría una sesión utilizable en el dispositivo');
      // El logout viajó con el refresh token que el usuario tenía al pulsar.
      final logout = espia.ultimaA(RutasApi.logout);
      expect(jsonDecode(utf8.decode(logout.bodyBytes)),
          {'refreshToken': 'refresh-0'});
    });

    test('un refresco viejo que llega tarde no pisa la sesión nueva',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return respuestaJson(
              cuerpoSesion(
                  token: 'token-viejo-rotado',
                  refreshToken: 'refresh-viejo-rotado',
                  correo: 'anterior@trabajito.test'),
              200);
        }
        return respuestaError(401, 'No autenticado');
      });
      final (cliente, almacen) = await clienteConSesion(mock,
          sesion: sesionDePrueba(vida: const Duration(seconds: -1)));

      final enCurso = cliente.obtener('/api/trabajos');
      // Mientras tanto entra otra cuenta (login/registro guardan sesión).
      await cliente.guardarSesion(SesionApi(
        token: 'token-nuevo',
        refreshToken: 'refresh-nuevo',
        expiraEn: DateTime.now().add(const Duration(minutes: 15)),
        usuario: const {'correo': 'nueva@trabajito.test'},
      ));
      await expectLater(enCurso, throwsA(isA<SesionInvalida>()));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(cliente.sesion!.refreshToken, 'refresh-nuevo');
      expect(cliente.usuarioDeLaSesion['correo'], 'nueva@trabajito.test');
      expect((await almacen.leerSesion())!.refreshToken, 'refresh-nuevo');
    });

    test('un 401 del refresco viejo tampoco tumba la sesión nueva', () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          // El backend revocó esa familia: 401.
          return respuestaError(401, 'Sesión inválida o expirada.');
        }
        return respuestaError(401, 'No autenticado');
      });
      final (cliente, almacen) = await clienteConSesion(mock,
          sesion: sesionDePrueba(vida: const Duration(seconds: -1)));

      final enCurso = cliente.obtener('/api/trabajos');
      await cliente.guardarSesion(SesionApi(
        token: 'token-nuevo',
        refreshToken: 'refresh-nuevo',
        expiraEn: DateTime.now().add(const Duration(minutes: 15)),
        usuario: const {'correo': 'nueva@trabajito.test'},
      ));
      await expectLater(enCurso, throwsA(isA<SesionInvalida>()));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(cliente.haySesion, isTrue,
          reason: 'el 401 era del refresh token anterior, no del actual');
      expect((await almacen.leerSesion())!.refreshToken, 'refresh-nuevo');
    });

    test('sin interferencias, la renovación normal sigue guardando la sesión',
        () async {
      final espia = EspiaHttp();
      final mock = clienteFalso(espia, (peticion) async {
        if (peticion.url.path == RutasApi.refresh) {
          return respuestaJson(
              cuerpoSesion(token: 'token-1', refreshToken: 'refresh-1'), 200);
        }
        return autorizacionDe(peticion) == 'Bearer token-1'
            ? respuestaJson({'ok': true}, 200)
            : respuestaError(401, 'No autenticado');
      });
      final (cliente, almacen) = await clienteConSesion(mock,
          sesion: sesionDePrueba(vida: const Duration(seconds: -1)));

      await cliente.obtener('/api/trabajos');

      expect(cliente.sesion!.refreshToken, 'refresh-1');
      expect((await almacen.leerSesion())!.token, 'token-1');
    });
  });
}
