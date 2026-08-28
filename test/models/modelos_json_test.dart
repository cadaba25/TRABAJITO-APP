import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/models/calificacion.dart';
import 'package:trabajito/models/chat.dart';
import 'package:trabajito/models/evidencia.dart';
import 'package:trabajito/models/postulacion.dart';
import 'package:trabajito/models/publicacion.dart';
import 'package:trabajito/models/tarjeta.dart';
import 'package:trabajito/models/usuario.dart';
import 'package:trabajito/utils/constantes.dart';

/// Los JSON de este archivo **no están inventados**: se copiaron de las
/// respuestas del backend real (VM Ubuntu, 2026-08-27) durante la tarea 018.
/// Si el backend cambia el contrato, estos tests son los que se enteran.
void main() {
  group('Usuario.desdeJson — UsuarioResponse real', () {
    // Copiado de POST /api/auth/registro. Nótense los `null`: el backend los
    // manda en todo campo opcional, donde la app espera cadena vacía.
    final json = jsonDecode('''
    {"id":"2841f8e3-f7e9-4eda-babf-bfd8fefd45cc",
     "correo":"f018-1787805949@trabajito.test","nombres":"Fase",
     "apellidos":"Uno","nombreCompleto":"Fase Uno","dni":"0801199912345",
     "telefono":"99887766","rol":"TRABAJADOR","fotoUrl":null,
     "presentacion":null,"departamento":"Francisco Morazan",
     "ciudad":"Tegucigalpa","trabajosCompletados":0,"trabajosPublicados":0,
     "pagosConfirmados":0,"calificacionPromedio":0.00,"totalCalificaciones":0,
     "saldo":0.00,"tipoEmpleador":null,"nombreEmpresa":null,
     "sectorEmpresa":null,"tamanoEmpresa":null,"sitioWeb":null}
    ''') as Map<String, dynamic>;

    test('mapea id → uid y fotoUrl → fotoPerfil', () {
      final usuario = Usuario.desdeJson(json);
      expect(usuario.uid, '2841f8e3-f7e9-4eda-babf-bfd8fefd45cc');
      expect(usuario.correo, 'f018-1787805949@trabajito.test');
      expect(usuario.fotoPerfil, '');
    });

    test('los null del backend se vuelven cadena vacía, no "null"', () {
      final usuario = Usuario.desdeJson(json);
      expect(usuario.presentacion, '');
      expect(usuario.nombreEmpresa, '');
      expect(usuario.sitioWeb, '');
    });

    test('el rol en MAYÚSCULAS alimenta rol y tipoUsuario', () {
      final trabajador = Usuario.desdeJson(json);
      expect(trabajador.rol, ValoresDefecto.rolTrabajador);
      expect(trabajador.tipoUsuario, ValoresDefecto.rolTrabajador);
      expect(trabajador.esEmpleador, isFalse);

      final empleador = Usuario.desdeJson({...json, 'rol': 'EMPLEADOR'});
      expect(empleador.rol, ValoresDefecto.rolEmpleador);
      expect(empleador.esEmpleador, isTrue);
    });

    test('ADMIN conserva su rol pero no se disfraza de empleador', () {
      final admin = Usuario.desdeJson({...json, 'rol': 'ADMIN'});
      expect(admin.rol, RolesApi.admin);
      expect(admin.esEmpleador, isFalse,
          reason: 'en Flutter no hay pantallas de administración');
    });

    test('un rol desconocido cae en trabajador (el de menos privilegios)', () {
      final raro = Usuario.desdeJson({...json, 'rol': 'SUPERJEFE'});
      expect(raro.rol, ValoresDefecto.rolTrabajador);
    });

    test('los BigDecimal llegan como número JSON y se leen como double', () {
      final usuario = Usuario.desdeJson({
        ...json,
        'saldo': 1250.50,
        'calificacionPromedio': 4.75,
        'totalCalificaciones': 8,
      });
      expect(usuario.saldo, 1250.50);
      expect(usuario.calificacionPromedio, 4.75);
      expect(usuario.totalCalificaciones, 8);
    });

    test('nombreCompleto y iniciales siguen funcionando con datos de la API',
        () {
      final usuario = Usuario.desdeJson(json);
      expect(usuario.nombreCompleto, 'Fase Uno');
      expect(usuario.iniciales, 'FU');
    });

    test('aJson() manda solo los campos editables del perfil', () {
      final cuerpo = Usuario.desdeJson(json).aJson();

      expect(cuerpo.keys, containsAll(<String>['nombres', 'telefono', 'fotoUrl']));
      // Lo que el backend NO deja tocar al dueño de la cuenta: no se manda.
      expect(cuerpo, isNot(contains('rol')));
      expect(cuerpo, isNot(contains('saldo')));
      expect(cuerpo, isNot(contains('correo')));
      expect(cuerpo, isNot(contains('trabajosCompletados')));
      expect(cuerpo, isNot(contains('calificacionPromedio')));
    });

    test('aJsonRegistro() usa RolPublico en mayúsculas y lleva la contraseña',
        () {
      final cuerpo = Usuario.desdeJson({...json, 'rol': 'EMPLEADOR'})
          .aJsonRegistro(password: 'ClaveDePrueba018');

      expect(cuerpo['rol'], 'EMPLEADOR');
      expect(cuerpo['password'], 'ClaveDePrueba018');
      expect(cuerpo['correo'], 'f018-1787805949@trabajito.test');
      expect(cuerpo, isNot(contains('saldo')));
    });
  });

  group('Publicacion.desdeJson — TrabajoResponse real', () {
    // Copiado de POST /api/trabajos.
    final json = jsonDecode('''
    {"id":"584221bb-03d4-4624-8cf4-0695378ba200",
     "empleadorId":"c15d2312-64f0-4f22-a505-d0644f0dc23d",
     "autorNombre":"Fase Cuatro","titulo":"Prueba fase 1",
     "descripcion":"Verificar forma del JSON","categoria":"Construccion",
     "departamento":"Cortes","ciudad":"San Pedro Sula","zona":"Centro",
     "presupuesto":"L. 800","plazo":"Corto plazo","estado":"ACTIVO",
     "trabajadorAsignadoId":null,"trabajadorAsignadoNombre":null,
     "montoAcordado":0,"tiempoAcordado":null,"fechaAcuerdo":null,
     "fechaInicio":null,"pagoRetenido":false,"entregado":false,
     "pagoLiberado":false,"correccionSolicitada":false,
     "motivoCorreccion":null,"fechaSolicitudCorreccion":null,
     "disputaAbiertaPorId":null,"motivoDisputa":null,"resolucionDisputa":null,
     "calificadoPorEmpleador":false,"calificadoPorTrabajador":false,
     "creadoEn":"2026-08-27T04:46:47.688473359Z"}
    ''') as Map<String, dynamic>;

    test('mapea los nombres que cambian respecto a Firestore', () {
      final publicacion = Publicacion.desdeJson(json);
      expect(publicacion.uidEmpleador, 'c15d2312-64f0-4f22-a505-d0644f0dc23d');
      expect(publicacion.autor, 'Fase Cuatro');
      expect(publicacion.titulo, 'Prueba fase 1');
      expect(publicacion.ubicacionDetallada, 'Centro, San Pedro Sula, Cortes');
    });

    test('el enum de estado pasa a la constante de la app', () {
      expect(Publicacion.desdeJson(json).estado, EstadosTrabajo.activo);
      expect(
          Publicacion.desdeJson({...json, 'estado': 'EN_PROGRESO'}).estado,
          EstadosTrabajo.enProgreso);
      expect(
          Publicacion.desdeJson({...json, 'estado': 'ESPERANDO_CONFIRMACION'})
              .estado,
          EstadosTrabajo.esperandoConfirmacion);
      expect(Publicacion.desdeJson({...json, 'estado': 'EN_DISPUTA'}).estado,
          EstadosTrabajo.enDisputa);
      expect(Publicacion.desdeJson({...json, 'estado': 'CANCELADO'}).estado,
          EstadosTrabajo.cancelado);
    });

    test('un estado que la app no conoce no se cuela por la UI', () {
      final publicacion =
          Publicacion.desdeJson({...json, 'estado': 'ESTADO_DEL_FUTURO'});
      expect(publicacion.estado, EstadosTrabajo.cerrado);
      expect(EstadosTrabajo.etiqueta(publicacion.estado), 'Cerrado');
    });

    test('la fecha ISO con nanosegundos se lee sin perder el instante', () {
      final publicacion = Publicacion.desdeJson(json);
      expect(publicacion.fechaCreacion.toUtc().toIso8601String(),
          startsWith('2026-08-27T04:46:47.688473'));
    });

    test('las fechas opcionales en null siguen siendo null', () {
      final publicacion = Publicacion.desdeJson(json);
      expect(publicacion.fechaAcuerdo, isNull);
      expect(publicacion.fechaInicio, isNull);
    });

    test('el escrow ya acordado se lee completo', () {
      final publicacion = Publicacion.desdeJson({
        ...json,
        'estado': 'EN_PROGRESO',
        'montoAcordado': 1500.00,
        'tiempoAcordado': '3 días',
        'fechaAcuerdo': '2026-08-27T05:00:00Z',
        'fechaInicio': '2026-08-27T06:30:00Z',
        'pagoRetenido': true,
        'trabajadorAsignadoId': 'aaa',
        'trabajadorAsignadoNombre': 'Juan Pérez',
      });

      expect(publicacion.montoAcordado, 1500.00);
      expect(publicacion.tiempoAcordado, '3 días');
      expect(publicacion.pagoRetenido, isTrue);
      expect(publicacion.uidTrabajadorAsignado, 'aaa');
      expect(publicacion.nombreTrabajadorAsignado, 'Juan Pérez');
      expect(publicacion.fechaAcuerdo, isNotNull);
    });

    test('aJson() no manda nada que decida el servidor', () {
      final cuerpo = Publicacion.desdeJson(json).aJson();

      expect(cuerpo['titulo'], 'Prueba fase 1');
      expect(cuerpo['zona'], 'Centro');
      for (final prohibido in [
        'estado',
        'empleadorId',
        'pagoRetenido',
        'montoAcordado',
        'pagoLiberado',
        'creadoEn',
      ]) {
        expect(cuerpo, isNot(contains(prohibido)),
            reason: '$prohibido lo fija el backend, no el cliente');
      }
    });
  });

  group('Postulacion.desdeJson', () {
    final json = <String, dynamic>{
      'id': '7c2f',
      'trabajoId': '584221bb',
      'trabajadorId': '2841f8e3',
      'trabajadorNombre': 'Fase Uno',
      'mensaje': 'Tengo 5 años de experiencia en albañilería',
      'estado': 'PENDIENTE',
      'creadoEn': '2026-08-27T04:50:00.123456Z',
    };

    test('mapea trabajoId → idPublicacion y el estado a minúsculas', () {
      final postulacion = Postulacion.desdeJson(json);
      expect(postulacion.idPublicacion, '584221bb');
      expect(postulacion.uidTrabajador, '2841f8e3');
      expect(postulacion.nombreTrabajador, 'Fase Uno');
      expect(postulacion.estado, EstadosPostulacion.pendiente);
    });

    test('los cuatro estados del backend tienen su equivalente', () {
      String estadoDe(String api) =>
          Postulacion.desdeJson({...json, 'estado': api}).estado;

      expect(estadoDe('PENDIENTE'), EstadosPostulacion.pendiente);
      expect(estadoDe('ACEPTADA'), EstadosPostulacion.aceptada);
      expect(estadoDe('RECHAZADA'), EstadosPostulacion.rechazada);
      expect(estadoDe('RETIRADA'), EstadosPostulacion.retirada);
    });

    test('los campos que el backend no manda quedan vacíos, no rompen', () {
      final postulacion = Postulacion.desdeJson(json);
      // Firestore los llevaba desnormalizados dentro de la postulación.
      expect(postulacion.tituloPublicacion, '');
      expect(postulacion.uidEmpleador, '');
    });

    test('aJson() manda el trabajo y el mensaje', () {
      expect(Postulacion.desdeJson(json).aJson(), {
        'trabajoId': '584221bb',
        'mensaje': 'Tengo 5 años de experiencia en albañilería',
      });
    });
  });

  group('Calificacion.desdeJson', () {
    final json = <String, dynamic>{
      'id': 'cal-1',
      'trabajoId': '584221bb',
      'autorId': 'emp-1',
      'receptorId': 'tra-1',
      'estrellas': 5,
      'comentario': 'Excelente trabajo, muy puntual',
      'creadoEn': '2026-08-27T07:00:00Z',
    };

    test('mapea autorId → deUid y receptorId → paraUid', () {
      final calificacion = Calificacion.desdeJson(json);
      expect(calificacion.idPublicacion, '584221bb');
      expect(calificacion.deUid, 'emp-1');
      expect(calificacion.paraUid, 'tra-1');
      expect(calificacion.estrellas, 5);
      expect(calificacion.comentario, 'Excelente trabajo, muy puntual');
    });

    test('lo que el backend no manda queda vacío', () {
      final calificacion = Calificacion.desdeJson(json);
      expect(calificacion.deNombre, '');
      expect(calificacion.rolCalificado, '');
    });

    test('aJson() no manda quién califica: sale del token', () {
      final cuerpo = Calificacion.desdeJson(json).aJson();
      expect(cuerpo, {
        'trabajoId': '584221bb',
        'receptorId': 'tra-1',
        'estrellas': 5,
        'comentario': 'Excelente trabajo, muy puntual',
      });
      expect(cuerpo, isNot(contains('autorId')));
    });
  });

  group('Evidencia.desdeJson', () {
    final json = <String, dynamic>{
      'id': 'ev-1',
      'trabajoId': '584221bb',
      'autorId': 'tra-1',
      'autorNombre': 'Fase Uno',
      'texto': 'Terminé la instalación eléctrica del segundo piso',
      'archivoUrl': '/archivos/foto.jpg',
      'creadoEn': '2026-08-27T08:00:00Z',
    };

    test('mapea autorId → autorUid y creadoEn → fecha', () {
      final evidencia = Evidencia.desdeJson(json);
      expect(evidencia.autorUid, 'tra-1');
      expect(evidencia.autorNombre, 'Fase Uno');
      expect(evidencia.texto,
          'Terminé la instalación eléctrica del segundo piso');
      expect(evidencia.fecha.toUtc().year, 2026);
    });

    test('aJson() solo manda el texto', () {
      expect(Evidencia.desdeJson(json).aJson(),
          {'texto': 'Terminé la instalación eléctrica del segundo piso'});
    });
  });

  group('Chat y Mensaje desdeJson', () {
    final chatJson = <String, dynamic>{
      'id': 'chat-1',
      'trabajoId': '584221bb',
      'tituloTrabajo': 'Prueba fase 1',
      'empleadorId': 'emp-1',
      'empleadorNombre': 'Fase Cuatro',
      'trabajadorId': 'tra-1',
      'trabajadorNombre': 'Fase Uno',
      'ultimoMensaje': '¿Podemos vernos mañana?',
      'fechaUltimoMensaje': '2026-08-27T09:00:00Z',
      'pagoMonto': 800.00,
      'pagoPropuestoPor': 'emp-1',
      'pagoAcordado': false,
      'tiempoValor': '2 días',
      'tiempoPropuestoPor': 'tra-1',
      'tiempoAcordado': true,
    };

    test('mapea los ids y la negociación de pago y tiempo', () {
      final chat = Chat.desdeJson(chatJson);
      expect(chat.idPublicacion, '584221bb');
      expect(chat.uidEmpleador, 'emp-1');
      expect(chat.uidTrabajador, 'tra-1');
      expect(chat.pagoMonto, 800.00);
      expect(chat.pagoPendiente, isTrue);
      expect(chat.tiempoPendiente, isFalse);
      expect(chat.otroNombre('emp-1'), 'Fase Uno');
      expect(chat.otroNombre('tra-1'), 'Fase Cuatro');
    });

    test('participantes se reconstruye: el backend no lo manda', () {
      expect(Chat.desdeJson(chatJson).participantes, ['emp-1', 'tra-1']);
    });

    test('noLeidos queda vacío porque el backend no lleva ese contador', () {
      // Anotado como pendiente de la fase 2 (chat + WebSocket).
      expect(Chat.desdeJson(chatJson).noLeidos, isEmpty);
      expect(Chat.desdeJson(chatJson).noLeidosDe('emp-1'), 0);
    });

    test('Mensaje: contenido → texto y el tipo se reduce a texto/sistema', () {
      final mensaje = Mensaje.desdeJson({
        'id': 'm-1',
        'contenido': '¿Podemos vernos mañana?',
        'deUid': 'emp-1',
        'tipo': 'TEXTO',
        'creadoEn': '2026-08-27T09:00:00Z',
      });

      expect(mensaje.texto, '¿Podemos vernos mañana?');
      expect(mensaje.tipo, TiposMensaje.texto);
      expect(mensaje.esSistema, isFalse);
    });

    test('los tipos que la app no pinta se tratan como mensajes de sistema',
        () {
      for (final tipo in ['SISTEMA', 'PROPUESTA_PAGO', 'IMAGEN', 'ARCHIVO']) {
        final mensaje = Mensaje.desdeJson(
            {'contenido': 'x', 'deUid': 'a', 'tipo': tipo});
        expect(mensaje.esSistema, isTrue, reason: 'tipo $tipo');
      }
    });

    test('Mensaje.aJson() usa el nombre que espera el backend', () {
      final mensaje = Mensaje(texto: 'Hola', deUid: 'a', fecha: DateTime.now());
      expect(mensaje.aJson(), {'contenido': 'Hola'});
    });
  });

  group('Tarjeta', () {
    test('va y vuelve sin perder datos, y nunca lleva el número completo', () {
      const tarjeta = Tarjeta(
        id: 't-1',
        marca: 'Visa',
        ultimos4: '4242',
        titular: 'Fase Uno',
        vencimiento: '12/28',
      );
      final ida = tarjeta.aJson();
      final vuelta = Tarjeta.desdeJson({'id': 't-1', ...ida});

      expect(vuelta.marca, 'Visa');
      expect(vuelta.ultimos4, '4242');
      expect(vuelta.vencimiento, '12/28');
      expect(ida.keys, isNot(contains('numero')));
      expect(ida.keys, isNot(contains('cvv')));
    });
  });

  group('Aguante ante JSON inesperado', () {
    // Un backend que cambia un tipo no debe tumbar una pantalla entera.
    test('un objeto vacío no revienta ningún modelo', () {
      expect(Usuario.desdeJson(const {}).uid, '');
      expect(Publicacion.desdeJson(const {}).titulo, '');
      expect(Postulacion.desdeJson(const {}).estado,
          EstadosPostulacion.pendiente);
      expect(Calificacion.desdeJson(const {}).estrellas, 0);
      expect(Evidencia.desdeJson(const {}).texto, '');
      expect(Chat.desdeJson(const {}).participantes, isEmpty);
      expect(Mensaje.desdeJson(const {}).texto, '');
    });

    test('tipos equivocados caen al valor por defecto', () {
      final publicacion = Publicacion.desdeJson(const {
        'titulo': 123,
        'montoAcordado': 'mil',
        'pagoRetenido': 'sí',
        'creadoEn': 'no es una fecha',
      });

      expect(publicacion.titulo, '123');
      expect(publicacion.montoAcordado, 0);
      expect(publicacion.pagoRetenido, isFalse);
      expect(publicacion.fechaCreacion, isNotNull);
    });
  });
}
