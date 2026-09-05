// Tests del primer servicio migrado al backend propio (tarea 020, fase 2a de
// ADR-0009): `AuthService` ya no habla con Firebase Auth ni con Firestore.
//
// Todo el JSON de aquí está **copiado de respuestas reales** del servidor de
// pruebas (VM Ubuntu, 2026-08-27), no inventado a partir de `docs/api.md`.
// Eso importa sobre todo en un punto: el backend manda `habilidades`,
// `experiencia` y `estudios` como `null` en el login, el registro y el
// ranking, y como lista en `GET /api/auth/yo`. Confundir ese `null` con una
// lista vacía y guardarla borraría el CV del usuario, así que hay varios tests
// dedicados solo a eso.
//
// No se abre ningún socket: se usa `MockClient` de `package:http/testing.dart`
// y un almacén de sesión en memoria, igual que los tests de la tarea 018.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trabajito/models/usuario.dart';
import 'package:trabajito/services/api/api_client.dart';
import 'package:trabajito/services/api/sesion_api.dart';
import 'package:trabajito/services/auth_service.dart';
import 'package:trabajito/services/sesion_usuario.dart';
import 'package:trabajito/utils/constantes.dart';

import '../api/ayudas_api.dart';

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

/// Monta servicio + espía con el enrutado que se le pase.
///
/// Devuelve los cuatro en el mismo orden siempre; cada test desestructura con
/// `_` los que no usa (en Dart 3 el guion bajo es un comodin de patron y se
/// puede repetir, asi que no hacen falta nombres inventados).
Future<(AuthService, EspiaHttp, SesionUsuario, ApiClient)> montar(
  Future<http.Response> Function(http.Request) responder, {
  SesionApi? sesionGuardada,
}) async {
  final espia = EspiaHttp();
  final (cliente, _) = await clienteConSesion(
    clienteFalso(espia, responder),
    sesion: sesionGuardada,
  );
  final sesion = SesionUsuario();
  return (AuthService(cliente: cliente, sesion: sesion), espia, sesion, cliente);
}

