// Lo que la tarea 019 añadió al contrato del perfil y la 020 tuvo que
// aprender a leer: el CV del trabajador, la fecha de nacimiento en ISO y la
// diferencia entre "no viene en esta respuesta" y "el usuario no tiene".
//
// El JSON está copiado del servidor real (2026-08-27). Estos tests existen
// porque el fallo que evitan no da error: guardar tratando un `null` como
// lista vacía funciona perfectamente... y deja al usuario sin CV.
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/models/json_utiles.dart';
import 'package:trabajito/models/usuario.dart';

void main() {
  group('Usuario.cvCargado — la diferencia que borra currículums', () {
    test('login y registro mandan las tres listas a null → cvCargado false',
        () {
      // Copiado de POST /api/auth/login: el `usuario` que viene con la sesión
      // no incluye habilidades, experiencia ni estudios.
      final usuario = Usuario.desdeJson(const {
        'id': '4325e383-6748-49e3-b18f-ba1890356e57',
        'correo': 'f020b@trabajito.test',
        'nombres': 'Ana Maria',
        'apellidos': 'Lopez Diaz',
        'rol': 'TRABAJADOR',
        'habilidades': null,
        'experiencia': null,
        'estudios': null,
      });

      expect(usuario.habilidades, isEmpty);
      expect(usuario.cvCargado, isFalse,
          reason: 'esas listas vacías no son el CV real del usuario');
    });

    test('/api/auth/yo manda listas de verdad → cvCargado true', () {
      final usuario = Usuario.desdeJson(const {
        'id': '4325e383',
        'correo': 'f020b@trabajito.test',
        'rol': 'TRABAJADOR',
        'habilidades': ['Albanileria', 'Pintura'],
        'experiencia': <Map<String, dynamic>>[],
        'estudios': <Map<String, dynamic>>[],
      });

      expect(usuario.cvCargado, isTrue);
      expect(usuario.habilidades, ['Albanileria', 'Pintura']);
    });

    test('un CV vacío de verdad (listas vacías) también es cvCargado true', () {
      // Verificado contra el servidor: un usuario recién registrado responde
      // `"habilidades":[]` en /api/auth/yo, no `null`. Esa lista vacía sí se
      // puede guardar sin miedo.
      final usuario = Usuario.desdeJson(const {
        'id': '1',
        'rol': 'EMPLEADOR',
        'habilidades': <String>[],
        'experiencia': <Map<String, dynamic>>[],
        'estudios': <Map<String, dynamic>>[],
      });

      expect(usuario.cvCargado, isTrue);
      expect(usuario.habilidades, isEmpty);
    });

    test('un Usuario construido a mano se da por completo', () {
      // Lo que se construye en el código es exactamente lo que quien lo
      // construye decidió, y lo que viene de Firestore trae las tres listas en
      // el mismo documento. En ninguno de los dos casos hay ambigüedad.
      final usuario = Usuario(
        uid: 'x',
        tipoUsuario: 'trabajador',
        correo: 'x@y.z',
        fechaRegistro: DateTime(2026),
        rol: 'trabajador',
      );

      expect(usuario.cvCargado, isTrue);
    });

    test('aJson() nunca manda el CV: se escribe por su propia ruta', () {
      final usuario = Usuario.desdeJson(const {
        'id': '1',
        'rol': 'TRABAJADOR',
        'habilidades': ['Albanileria'],
      });

      expect(usuario.aJson(), isNot(contains('habilidades')));
      expect(usuario.aJson(), isNot(contains('experiencia')));
      expect(usuario.aJson(), isNot(contains('estudios')));
    });
  });

  group('Experiencia y Estudio — sub-recursos con id propio', () {
    test('desdeJson recoge el id que pone el servidor', () {
      final exp = Experiencia.desdeJson(const {
        'id': 'd0cc258a-1df1-484d-86b3-64bf821b2883',
        'empresa': 'Constructora X',
        'puesto': 'Albanil',
        'habilidades': 'repello',
        'descripcion': 'obra gris',
        'fechaInicio': '01/2020',
        'fechaFin': '',
        'trabajaActualmente': true,
      });

      expect(exp.id, 'd0cc258a-1df1-484d-86b3-64bf821b2883');
      expect(exp.empresa, 'Constructora X');
      expect(exp.trabajaActualmente, isTrue);
    });

    test('aJson() NO manda el id: lo decide el servidor y va en la URL', () {
      const exp = Experiencia(
          id: 'ya-existe',
          empresa: 'X',
          puesto: 'Y',
          fechaInicio: '2020');

      expect(exp.aJson(), isNot(contains('id')));
    });

    test('un estudio sin id (recién escrito en el formulario) se acepta', () {
      const est = Estudio(nivel: 'Secundaria', centro: 'X', fechaInicio: '2010');

      expect(est.id, '');
      expect(est.aJson()['nivel'], 'Secundaria');
      expect(est.aJson(), isNot(contains('id')));
    });

    test('lo que viene de Firestore no tiene id y sigue leyéndose igual', () {
      final exp = Experiencia.desdeMap(const {
        'empresa': 'Antigua',
        'puesto': 'Peon',
        'fechaInicio': '2018',
      });

      expect(exp.id, '');
      expect(exp.empresa, 'Antigua');
    });
  });

  group('fechaNacimiento — el backend la devuelve en ISO, la app la enseña '
      'en dd/MM/aaaa', () {
    test('ISO del servidor → formato del formulario', () {
      expect(fechaNacimientoVisible('1995-03-15'), '15/03/1995');
    });

    test('lo que ya está en dd/MM/aaaa (Firestore) se deja igual', () {
      expect(fechaNacimientoVisible('15/03/1995'), '15/03/1995');
    });

    test('vacío sigue vacío, no "//"', () {
      expect(fechaNacimientoVisible(''), '');
      expect(fechaNacimientoVisible('   '), '');
    });

    test('el getter del modelo traduce lo que venga del backend', () {
      final usuario = Usuario.desdeJson(const {
        'id': '1',
        'rol': 'TRABAJADOR',
        'fechaNacimiento': '1995-03-15',
      });

      expect(usuario.fechaNacimiento, '1995-03-15',
          reason: 'el campo crudo conserva lo que mandó el servidor');
      expect(usuario.fechaNacimientoLegible, '15/03/1995');
    });

    test('un usuario sin fecha (o un perfil ajeno, que la oculta) da vacío',
        () {
      final ajeno = Usuario.desdeJson(const {
        'id': '1',
        'rol': 'TRABAJADOR',
        'fechaNacimiento': null,
      });

      expect(ajeno.fechaNacimientoLegible, '');
    });
  });

  group('perfil ajeno — los campos privados llegan null', () {
    test('correo, DNI, teléfonos y saldo se leen como vacío/0, sin reventar',
        () {
      // Verificado: GET /api/usuarios/{id} los oculta a propósito (ADR-0011).
      final ajeno = Usuario.desdeJson(const {
        'id': '8883f99d',
        'correo': null,
        'nombres': 'Tomas',
        'apellidos': 'QA',
        'dni': null,
        'telefono': null,
        'telefonoEmergencia': null,
        'fechaNacimiento': null,
        'saldo': null,
        'rol': 'TRABAJADOR',
        'trabajosCompletados': 4,
        'habilidades': ['Soldadura'],
        'experiencia': <Map<String, dynamic>>[],
        'estudios': <Map<String, dynamic>>[],
      });

      expect(ajeno.correo, '');
      expect(ajeno.dni, '');
      expect(ajeno.telefono, '');
      expect(ajeno.saldo, 0);
      expect(ajeno.nombreCompleto, 'Tomas QA');
      // Lo que sí se enseña de otra persona: su trabajo y su CV.
      expect(ajeno.trabajosCompletados, 4);
      expect(ajeno.habilidades, ['Soldadura']);
    });
  });

  group('registroCompleto y activo', () {
    test('el backend los manda y se respetan tal cual', () {
      final aMedias = Usuario.desdeJson(const {
        'id': '1',
        'rol': 'TRABAJADOR',
        'nombres': 'Ana',
        'apellidos': 'Lopez',
        'registroCompleto': false,
        'activo': true,
      });

      expect(aMedias.registroCompleto, isFalse,
          reason: 'tener nombre y apellidos no significa haber terminado los '
              '5 pasos del registro');
      expect(aMedias.estado, 'activo');
    });

    test('una cuenta dada de baja llega con activo false', () {
      final baja = Usuario.desdeJson(const {
        'id': '1',
        'rol': 'TRABAJADOR',
        'activo': false,
      });

      expect(baja.estado, 'suspendido');
    });
  });
}
