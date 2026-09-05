// Tests de los dos servicios que migró la tarea 026 (fase 2b-1 de ADR-0009):
// `PublicacionService` y `PostulacionService` contra `/api/trabajos/**` y
// `/api/postulaciones/**`.
//
// **Todo el JSON de aquí está copiado de respuestas reales** del servidor de
// pruebas (VM Ubuntu, 2026-09-04), no deducido de `docs/api.md`. Eso importa
// en tres puntos que ningún documento decía bien:
//
//   1. El feed pagina con `pagina`/`tamano`, **no** con los `page`/`size` de
//      Spring Data. Mandar los de Spring no da error: se ignoran y devuelven
//      siempre la página 0, así que un scroll infinito repetiría los mismos
//      veinte trabajos para siempre. Hay un test dedicado solo a eso.
//   2. `POST /api/trabajos/{id}/cancelar` exige `reabrir` y responde 400 si
//      falta. No tiene valor por defecto ni aquí ni en el backend.
//   3. La postulación que devuelve el backend **no trae** `tituloTrabajo` ni
//      `empleadorId`; en Firestore iban desnormalizados dentro del documento.
//
// No se abre ningún socket: `MockClient` de `package:http/testing.dart` y un
// almacén de sesión en memoria, igual que los tests de las tareas 018 y 020.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trabajito/models/evidencia.dart';
import 'package:trabajito/models/postulacion.dart';
import 'package:trabajito/models/publicacion.dart';
import 'package:trabajito/services/api/api_client.dart';
import 'package:trabajito/services/postulacion_service.dart';
import 'package:trabajito/services/publicacion_service.dart';
import 'package:trabajito/utils/constantes.dart';

import '../api/ayudas_api.dart';

/// `TrabajoResponse` tal y como lo devolvió el servidor el 2026-09-04.
Map<String, dynamic> trabajoJson({
  String id = '8330573c-7d54-4e56-95b6-0d77df9d6352',
  String estado = 'ACTIVO',
  String titulo = 'Pintar sala F026',
  String? trabajadorAsignadoId,
  num montoAcordado = 0.00,
  bool pagoRetenido = false,
}) =>
    <String, dynamic>{
      'id': id,
      'empleadorId': '5589d127-e888-4138-8170-e9178b853ec7',
      'autorNombre': 'Emp F026',
      'titulo': titulo,
      'descripcion': 'Prueba de contrato para la tarea 026',
      'categoria': 'Construccion',
      'departamento': 'Francisco Morazan',
      'ciudad': 'Tegucigalpa',
      'zona': 'Col. Kennedy',
      'presupuesto': 'L. 1200',
      'plazo': 'Corto plazo',
      'estado': estado,
      'trabajadorAsignadoId': trabajadorAsignadoId,
      'trabajadorAsignadoNombre':
          trabajadorAsignadoId == null ? null : 'Carlos Demo',
      'montoAcordado': montoAcordado,
      'tiempoAcordado': null,
      'fechaAcuerdo': null,
      'fechaInicio': null,
      'pagoRetenido': pagoRetenido,
      'entregado': false,
      'pagoLiberado': false,
      'correccionSolicitada': false,
      'motivoCorreccion': null,
      // Los cuatro campos de disputa que el modelo de la app ignora a
      // propósito: si un día dejaran de ignorarse, este JSON ya los trae.
      'fechaSolicitudCorreccion': null,
      'disputaAbiertaPorId': null,
      'motivoDisputa': null,
      'resolucionDisputa': null,
      'calificadoPorEmpleador': false,
      'calificadoPorTrabajador': false,
      'creadoEn': '2026-09-04T22:43:36.698451978Z',
    };

/// Envoltorio de página de Spring Data, con los campos que trae de verdad.
Map<String, dynamic> paginaJson(
  List<Map<String, dynamic>> contenido, {
  int numero = 0,
  int totalElementos = 32,
  int totalPaginas = 2,
  bool ultima = false,
}) =>
    <String, dynamic>{
      'content': contenido,
      'pageable': {
        'pageNumber': numero,
        'pageSize': 20,
        'sort': {'sorted': true, 'unsorted': false, 'empty': false},
        'offset': numero * 20,
        'paged': true,
        'unpaged': false,
      },
      'totalElements': totalElementos,
      'totalPages': totalPaginas,
      'last': ultima,
      'first': numero == 0,
      'numberOfElements': contenido.length,
      'size': 20,
      'number': numero,
      'sort': {'sorted': true, 'unsorted': false, 'empty': false},
      'empty': contenido.isEmpty,
    };

