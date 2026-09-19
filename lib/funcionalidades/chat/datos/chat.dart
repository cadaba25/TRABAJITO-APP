import '../../../compartido/modelos/json_utiles.dart';
import '../../../nucleo/dominio/estados.dart';

/// Chat entre contratista y trabajador (uno por trabajo asignado). Entidad
/// `ChatRoom` del backend; lo crea el servidor al aceptar la postulación.
///
/// Nombres que cambian respecto a la época de Firestore:
/// `trabajoId` → [idPublicacion], `tituloTrabajo` → [tituloPublicacion],
/// `empleadorId`/`trabajadorId` → [uidEmpleador]/[uidTrabajador],
/// `empleadorNombre`/`trabajadorNombre` → [nombreEmpleador]/[nombreTrabajador].
/// **[id] es un UUID propio, NO el del trabajo.**
///
/// `participantes` ya no existe (se deduce de los dos uid). Los no leídos no
/// vienen en el chat sino de `GET /api/chats/no-leidos`: [noLeidos] los rellena
/// `ChatService.misChats()` con [conNoLeidos] y vale 0 si nadie lo hizo.
///
/// El backend manda `null` donde Firestore guardaba cadena vacía
/// (`pagoPropuestoPor`, `tiempoValor`...): `desdeJson` lo normaliza a `''`.
class Chat {
  final String id;
  final String idPublicacion;
  final String tituloPublicacion;
  final String uidEmpleador;
  final String nombreEmpleador;
  final String uidTrabajador;
  final String nombreTrabajador;
  final String ultimoMensaje;
  final DateTime fechaUltimoMensaje;

  /// Mensajes del otro sin leer, para el usuario que consulta.
  final int noLeidos;

  // Negociación de pago
  final double pagoMonto;
  final String pagoPropuestoPor;
  final bool pagoAcordado;
  // Negociación de tiempo
  final String tiempoValor;
  final String tiempoPropuestoPor;
  final bool tiempoAcordado;

  const Chat({
    required this.id,
    required this.idPublicacion,
    this.tituloPublicacion = '',
    required this.uidEmpleador,
    this.nombreEmpleador = '',
    required this.uidTrabajador,
    this.nombreTrabajador = '',
    this.ultimoMensaje = '',
    required this.fechaUltimoMensaje,
    this.noLeidos = 0,
    this.pagoMonto = 0,
    this.pagoPropuestoPor = '',
    this.pagoAcordado = false,
    this.tiempoValor = '',
    this.tiempoPropuestoPor = '',
    this.tiempoAcordado = false,
  });

  /// Nombre de la otra persona para mostrar en la lista/encabezado.
  String otroNombre(String miUid) =>
      miUid == uidEmpleador ? nombreTrabajador : nombreEmpleador;

  bool get pagoPendiente => pagoPropuestoPor.isNotEmpty && !pagoAcordado;
  bool get tiempoPendiente => tiempoPropuestoPor.isNotEmpty && !tiempoAcordado;

  /// Pago y tiempo acordados por las dos partes: condición para depositar.
  bool get acuerdoCompleto => pagoAcordado && tiempoAcordado;

  Chat conNoLeidos(int n) => Chat(
        id: id,
        idPublicacion: idPublicacion,
        tituloPublicacion: tituloPublicacion,
        uidEmpleador: uidEmpleador,
        nombreEmpleador: nombreEmpleador,
        uidTrabajador: uidTrabajador,
        nombreTrabajador: nombreTrabajador,
        ultimoMensaje: ultimoMensaje,
        fechaUltimoMensaje: fechaUltimoMensaje,
        noLeidos: n,
        pagoMonto: pagoMonto,
        pagoPropuestoPor: pagoPropuestoPor,
        pagoAcordado: pagoAcordado,
        tiempoValor: tiempoValor,
        tiempoPropuestoPor: tiempoPropuestoPor,
        tiempoAcordado: tiempoAcordado,
      );

  factory Chat.desdeJson(Map<String, dynamic> json) => Chat(
        id: textoJson(json['id']),
        idPublicacion: textoJson(json['trabajoId']),
        tituloPublicacion: textoJson(json['tituloTrabajo']),
        uidEmpleador: textoJson(json['empleadorId']),
        nombreEmpleador: textoJson(json['empleadorNombre']),
        uidTrabajador: textoJson(json['trabajadorId']),
        nombreTrabajador: textoJson(json['trabajadorNombre']),
        ultimoMensaje: textoJson(json['ultimoMensaje']),
        fechaUltimoMensaje: fechaJson(
          json['fechaUltimoMensaje'],
          siFalta: fechaJsonOpcional(json['creadoEn']),
        ),
        pagoMonto: decimalJson(json['pagoMonto']),
        pagoPropuestoPor: textoJson(json['pagoPropuestoPor']),
        pagoAcordado: boolJson(json['pagoAcordado']),
        tiempoValor: textoJson(json['tiempoValor']),
        tiempoPropuestoPor: textoJson(json['tiempoPropuestoPor']),
        tiempoAcordado: boolJson(json['tiempoAcordado']),
      );
}

/// Mensaje dentro de un chat (entidad `Mensaje` del backend).
///
/// El texto viaja como `contenido` y la fecha como `creadoEn`. El enum
/// `tipo` (`TEXTO`, `IMAGEN`, `ARCHIVO`, `PROPUESTA_PAGO`, `PROPUESTA_TIEMPO`,
/// `SISTEMA`) se reduce a texto/sistema: ver `TiposMensaje`.
class Mensaje {
  final String id;
  final String texto;
  final String deUid;
  final String tipo; // 'texto' | 'sistema'
  final DateTime fecha;

  const Mensaje({
    this.id = '',
    required this.texto,
    required this.deUid,
    this.tipo = 'texto',
    required this.fecha,
  });

  bool get esSistema => tipo == 'sistema';

  factory Mensaje.desdeJson(Map<String, dynamic> json) => Mensaje(
        id: textoJson(json['id']),
        texto: textoJson(json['contenido']),
        deUid: textoJson(json['deUid']),
        tipo: TiposMensaje.desdeApi(json['tipo']),
        fecha: fechaJson(json['creadoEn']),
      );

  /// Cuerpo de `POST /api/chats/{id}/mensajes`. `contenido` es obligatorio
  /// (máx. 2000 caracteres); el autor sale del token.
  Map<String, dynamic> aJson() => {'contenido': texto};
}
