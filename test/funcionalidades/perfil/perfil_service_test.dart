// Tests de `PerfilService`, que salió de `AuthService` en la tarea 027 (parte
// B-2, ADR-0014): recargar/editar el perfil propio, el CV del trabajador, el
// perfil público ajeno y el listado de trabajadores.
//
// Antes vivían en `test/funcionalidades/autenticacion/auth_service_test.dart`
// (grupos "actualizarCampos", "CV del trabajador", "listarTrabajadores" y
// "obtenerUsuarioPorUid"); solo cambia el servicio que se monta, no lo que se
// comprueba. Todo el JSON está copiado de respuestas reales del servidor de
// pruebas (VM Ubuntu, 2026-08-27), no inventado.
//
// No se abre ningún socket: `MockClient` de `package:http/testing.dart` y un
// almacén de sesión en memoria.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/api/sesion_api.dart';
import 'package:trabajito/funcionalidades/perfil/datos/perfil_service.dart';
import 'package:trabajito/nucleo/sesion/sesion_usuario.dart';

import '../../api/ayudas_api.dart';

/// `GET /api/auth/yo` del servidor real, con CV. Es la ÚNICA lectura que trae
/// el perfil completo del dueño de la cuenta.
Map<String, dynamic> perfilCompleto({
  List<String> habilidades = const ['Albanileria', 'Pintura'],
  String rol = 'TRABAJADOR',
}) =>
    <String, dynamic>{
      'id': '4325e383-6748-49e3-b18f-ba1890356e57',
      'correo': 'f020b@trabajito.test',
      'nombres': 'Ana Maria',
      'apellidos': 'Lopez Diaz',
      'nombreCompleto': 'Ana Maria Lopez Diaz',
      'dni': '0801199598765',
      'telefono': '98765432',
      'telefonoEmergencia': '33334444',
      // Ojo: ISO, no dd/MM/aaaa. Es lo que devuelve el servidor.
      'fechaNacimiento': '1995-03-15',
      'genero': 'Masculino',
      'rol': rol,
      'activo': true,
      'registroCompleto': true,
      'creadoEn': '2026-08-27T23:48:34.579805Z',
      'fotoUrl': null,
      'presentacion': 'Trabajo duro',
      'urlCV': null,
      'departamento': 'Francisco Morazan',
      'ciudad': 'Tegucigalpa',
      'codigoPostal': null,
      'pais': 'Honduras',
      'viveEnHonduras': true,
      'trabajosCompletados': 0,
      'trabajosPublicados': 0,
      'pagosConfirmados': 0,
      'calificacionPromedio': 0.00,
      'totalCalificaciones': 0,
      'calificacionComoTrabajador': 0.00,
      'totalCalificacionesComoTrabajador': 0,
      'calificacionComoEmpleador': 0.00,
      'totalCalificacionesComoEmpleador': 0,
      'saldo': 0.00,
      'tipoEmpleador': null,
      'nombreEmpresa': null,
      'rtn': null,
      'cargoContacto': null,
      'sectorEmpresa': null,
      'tamanoEmpresa': null,
      'sitioWeb': null,
      'descripcionEmpresa': null,
      'habilidades': habilidades,
      'experiencia': [
        {
          'id': 'd0cc258a-1df1-484d-86b3-64bf821b2883',
          'empresa': 'Constructora X',
          'puesto': 'Albanil',
          'habilidades': 'repello',
          'descripcion': 'obra gris',
          'fechaInicio': '01/2020',
          'fechaFin': '',
          'trabajaActualmente': true,
        }
      ],
      'estudios': [
        {
          'id': 'bca05e2b-eed2-4643-880f-04bf02b87bcc',
          'nivel': 'Secundaria',
          'centro': 'Instituto Central',
          'fechaInicio': '2010',
          'fechaFin': '2013',
          'cursandoActualmente': false,
        }
      ],
    };

/// Un elemento de `GET /api/usuarios/ranking` del servidor real: vista
/// pública, **sin CV y sin datos personales**.
Map<String, dynamic> perfilPublicoDelRanking() => <String, dynamic>{
      'id': '8883f99d-2531-4c52-ab1b-a23d22002ec5',
      'correo': null,
      'nombres': 'Tomas',
      'apellidos': 'QA',
      'nombreCompleto': 'Tomas QA',
      'dni': null,
      'telefono': null,
      'telefonoEmergencia': null,
      'fechaNacimiento': null,
      'genero': null,
      'rol': 'TRABAJADOR',
      'activo': true,
      'registroCompleto': true,
      'creadoEn': '2026-08-22T00:02:21.283423Z',
      'fotoUrl': null,
      'presentacion': null,
      'urlCV': null,
      'departamento': null,
      'ciudad': null,
      'codigoPostal': null,
      'pais': 'Honduras',
      'viveEnHonduras': true,
      'trabajosCompletados': 4,
      'trabajosPublicados': 0,
      'pagosConfirmados': 0,
      'calificacionPromedio': 5.00,
      'totalCalificaciones': 1,
      'calificacionComoTrabajador': 5.00,
      'totalCalificacionesComoTrabajador': 1,
      'calificacionComoEmpleador': 0.00,
      'totalCalificacionesComoEmpleador': 0,
      'saldo': null,
      'tipoEmpleador': null,
      'nombreEmpresa': null,
      'rtn': null,
      'cargoContacto': null,
      'sectorEmpresa': null,
      'tamanoEmpresa': null,
      'sitioWeb': null,
      'descripcionEmpresa': null,
      // Los tres `null` que hay que saber distinguir de "no tiene".
      'habilidades': null,
      'experiencia': null,
      'estudios': null,
    };