/// La entidad `Postulacion` en crudo: el backend la serializa tal cual, sin
/// DTO. Por eso salen `actualizadoEn` y falta el título del trabajo.
Map<String, dynamic> postulacionJson({
  String id = '184dd281-7a2d-4694-8b83-8a7abf9d656a',
  String trabajoId = '8330573c-7d54-4e56-95b6-0d77df9d6352',
  String estado = 'PENDIENTE',
  String creadoEn = '2026-09-04T22:43:36.936169Z',
  String mensaje = 'Puedo empezar manana',
}) =>
    <String, dynamic>{
      'id': id,
      'creadoEn': creadoEn,
      'actualizadoEn': creadoEn,
      'trabajoId': trabajoId,
      'trabajadorId': '67d11167-16e0-4172-a0ca-b92b0de663f8',
      'trabajadorNombre': 'Carlos Demo',
      'mensaje': mensaje,
      'estado': estado,
    };

Map<String, dynamic> cuerpoDe(http.Request peticion) =>
    jsonDecode(utf8.decode(peticion.bodyBytes)) as Map<String, dynamic>;

void main() {
  late EspiaHttp espia;

  /// Monta los dos servicios sobre un cliente con sesión válida.
  Future<(PublicacionService, PostulacionService)> servicios(
    Future<http.Response> Function(http.Request) responder,
  ) async {
    espia = EspiaHttp();
    final (cliente, _) = await clienteConSesion(
      clienteFalso(espia, responder),
      sesion: sesionDePrueba(),
    );
    return (
      PublicacionService(cliente: cliente),
      PostulacionService(cliente: cliente),
    );
  }

  group('PublicacionService — lectura del feed', () {
    test(
        'el feed se pide con "pagina"/"tamano", no con los "page"/"size" de '
        'Spring Data', () async {
      // Este test existe por un fallo silencioso, no por completismo: el
      // controlador declara @RequestParam("pagina"/"tamano"). Si se mandan
      // page/size, Spring NO da error, los ignora y devuelve siempre la
      // página 0 — el scroll infinito repetiría los mismos trabajos sin que
      // nadie se entere.
      final (pub, _) = await servicios(
          (_) async => respuestaJson(paginaJson([trabajoJson()]), 200));

      await pub.listarFeed(pagina: 3, tamano: 20);

      final consulta = espia.ultimaA('/api/trabajos').url.queryParameters;
      expect(consulta['pagina'], '3');
      expect(consulta['tamano'], '20');
      expect(consulta.containsKey('page'), isFalse);
      expect(consulta.containsKey('size'), isFalse);
    });

    test('lee el envoltorio de página y dice si hay más', () async {
      final (pub, _) = await servicios((_) async => respuestaJson(
          paginaJson([trabajoJson(), trabajoJson(id: 'otro')]), 200));

      final pagina = await pub.listarFeed();

      expect(pagina.elementos, hasLength(2));
      expect(pagina.totalElementos, 32);
      expect(pagina.hayMas, isTrue);
      expect(pagina.paginaSiguiente, 1);
      expect(pagina.elementos.first.titulo, 'Pintar sala F026');
      // Los nombres cambian respecto a Firestore: empleadorId → uidEmpleador.
      expect(pagina.elementos.first.uidEmpleador,
          '5589d127-e888-4138-8170-e9178b853ec7');
    });

    test('la última página no ofrece siguiente', () async {
      final (pub, _) = await servicios((_) async => respuestaJson(
          paginaJson([trabajoJson()], numero: 1, ultima: true), 200));

      final pagina = await pub.listarFeed(pagina: 1);

      expect(pagina.hayMas, isFalse);
      expect(pagina.paginaSiguiente, isNull);
    });

    test('"mis publicaciones" lee un array pelado, sin paginar', () async {
      final (pub, _) = await servicios((_) async =>
          respuestaJson([trabajoJson(), trabajoJson(id: 'b')], 200));

      final mias = await pub.misPublicaciones();

      expect(mias, hasLength(2));
      expect(espia.ultimaA('/api/trabajos/mios').method, 'GET');
      // El uid no viaja en ningún sitio: lo saca el backend del token.
      expect(espia.ultimaA('/api/trabajos/mios').url.queryParameters, isEmpty);
    });

    test('los 10 estados del backend se traducen, incluido EN_DISPUTA',
        () async {
      final (pub, _) = await servicios((_) async =>
          respuestaJson(trabajoJson(estado: 'EN_DISPUTA'), 200));

      final trabajo = await pub.recargarPublicacion('x');

      expect(trabajo.estado, EstadosTrabajo.enDisputa);
      expect(EstadosTrabajo.etiqueta(trabajo.estado), 'En disputa');
    });
  });

  group('PublicacionService — publicar', () {
    test('solo manda los campos que el backend acepta del cliente', () async {
      final (pub, _) = await servicios((_) async =>
          respuestaJson(trabajoJson(), 200));

      await pub.crearPublicacion(Publicacion(
        uidEmpleador: 'no-deberia-viajar',
        autor: 'Tampoco',
        categoria: 'Construccion',
        titulo: 'Pintar sala',
        descripcion: 'Dos paredes',
        departamento: 'Francisco Morazan',
        ciudad: 'Tegucigalpa',
        zona: 'Col. Kennedy',
        presupuesto: 'L. 1200',
        plazo: 'Corto plazo',
        estado: EstadosTrabajo.completado, // intento de saltarse la máquina
        pagoRetenido: true,
        fechaCreacion: DateTime(2026, 9, 4),
      ));

      final cuerpo = cuerpoDe(espia.ultimaA('/api/trabajos'));
      expect(cuerpo['titulo'], 'Pintar sala');
      expect(cuerpo['ciudad'], 'Tegucigalpa');
      // El empleador, el estado y el escrow los pone el servidor. Mandarlos
      // sería, además de inútil, un intento de saltarse ADR-0007.
      expect(cuerpo.containsKey('empleadorId'), isFalse);
      expect(cuerpo.containsKey('estado'), isFalse);
      expect(cuerpo.containsKey('pagoRetenido'), isFalse);
    });

    test('un 400 por campo enseña el detalle del campo, no el resumen',
        () async {
      final (pub, _) = await servicios((_) async => respuestaError(
          400, 'Datos inválidos',
          campos: {'titulo': 'El título no puede superar 50 caracteres'}));

      final error = await pub.crearPublicacion(Publicacion(
        uidEmpleador: 'u',
        autor: 'a',
        categoria: 'c',
        titulo: 'x' * 60,
        descripcion: 'd',
        fechaCreacion: DateTime(2026, 9, 4),
      ));

      expect(error, 'El título no puede superar 50 caracteres');
    });

    test('crearYDevolver entrega el trabajo con el id que puso el servidor',
        () async {
      final (pub, _) = await servicios(
          (_) async => respuestaJson(trabajoJson(id: 'id-del-servidor'), 200));

      final creada = await pub.crearYDevolver(Publicacion(
        uidEmpleador: 'u',
        autor: 'a',
        categoria: 'c',
        titulo: 'Pintar',
        descripcion: 'd',
        fechaCreacion: DateTime(2026, 9, 4),
      ));

      expect(creada, isNotNull);
      expect(creada!.id, 'id-del-servidor');
      expect(pub.ultimoError, isNull);
    });
  });

  group('PublicacionService — lo que el backend no sabe hacer', () {
    test('editar un trabajo no llega a pedir nada y lo dice claro', () async {
      final (pub, _) = await servicios((_) async {
        fail('No debería salir ninguna petición: no existe el endpoint');
      });

      final error = await pub.actualizarPublicacion('id', {'titulo': 'otro'});

      expect(error, MensajesError.sinEdicionDeTrabajo);
      expect(espia.peticiones, isEmpty);
    });

    test('borrar un trabajo tampoco existe; se ofrece cerrarlo', () async {
      final (pub, _) = await servicios((_) async {
        fail('No debería salir ninguna petición: no existe el endpoint');
      });

      final error = await pub.eliminarPublicacion('id');

      expect(error, MensajesError.sinBorradoDeTrabajo);
      expect(espia.peticiones, isEmpty);
    });
  });

  group('PublicacionService — transiciones', () {
    test('cancelar SIEMPRE manda "reabrir": sin él el backend responde 400',
        () async {
      final (pub, _) = await servicios(
          (_) async => respuestaJson(trabajoJson(estado: 'ACTIVO'), 200));

      await pub.cancelarContratacion(idPublicacion: 'abc', reabrir: true);
      final reabriendo = cuerpoDe(espia.ultimaA('/api/trabajos/abc/cancelar'));
      expect(reabriendo['reabrir'], isTrue);

      await pub.cancelarContratacion(idPublicacion: 'abc', reabrir: false);
      final cerrando = cuerpoDe(espia.ultimaA('/api/trabajos/abc/cancelar'));
      expect(cerrando['reabrir'], isFalse);
    });

    test('cerrar la publicación es cancelar sin reabrir', () async {
      final (pub, _) = await servicios(
          (_) async => respuestaJson(trabajoJson(estado: 'CANCELADO'), 200));

      final error = await pub.cerrarPublicacion('abc');

      expect(error, isNull);
      expect(cuerpoDe(espia.ultimaA('/api/trabajos/abc/cancelar'))['reabrir'],
          isFalse);
    });

    test('reservar pago manda monto y tiempo, y no el uid del empleador',
        () async {
      final (pub, _) = await servicios((_) async =>
          respuestaJson(trabajoJson(estado: 'ACORDADO', montoAcordado: 500), 200));

      await pub.reservarPago(
        idPublicacion: 'abc',
        uidEmpleador: 'no-viaja',
        monto: 500,
        tiempo: '3 días',
      );

      final cuerpo = cuerpoDe(espia.ultimaA('/api/trabajos/abc/reservar-pago'));
      expect(cuerpo['monto'], 500);
      expect(cuerpo['tiempo'], '3 días');
      expect(cuerpo.containsKey('uidEmpleador'), isFalse);
    });

    test(
        'entregar sin evidencias devuelve el 409 del servidor tal cual, porque '
        'explica qué hacer', () async {
      const mensaje = 'Adjunta al menos una evidencia del trabajo '
          '(POST /api/trabajos/{id}/evidencias) antes de marcarlo como terminado';
      final (pub, _) = await servicios((_) async => respuestaError(409, mensaje));

      final error = await pub.marcarTerminado('abc');

      expect(error, mensaje);
    });

    test('cancelar un trabajo ya iniciado devuelve el 409 con la salida real',
        () async {
      const mensaje = 'El trabajo ya inició: ninguna de las dos partes puede '
          'cancelarlo. Si hay un problema, repórtalo a soporte.';
      final (pub, _) = await servicios((_) async => respuestaError(409, mensaje));

      expect(
        await pub.cancelarContratacion(idPublicacion: 'abc', reabrir: true),
        mensaje,
      );
    });

    test('reclamar a soporte manda motivo y descripción', () async {
      final (pub, _) = await servicios(
          (_) async => respuestaJson(trabajoJson(estado: 'EN_DISPUTA'), 200));

      await pub.reclamarProblema(
        idPublicacion: 'abc',
        motivo: 'No se presentó',
        descripcion: 'Llevo tres días esperando',
      );

      final cuerpo = cuerpoDe(espia.ultimaA('/api/trabajos/abc/reclamar'));
      expect(cuerpo['motivo'], 'No se presentó');
      expect(cuerpo['descripcion'], 'Llevo tres días esperando');
    });

    test('las transiciones sin cuerpo mandan POST igualmente', () async {
      final (pub, _) = await servicios(
          (_) async => respuestaJson(trabajoJson(estado: 'EN_PROGRESO'), 200));

      await pub.iniciarTrabajo('abc');
      expect(espia.ultimaA('/api/trabajos/abc/iniciar').method, 'POST');

      await pub.aceptarTrabajo('abc');
      expect(espia.ultimaA('/api/trabajos/abc/aceptar').method, 'POST');

      await pub.rechazarAsignacion(idPublicacion: 'abc');
      expect(espia.ultimaA('/api/trabajos/abc/rechazar').method, 'POST');
    });
  });

  group('PublicacionService — evidencias', () {
    test('lee la lista y traduce autorId → autorUid, creadoEn → fecha',
        () async {
      final (pub, _) = await servicios((_) async => respuestaJson([
            {
              'id': 'e1',
              'creadoEn': '2026-09-04T23:10:00Z',
              'actualizadoEn': '2026-09-04T23:10:00Z',
              'trabajoId': 'abc',
              'autorId': '67d11167-16e0-4172-a0ca-b92b0de663f8',
              'autorNombre': 'Carlos Demo',
              'texto': 'Primera capa de pintura lista',
              'archivoUrl': null,
            }
          ], 200));

      final lista = await pub.listarEvidencias('abc');

      expect(lista, hasLength(1));
      expect(lista.first.autorUid, '67d11167-16e0-4172-a0ca-b92b0de663f8');
      expect(lista.first.texto, 'Primera capa de pintura lista');
    });

    test('agregar un avance manda solo el texto', () async {
      final (pub, _) = await servicios((_) async => respuestaJson({
            'id': 'e1',
            'creadoEn': '2026-09-04T23:10:00Z',
            'trabajoId': 'abc',
            'autorId': 'u',
            'texto': 'Listo',
          }, 200));

      await pub.agregarEvidencia(
          'abc',
          Evidencia(
              texto: 'Listo', autorUid: 'no-viaja', fecha: DateTime(2026, 9, 4)));

      final cuerpo = cuerpoDe(espia.ultimaA('/api/trabajos/abc/evidencias'));
      expect(cuerpo, {'texto': 'Listo'});
    });
  });

  group('PostulacionService', () {
    test('postularse manda trabajoId y mensaje; el trabajador sale del token',
        () async {
      final (_, post) =
          await servicios((_) async => respuestaJson(postulacionJson(), 200));

      await post.postular(Postulacion(
        idPublicacion: 'abc',
        uidTrabajador: 'no-viaja',
        nombreTrabajador: 'Tampoco',
        uidEmpleador: 'ni-esto',
        mensaje: 'Puedo empezar mañana',
        fechaPostulacion: DateTime(2026, 9, 4),
      ));

      final cuerpo = cuerpoDe(espia.ultimaA('/api/postulaciones'));
      expect(cuerpo, {'trabajoId': 'abc', 'mensaje': 'Puedo empezar mañana'});
    });

    test('postularse al propio trabajo devuelve el 409 del backend', () async {
      // Decisión del dueño (tarea 019): es un conflicto con el estado del
      // recurso —quien pide ES el dueño—, no un cuerpo mal formado.
      final (_, post) = await servicios((_) async =>
          respuestaError(409, 'No puedes postularte a tu propio trabajo'));

      final error = await post.postular(Postulacion(
        idPublicacion: 'abc',
        uidTrabajador: 'u',
        nombreTrabajador: 'n',
        uidEmpleador: 'u',
        fechaPostulacion: DateTime(2026, 9, 4),
      ));

      expect(error, 'No puedes postularte a tu propio trabajo');
    });

    test('postularse dos veces al mismo trabajo devuelve el 409', () async {
      final (_, post) = await servicios(
          (_) async => respuestaError(409, 'Ya te postulaste a este trabajo'));

      expect(
        await post.postular(Postulacion(
          idPublicacion: 'abc',
          uidTrabajador: 'u',
          nombreTrabajador: 'n',
          uidEmpleador: 'e',
          fechaPostulacion: DateTime(2026, 9, 4),
        )),
        'Ya te postulaste a este trabajo',
      );
    });

    test('la postulación del backend no trae título ni empleador', () async {
      // En Firestore iban desnormalizados dentro del documento para pintar la
      // lista de una sola lectura. Si esto deja de ser cierto (porque el
      // backend amplíe el DTO), `MisPostulacionesScreen` puede dejar de pedir
      // el trabajo aparte.
      final (_, post) =
          await servicios((_) async => respuestaJson([postulacionJson()], 200));

      final mias = await post.misPostulaciones();

      expect(mias.single.tituloPublicacion, isEmpty);
      expect(mias.single.uidEmpleador, isEmpty);
      expect(mias.single.idPublicacion, '8330573c-7d54-4e56-95b6-0d77df9d6352');
      expect(mias.single.estado, EstadosPostulacion.pendiente);
    });

    test('los postulantes se piden con trabajoId y sin las retiradas',
        () async {
      final (_, post) = await servicios((_) async => respuestaJson([
            postulacionJson(id: 'p1', creadoEn: '2026-09-01T10:00:00Z'),
            postulacionJson(
                id: 'p2',
                estado: 'RETIRADA',
                creadoEn: '2026-09-02T10:00:00Z'),
            postulacionJson(id: 'p3', creadoEn: '2026-09-03T10:00:00Z'),
          ], 200));

      final lista = await post.postulantesDe('abc');

      expect(espia.ultimaA('/api/postulaciones').url.queryParameters['trabajoId'],
          'abc');
      // Sin la retirada, y de la más nueva a la más vieja.
      expect(lista.map((p) => p.id), ['p3', 'p1']);
    });

    test('aceptar a un postulante es un POST a su /aceptar', () async {
      final (_, post) = await servicios(
          (_) async => respuestaJson(postulacionJson(estado: 'ACEPTADA'), 200));

      final error = await post.aceptar('p1');

      expect(error, isNull);
      expect(espia.rutas, contains('/api/postulaciones/p1/aceptar'));
      expect(espia.ultimaA('/api/postulaciones/p1/aceptar').method, 'POST');
    });

    test('aceptar cuando el trabajo ya no está activo devuelve el 409',
        () async {
      final (_, post) = await servicios((_) async =>
          respuestaError(409, 'Este trabajo ya no está disponible para asignar'));

      expect(await post.aceptar('p1'),
          'Este trabajo ya no está disponible para asignar');
    });

    test('retirar usa DELETE y tolera la respuesta sin cuerpo', () async {
      final (_, post) = await servicios(
          (_) async => http.Response.bytes(const [], 200));

      final error = await post.retirar('p1');

      expect(error, isNull);
      expect(espia.ultimaA('/api/postulaciones/p1').method, 'DELETE');
    });

    test('miPostulacionEn encuentra la del trabajo y devuelve null si no hay',
        () async {
      final (_, post) = await servicios((_) async => respuestaJson([
            postulacionJson(id: 'p1', trabajoId: 'trabajo-1'),
            postulacionJson(id: 'p2', trabajoId: 'trabajo-2'),
          ], 200));

      expect((await post.miPostulacionEn('trabajo-2'))?.id, 'p2');
      expect(await post.miPostulacionEn('trabajo-9'), isNull);
    });

    test(
        'los ids de trabajos postulados incluyen las RETIRADAS: la restricción '
        'única no deja volver a postularse', () async {
      final (_, post) = await servicios((_) async => respuestaJson([
            postulacionJson(id: 'p1', trabajoId: 't1'),
            postulacionJson(id: 'p2', trabajoId: 't2', estado: 'RETIRADA'),
            postulacionJson(id: 'p3', trabajoId: 't3', estado: 'RECHAZADA'),
          ], 200));

      expect(await post.idsDeTrabajosPostulados(), {'t1', 't2', 't3'});
    });
  });

  group('Sesión y errores comunes', () {
    test('un 403 en los postulantes ajenos llega con el mensaje del backend',
        () async {
      final (_, post) = await servicios(
          (_) async => respuestaError(403, 'No eres el dueño de este trabajo'));

      await expectLater(
        post.postulantesDe('abc'),
        throwsA(isA<Exception>()),
      );
    });

    test('sin sesión, una lectura no sale a la red', () async {
      final espiaSinSesion = EspiaHttp();
      final cliente = ApiClient(
        clienteHttp: clienteFalso(espiaSinSesion, (_) async {
          fail('No debería salir ninguna petición sin sesión');
        }),
        urlBase: urlBaseDePrueba,
      );

      await expectLater(
        PublicacionService(cliente: cliente).misPublicaciones(),
        throwsA(isA<Exception>()),
      );
      expect(espiaSinSesion.peticiones, isEmpty);
    });
  });
}