void main() {
  group('iniciarSesion', () {
    test('guarda la sesión y publica el perfil COMPLETO, no el del login',
        () async {
      final (auth, espia, sesion, _) = await montar((p) async {
        if (p.url.path == '/api/auth/login') {
          return respuestaJson(
              cuerpoSesion(token: 'tok', refreshToken: 'ref'), 200);
        }
        if (p.url.path == '/api/auth/yo') {
          return respuestaJson(perfilCompleto(), 200);
        }
        return respuestaError(404, 'ruta inesperada: ${p.url.path}');
      });

      final error = await auth.iniciarSesion(
          correo: ' f020b@trabajito.test ', contrasena: 'Trabajito2026x');

      expect(error, isNull);
      expect(sesion.hay, isTrue);
      // El cuerpo del login NO trae el CV; por eso se pide `/api/auth/yo`
      // detrás. Sin esa segunda llamada, editar el perfil borraría el CV.
      expect(espia.rutas, ['/api/auth/login', '/api/auth/yo']);
      expect(sesion.usuario!.habilidades, ['Albanileria', 'Pintura']);
      expect(sesion.usuario!.cvCargado, isTrue);
    });

    test('manda el correo recortado y la contraseña como "password"', () async {
      final (auth, espia, _, _) = await montar((p) async {
        if (p.url.path == '/api/auth/login') {
          return respuestaJson(
              cuerpoSesion(token: 'tok', refreshToken: 'ref'), 200);
        }
        return respuestaJson(perfilCompleto(), 200);
      });

      await auth.iniciarSesion(
          correo: '  f020b@trabajito.test  ', contrasena: 'Trabajito2026x');

      final cuerpo = cuerpoDe(espia.ultimaA('/api/auth/login'));
      expect(cuerpo['correo'], 'f020b@trabajito.test');
      expect(cuerpo['password'], 'Trabajito2026x');
    });

    test('un 401 se lee como credenciales incorrectas, no como sesión expirada',
        () async {
      final (auth, _, sesion, _) = await montar(
        (p) async => respuestaError(401, 'Correo o contraseña incorrectos'),
      );

      final error = await auth.iniciarSesion(
          correo: 'quien@sea.test', contrasena: 'ClaveEquivocada1');

      expect(error, 'Correo o contraseña incorrectos');
      expect(sesion.hay, isFalse);
    });

    test('un 429 dice cuánto hay que esperar (Retry-After), no un error seco',
        () async {
      final (auth, _, _, _) = await montar(
        (p) async => respuestaError(
          429,
          'Demasiados intentos fallidos.',
          cabeceras: const {'retry-after': '900'},
        ),
      );

      final error = await auth.iniciarSesion(
          correo: 'quien@sea.test', contrasena: 'ClaveEquivocada1');

      expect(error, contains('15 minutos'));
    });

    test(
        'un 400 de validación enseña el detalle del campo, no "Datos inválidos"',
        () async {
      final (auth, _, _, _) = await montar(
        (p) async => respuestaError(400, 'Datos inválidos', campos: const {
          'password': 'La contraseña debe tener al menos 10 caracteres',
        }),
      );

      final error =
          await auth.iniciarSesion(correo: 'quien@sea.test', contrasena: 'corta1');

      expect(error, 'La contraseña debe tener al menos 10 caracteres');
      expect(auth.ultimoErrorPorCampo['password'], isNotNull,
          reason: 'el formulario debe poder marcar el campo que falló');
    });
  });

  group('registrar', () {
    test('un solo POST crea la cuenta y deja sesión iniciada con CV completo',
        () async {
      final (auth, espia, sesion, _) = await montar((p) async {
        if (p.url.path == '/api/auth/registro') {
          return respuestaJson(
              cuerpoSesion(token: 'tok', refreshToken: 'ref'), 200);
        }
        return respuestaJson(perfilCompleto(habilidades: const []), 200);
      });

      final error = await auth.registrar(
        datos: Usuario(
          uid: '',
          tipoUsuario: ValoresDefecto.rolEmpleador,
          nombres: 'Ana Maria',
          apellidos: 'Lopez Diaz',
          dni: '0801199598765',
          correo: 'f020b@trabajito.test',
          fechaRegistro: DateTime(2026, 8, 27),
          rol: ValoresDefecto.rolEmpleador,
        ),
        contrasena: 'Trabajito2026x',
      );

      expect(error, isNull);
      expect(sesion.hay, isTrue);
      final cuerpo = cuerpoDe(espia.ultimaA('/api/auth/registro'));
      // `RolPublico` en mayúsculas: el backend responde 400 a cualquier otra
      // cosa, incluido ADMIN (ADR-0005).
      expect(cuerpo['rol'], 'EMPLEADOR');
      expect(cuerpo['password'], 'Trabajito2026x');
      // Una lista vacía que SÍ vino en la respuesta es un CV vacío de verdad.
      expect(sesion.usuario!.cvCargado, isTrue);
      expect(sesion.usuario!.habilidades, isEmpty);
    });

    test('un correo repetido (409) no deja sesión a medias', () async {
      final (auth, _, sesion, _) = await montar(
        (p) async => respuestaError(409, 'Ya existe una cuenta con ese correo'),
      );

      final error = await auth.registrar(
        datos: Usuario(
          uid: '',
          tipoUsuario: ValoresDefecto.rolTrabajador,
          correo: 'repetido@trabajito.test',
          fechaRegistro: DateTime(2026, 8, 27),
          rol: ValoresDefecto.rolTrabajador,
        ),
        contrasena: 'Trabajito2026x',
      );

      expect(error, 'Ya existe una cuenta con ese correo');
      expect(sesion.hay, isFalse);
    });
  });

  group('restaurarSesion — lo que antes hacía authStateChanges()', () {
    test('sin sesión guardada en el dispositivo → sinSesion', () async {
      final (auth, espia, sesion, _) =
          await montar((p) async => respuestaJson(perfilCompleto(), 200));

      await auth.restaurarSesion();

      expect(sesion.value.fase, FaseSesion.sinSesion);
      expect(espia.peticiones, isEmpty,
          reason: 'sin sesión guardada no hay a quién preguntarle nada');
    });

    test('con sesión guardada la confirma contra /api/auth/yo', () async {
      final (auth, espia, sesion, _) = await montar(
        (p) async => respuestaJson(perfilCompleto(), 200),
        sesionGuardada: sesionDePrueba(),
      );

      await auth.restaurarSesion();

      expect(sesion.value.fase, FaseSesion.conSesion);
      expect(espia.rutas, ['/api/auth/yo']);
      expect(sesion.usuario!.correo, 'f020b@trabajito.test');
      expect(sesion.value.avisoSinConexion, isFalse);
    });

    test('si el refresh token ya no vale (401) se cierra la sesión', () async {
      final (auth, _, sesion, cliente) = await montar(
        (p) async => respuestaError(401, 'Sesión inválida o expirada.'),
        sesionGuardada: sesionDePrueba(),
      );

      await auth.restaurarSesion();

      expect(sesion.value.fase, FaseSesion.sinSesion);
      expect(cliente.haySesion, isFalse,
          reason:
              'no tiene sentido conservar una sesión que el servidor rechazó');
    });

    test('sin conexión NO expulsa: entra con el perfil guardado y avisa',
        () async {
      // Es el caso de uso real de esta app: gente trabajando en la calle con
      // cobertura intermitente. Echarles al login por un corte de red sería
      // peor que enseñarles datos de hace un rato.
      final (auth, _, sesion, cliente) = await montar(
        (p) async => throw const SocketException('sin ruta al host'),
        sesionGuardada: sesionDePrueba(),
      );

      await auth.restaurarSesion();

      expect(sesion.value.fase, FaseSesion.conSesion);
      expect(sesion.value.avisoSinConexion, isTrue);
      expect(cliente.haySesion, isTrue);
      // El perfil rescatado viene del login guardado, que no traía el CV.
      expect(sesion.usuario!.cvCargado, isFalse,
          reason: 'ese perfil no puede usarse para reescribir el CV');
    });
  });

  group('cerrarSesion', () {
    test('revoca el refresh token en el servidor y vacía la sesión', () async {
      final (auth, espia, sesion, cliente) = await montar(
        (p) async => respuestaJson(null, 204),
        sesionGuardada: sesionDePrueba(refreshToken: 'refresh-vivo'),
      );
      sesion.entrar(Usuario.desdeJson(perfilCompleto()));

      await auth.cerrarSesion();

      expect(espia.rutas, ['/api/auth/logout']);
      expect(cuerpoDe(espia.ultimaA('/api/auth/logout'))['refreshToken'],
          'refresh-vivo');
      expect(sesion.value.fase, FaseSesion.sinSesion);
      expect(cliente.haySesion, isFalse);
    });

    test('si el servidor no responde, la sesión local se va igual', () async {
      final (auth, _, sesion, cliente) = await montar(
        (p) async => throw const SocketException('servidor caído'),
        sesionGuardada: sesionDePrueba(),
      );
      sesion.entrar(Usuario.desdeJson(perfilCompleto()));

      await auth.cerrarSesion();

      expect(sesion.value.fase, FaseSesion.sinSesion);
      expect(cliente.haySesion, isFalse,
          reason: 'el usuario pidió salir; debe salir');
    });
  });

  group('actualizarCampos — PUT /api/usuarios/me', () {
    test('no manda habilidades aunque se las pasen: el CV va por su ruta',
        () async {
      final (auth, espia, _, _) = await montar(
        (p) async => respuestaJson(perfilCompleto(), 200),
        sesionGuardada: sesionDePrueba(),
      );

      await auth.actualizarCampos({
        'presentacion': 'Trabajo duro',
        'habilidades': <String>[], // el error que borraría el CV
      });

      final cuerpo = cuerpoDe(espia.ultimaA('/api/usuarios/me'));
      expect(cuerpo, isNot(contains('habilidades')));
      expect(cuerpo['presentacion'], 'Trabajo duro');
    });

    test('descarta los campos que ActualizarPerfilRequest no conoce', () async {
      final (auth, espia, _, _) = await montar(
        (p) async => respuestaJson(perfilCompleto(), 200),
        sesionGuardada: sesionDePrueba(),
      );

      await auth.actualizarCampos({
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
      final (auth, espia, _, _) = await montar(
        (p) async => respuestaJson(perfilCompleto(), 200),
        sesionGuardada: sesionDePrueba(),
      );

      await auth.actualizarCampos({'fotoPerfil': 'https://x/y.png'});

      expect(cuerpoDe(espia.ultimaA('/api/usuarios/me'))['fotoUrl'],
          'https://x/y.png');
    });

    test('un campo a null no viaja: para el backend ausente = "no lo toques"',
        () async {
      final (auth, espia, _, _) = await montar(
        (p) async => respuestaJson(perfilCompleto(), 200),
        sesionGuardada: sesionDePrueba(),
      );

      await auth.actualizarCampos({'telefono': '9988', 'genero': null});

      expect(cuerpoDe(espia.ultimaA('/api/usuarios/me')),
          isNot(contains('genero')));
    });

    test('publica en la sesión el perfil que devuelve el PUT, ya con CV',
        () async {
      final (auth, _, sesion, _) = await montar(
        (p) async =>
            respuestaJson(perfilCompleto(habilidades: const ['Soldadura']), 200),
        sesionGuardada: sesionDePrueba(),
      );
      sesion.entrar(Usuario.desdeJson(perfilCompleto()));

      await auth.actualizarCampos({'presentacion': 'nueva'});

      expect(sesion.usuario!.habilidades, ['Soldadura']);
    });

    test('la edad mínima que exige el servidor llega en español al usuario',
        () async {
      final (auth, _, _, _) = await montar(
        (p) async => respuestaError(
            400, 'Debes tener al menos 18 años para usar Trabajito'),
        sesionGuardada: sesionDePrueba(),
      );

      final error =
          await auth.actualizarCampos({'fechaNacimiento': '01/01/2015'});

      expect(error, 'Debes tener al menos 18 años para usar Trabajito');
    });
  });

  group('CV del trabajador (sub-recursos)', () {
    test('reemplazarHabilidades manda la lista entera a su propia ruta',
        () async {
      final (auth, espia, _, _) = await montar(
        (p) async => respuestaJson(const ['Albanileria'], 200),
        sesionGuardada: sesionDePrueba(),
      );

      final error = await auth.reemplazarHabilidades(const ['Albanileria']);

      expect(error, isNull);
      expect(espia.rutas, ['/api/usuarios/me/habilidades']);
      expect(espia.ultimaA('/api/usuarios/me/habilidades').method, 'PUT');
      expect(cuerpoDe(espia.ultimaA('/api/usuarios/me/habilidades')), {
        'habilidades': ['Albanileria']
      });
    });

    test('agregarExperiencia hace POST y no manda el id (lo pone el servidor)',
        () async {
      final (auth, espia, _, _) = await montar(
        (p) async => respuestaJson(const {'id': 'nuevo'}, 201),
        sesionGuardada: sesionDePrueba(),
      );

      await auth.agregarExperiencia(const Experiencia(
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
      final (auth, espia, _, _) = await montar(
        (p) async => respuestaJson(const {'id': 'nuevo'}, 201),
        sesionGuardada: sesionDePrueba(),
      );

      await auth.agregarEstudio(const Estudio(
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
      final (auth, espia, _, _) = await montar(
        (p) async => respuestaJson([perfilPublicoDelRanking()], 200),
        sesionGuardada: sesionDePrueba(),
      );

      final lista = await auth.listarTrabajadores();

      expect(espia.rutas, ['/api/usuarios/ranking']);
      expect(lista, hasLength(1));
      expect(lista.first.nombreCompleto, 'Tomas QA');
      expect(lista.first.trabajosCompletados, 4);
    });

    test('los elementos del ranking NO traen CV, y el modelo lo sabe', () async {
      final (auth, _, _, _) = await montar(
        (p) async => respuestaJson([perfilPublicoDelRanking()], 200),
        sesionGuardada: sesionDePrueba(),
      );

      final trabajador = (await auth.listarTrabajadores()).first;

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
      final (auth, espia, _, _) = await montar(
        (p) async => respuestaJson(publico, 200),
        sesionGuardada: sesionDePrueba(),
      );

      final otro = await auth.obtenerUsuarioPorUid('otro-uuid');

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
      final (auth, _, _, _) = await montar(
        (p) async => respuestaError(404, 'Usuario no encontrado'),
        sesionGuardada: sesionDePrueba(),
      );

      expect(await auth.obtenerUsuarioPorUid('no-existe'), isNull);
    });
  });

  group('darDeBajaCuenta', () {
    test('hace DELETE y cierra la sesión', () async {
      final (auth, espia, sesion, cliente) = await montar(
        (p) async => respuestaJson(null, p.method == 'DELETE' ? 200 : 204),
        sesionGuardada: sesionDePrueba(),
      );
      sesion.entrar(Usuario.desdeJson(perfilCompleto()));

      final error = await auth.darDeBajaCuenta();

      expect(error, isNull);
      expect(espia.rutas, ['/api/usuarios/me', '/api/auth/logout']);
      expect(sesion.value.fase, FaseSesion.sinSesion);
      expect(cliente.haySesion, isFalse);
    });
  });

  group('lo que el backend todavía no sabe hacer', () {
    test('restablecer contraseña avisa en vez de fingir que envió un correo',
        () async {
      final (auth, espia, _, _) =
          await montar((p) async => respuestaJson(null, 200));

      final aviso = await auth.enviarResetPassword('quien@sea.test');

      expect(aviso, MensajesError.sinRecuperacionContrasena);
      expect(espia.peticiones, isEmpty,
          reason: 'no existe endpoint: no hay que llamar a nada');
    });

    test('cambiar contraseña avisa igual (tarea 017 abierta)', () async {
      final (auth, espia, _, _) =
          await montar((p) async => respuestaJson(null, 200));

      expect(await auth.cambiarContrasena('OtraClaveLarga1'),
          MensajesError.sinCambioContrasena);
      expect(espia.peticiones, isEmpty);
    });
  });

  group('la sesión que muere sola', () {
    test('un EventoSesion.terminada devuelve la app al login', () async {
      // Sin esto, un refresh token revocado dejaría al usuario dentro de una
      // pantalla donde ya no carga nada: el cliente HTTP se entera, la
      // interfaz no. Es lo que `authStateChanges()` daba de serie.
      final (auth, _, sesion, cliente) = await montar(
        (p) async => respuestaJson(null, 204),
        sesionGuardada: sesionDePrueba(),
      );
      sesion.entrar(Usuario.desdeJson(perfilCompleto()));
      auth.escucharFinDeSesion();

      await cliente.cerrarSesion();
      await Future<void>.delayed(Duration.zero); // deja correr el stream

      expect(sesion.value.fase, FaseSesion.sinSesion);
    });
  });
}