Map<String, dynamic> cuerpoDe(http.Request p) =>
    jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;

/// Monta `PerfilService` + espía con el enrutado que se le pase.
Future<(PerfilService, EspiaHttp, SesionUsuario, ApiClient)> montar(
  Future<http.Response> Function(http.Request) responder, {
  SesionApi? sesionGuardada,
}) async {
  final espia = EspiaHttp();
  final (cliente, _) = await clienteConSesion(
    clienteFalso(espia, responder),
    sesion: sesionGuardada,
  );
  final sesion = SesionUsuario();
  return (
    PerfilService(cliente: cliente, sesion: sesion),
    espia,
    sesion,
    cliente
  );
}

void main() {
  group('actualizarCampos — PUT /api/usuarios/me', () {
    test('no manda habilidades aunque se las pasen: el CV va por su ruta',
        () async {
      final (perfil, espia, _, _) = await montar(
        (p) async => respuestaJson(perfilCompleto(), 200),
        sesionGuardada: sesionDePrueba(),
      );

      await perfil.actualizarCampos({
        'presentacion': 'Trabajo duro',
        'habilidades': <String>[], // el error que borraría el CV
      });

      final cuerpo = cuerpoDe(espia.ultimaA('/api/usuarios/me'));
      expect(cuerpo, isNot(contains('habilidades')));
      expect(cuerpo['presentacion'], 'Trabajo duro');
    });

    test('descarta los campos que ActualizarPerfilRequest no conoce', () async {
      final (perfil, espia, _, _) = await montar(
        (p) async => respuestaJson(perfilCompleto(), 200),
        sesionGuardada: sesionDePrueba(),
      );

      await perfil.actualizarCampos({
        'telefono': '98765432',
        // Nada de esto lo puede tocar el dueño de la cuenta: el backend los
        // ignora (ADR-0005/ADR-0008) y mandarlos solo generaría ruido.
        'saldo': 9999,
        'rol': 'admin',
        'correo': 'otro@trabajito.test',
        'trabajosCompletados': 500,
      });

      final cuerpo = cuerpoDe(espia.ultimaA('/api/usuarios/me'));
      expect(cuerpo.keys, ['telefono']);
    });

    test('traduce fotoPerfil (nombre de la app) a fotoUrl (nombre del backend)',
        () async {
      final (perfil, espia, _, _) = await montar(
        (p) async => respuestaJson(perfilCompleto(), 200),
        sesionGuardada: sesionDePrueba(),
      );

      await perfil.actualizarCampos({'fotoPerfil': 'https://x/y.png'});

      expect(cuerpoDe(espia.ultimaA('/api/usuarios/me'))['fotoUrl'],
          'https://x/y.png');
    });

    test('un campo a null no viaja: para el backend ausente = "no lo toques"',
        () async {
      final (perfil, espia, _, _) = await montar(
        (p) async => respuestaJson(perfilCompleto(), 200),
        sesionGuardada: sesionDePrueba(),
      );

      await perfil.actualizarCampos({'telefono': '9988', 'genero': null});

      expect(cuerpoDe(espia.ultimaA('/api/usuarios/me')),
          isNot(contains('genero')));
    });

    test('publica en la sesión el perfil que devuelve el PUT, ya con CV',
        () async {
      final (perfil, _, sesion, _) = await montar(
        (p) async =>
            respuestaJson(perfilCompleto(habilidades: const ['Soldadura']), 200),
        sesionGuardada: sesionDePrueba(),
      );
      sesion.entrar(Usuario.desdeJson(perfilCompleto()));

      await perfil.actualizarCampos({'presentacion': 'nueva'});

      expect(sesion.usuario!.habilidades, ['Soldadura']);
    });

    test('la edad mínima que exige el servidor llega en español al usuario',
        () async {
      final (perfil, _, _, _) = await montar(
        (p) async => respuestaError(
            400, 'Debes tener al menos 18 años para usar Trabajito'),
        sesionGuardada: sesionDePrueba(),
      );

      final error =
          await perfil.actualizarCampos({'fechaNacimiento': '01/01/2015'});

      expect(error, 'Debes tener al menos 18 años para usar Trabajito');
    });
  });

  group('CV del trabajador (sub-recursos)', () {
    test('reemplazarHabilidades manda la lista entera a su propia ruta',
        () async {
      final (perfil, espia, _, _) = await montar(
        (p) async => respuestaJson(const ['Albanileria'], 200),
        sesionGuardada: sesionDePrueba(),
      );

      final error = await perfil.reemplazarHabilidades(const ['Albanileria']);

      expect(error, isNull);
      expect(espia.rutas, ['/api/usuarios/me/habilidades']);
      expect(espia.ultimaA('/api/usuarios/me/habilidades').method, 'PUT');
      expect(cuerpoDe(espia.ultimaA('/api/usuarios/me/habilidades')), {
        'habilidades': ['Albanileria']
      });
    });

    test('agregarExperiencia hace POST y no manda el id (lo pone el servidor)',
        () async {
      final (perfil, espia, _, _) = await montar(
        (p) async => respuestaJson(const {'id': 'nuevo'}, 201),
        sesionGuardada: sesionDePrueba(),
      );

      await perfil.agregarExperiencia(const Experiencia(
        id: 'no-deberia-viajar',
        empresa: 'Constructora X',
        puesto: 'Albanil',
        fechaInicio: '01/2020',
        trabajaActualmente: true,
      ));

      final peticion = espia.ultimaA('/api/usuarios/me/experiencia');
      expect(peticion.method, 'POST');
      final cuerpo = cuerpoDe(peticion);
      expect(cuerpo, isNot(contains('id')));
      expect(cuerpo['empresa'], 'Constructora X');
      expect(cuerpo['trabajaActualmente'], isTrue);
    });

    test('agregarEstudio hace POST a su ruta', () async {
      final (perfil, espia, _, _) = await montar(
        (p) async => respuestaJson(const {'id': 'nuevo'}, 201),
        sesionGuardada: sesionDePrueba(),
      );

      await perfil.agregarEstudio(const Estudio(
          nivel: 'Secundaria',
          centro: 'Instituto Central',
          fechaInicio: '2010'));

      expect(espia.rutas, ['/api/usuarios/me/estudios']);
      expect(cuerpoDe(espia.ultimaA('/api/usuarios/me/estudios'))['nivel'],
          'Secundaria');
    });
  });

  group('listarTrabajadores — lo que antes era streamTrabajadores()', () {
    test('lee el array del ranking (no es una página de Spring)', () async {
      final (perfil, espia, _, _) = await montar(
        (p) async => respuestaJson([perfilPublicoDelRanking()], 200),
        sesionGuardada: sesionDePrueba(),
      );

      final lista = await perfil.listarTrabajadores();

      expect(espia.rutas, ['/api/usuarios/ranking']);
      expect(lista, hasLength(1));
      expect(lista.first.nombreCompleto, 'Tomas QA');
      expect(lista.first.trabajosCompletados, 4);
    });

    test('los elementos del ranking NO traen CV, y el modelo lo sabe', () async {
      final (perfil, _, _, _) = await montar(
        (p) async => respuestaJson([perfilPublicoDelRanking()], 200),
        sesionGuardada: sesionDePrueba(),
      );

      final trabajador = (await perfil.listarTrabajadores()).first;

      expect(trabajador.habilidades, isEmpty);
      expect(trabajador.cvCargado, isFalse,
          reason: 'llegó null: significa "no viene", no "no tiene"');
    });
  });

  group('obtenerUsuarioPorUid — perfil ajeno', () {
    test('pide /api/usuarios/{id} y acepta que falten los datos privados',
        () async {
      final publico = perfilCompleto()
        ..['correo'] = null
        ..['dni'] = null
        ..['telefono'] = null
        ..['fechaNacimiento'] = null
        ..['saldo'] = null;
      final (perfil, espia, _, _) = await montar(
        (p) async => respuestaJson(publico, 200),
        sesionGuardada: sesionDePrueba(),
      );

      final otro = await perfil.obtenerUsuarioPorUid('otro-uuid');

      expect(espia.rutas, ['/api/usuarios/otro-uuid']);
      expect(otro, isNotNull);
      // La UI ya sabe pintar cadena vacía y 0; lo que no debe es reventar.
      expect(otro!.correo, '');
      expect(otro.dni, '');
      expect(otro.saldo, 0);
      // El CV sí viene en el perfil ajeno: es lo que hay que enseñar.
      expect(otro.habilidades, isNotEmpty);
      expect(otro.cvCargado, isTrue);
    });

    test('un 404 devuelve null en vez de tumbar la pantalla', () async {
      final (perfil, _, _, _) = await montar(
        (p) async => respuestaError(404, 'Usuario no encontrado'),
        sesionGuardada: sesionDePrueba(),
      );

      expect(await perfil.obtenerUsuarioPorUid('no-existe'), isNull);
    });
  });
}
