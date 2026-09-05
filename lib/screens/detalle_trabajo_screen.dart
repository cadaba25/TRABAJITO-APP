import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/evidencia.dart';
import '../models/postulacion.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
import '../services/api/api_excepciones.dart';
import '../services/chat_service.dart';
import '../services/postulacion_service.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import 'calificar_sheet.dart';
import 'chat_screen.dart';
import 'editar_trabajo_screen.dart';
import 'postularse_sheet.dart';
import 'postulantes_screen.dart';

/// Detalle completo de una publicación de trabajo, con la acción contextual
/// según el rol del usuario y el estado del trabajo.
///
/// **Ya no escucha nada en vivo.** Antes había tres streams de Firestore
/// anidados (el trabajo, la postulación propia y las evidencias) que se
/// actualizaban solos. Ahora se pide todo al abrir la pantalla, se vuelve a
/// pedir **después de cada acción** —que es cuando de verdad ha cambiado algo—
/// y se puede recargar deslizando hacia abajo. Es la decisión del `tech-lead`
/// para la fase 2 (tarea 018): carga puntual, nada de sondeo.
///
/// ## Lo que cambió de comportamiento, y por qué
///
/// Estas no son decisiones de diseño de la pantalla: son reglas del servidor
/// (ADR-0007) que antes no existían, porque la versión de Firestore escribía
/// el estado directamente desde el móvil.
///
/// - **Cancelar solo antes de iniciar.** Desde `en_progreso` ninguna de las
///   dos partes cancela (409). La única salida es reclamar a soporte, que deja
///   el dinero congelado hasta que un ADMIN resuelva. Por eso el botón de
///   cancelar desaparece en esos estados y aparece el de reclamar, que antes
///   solo enseñaba un "próximamente".
/// - **Cancelar obliga a elegir** entre devolver el trabajo al feed o cerrarlo:
///   el backend exige `reabrir` y sin él responde 400. De ahí el diálogo con
///   dos opciones en vez de un "¿seguro?".
/// - **Entregar exige haber subido al menos una evidencia** (y una nueva si
///   hubo petición de correcciones). La pantalla lo avisa antes de intentarlo,
///   para que el trabajador no descubra la regla a base de errores.
class DetalleTrabajoScreen extends StatefulWidget {
  final Publicacion publicacion;
  final Usuario usuario;
  const DetalleTrabajoScreen({
    super.key,
    required this.publicacion,
    required this.usuario,
  });

  @override
  State<DetalleTrabajoScreen> createState() => _DetalleTrabajoScreenState();
}

class _DetalleTrabajoScreenState extends State<DetalleTrabajoScreen> {
  final _pubService = PublicacionService();
  final _postService = PostulacionService();

  /// Última versión conocida del trabajo. Arranca con la que trajo la lista y
  /// se sustituye en cuanto responde el servidor.
  late Publicacion _pub = widget.publicacion;

  /// Postulación propia a este trabajo, si la hay. `null` mientras no se sepa.
  Postulacion? _miPostulacion;
  List<Evidencia> _evidencias = const [];
  bool _recargando = false;

  Usuario get usuario => widget.usuario;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Pide todo lo que la pantalla enseña. Se llama al abrir, al deslizar y
  /// después de cada acción.
  ///
  /// Ninguna de las tres lecturas puede tumbar a las otras: si el trabajo se
  /// lee pero las evidencias dan 403 (porque quien mira no participa), se
  /// enseña el trabajo igual.
  Future<void> _cargar() async {
    if (_recargando) return;
    setState(() => _recargando = true);

    try {
      final trabajo = await _pubService.recargarPublicacion(widget.publicacion.id);
      if (mounted) setState(() => _pub = trabajo);
    } on ExcepcionApi catch (e) {
      // Se sigue enseñando lo que ya se tenía; el usuario no se queda en
      // blanco por un corte de red.
      debugPrint('No se pudo recargar el trabajo: $e');
      if (mounted) mostrarSnackBar(context, e.mensaje, esError: true);
    }

    await Future.wait([_cargarMiPostulacion(), _cargarEvidencias()]);
    if (mounted) setState(() => _recargando = false);
  }

  /// Solo tiene sentido para un trabajador que no es ni el dueño ni el
  /// asignado: es lo que decide si el botón dice "Postularme" o "Ya te
  /// postulaste".
  Future<void> _cargarMiPostulacion() async {
    if (usuario.esEmpleador || _esDueno(_pub) || _esAsignado(_pub)) return;
    try {
      final mia = await _postService.miPostulacionEn(_pub.id);
      if (mounted) setState(() => _miPostulacion = mia);
    } on ExcepcionApi catch (e) {
      debugPrint('No se pudo leer la postulación propia: $e');
    }
  }

  /// Las evidencias solo las puede leer quien participa en el trabajo (403 en
  /// otro caso), y solo existen a partir de que el trabajo está en marcha.
  Future<void> _cargarEvidencias() async {
    const conAvances = [
      EstadosTrabajo.enProgreso,
      EstadosTrabajo.esperandoConfirmacion,
      EstadosTrabajo.enDisputa,
      EstadosTrabajo.completado,
      EstadosTrabajo.finalizado,
    ];
    if (!conAvances.contains(_pub.estado) ||
        (!_esDueno(_pub) && !_esAsignado(_pub))) {
      if (_evidencias.isNotEmpty && mounted) {
        setState(() => _evidencias = const []);
      }
      return;
    }
    try {
      final lista = await _pubService.listarEvidencias(_pub.id);
      if (mounted) setState(() => _evidencias = lista);
    } on ExcepcionApi catch (e) {
      debugPrint('No se pudieron leer los avances: $e');
    }
  }

  /// Ejecuta una acción y **recarga después**. Sin stream, esto es lo único
  /// que mantiene la pantalla al día tras cambiar de estado.
  Future<void> _accion(Future<String?> Function() accion,
      {required String exito}) async {
    final ok = await ejecutarConCarga(context, accion, exito: exito);
    if (ok && mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) => _contenido(context, _pub);

  bool _esDueno(Publicacion pub) => usuario.uid == pub.uidEmpleador;
  bool _esAsignado(Publicacion pub) => usuario.uid == pub.uidTrabajadorAsignado;

  Widget _contenido(BuildContext context, Publicacion pub) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del trabajo',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: RefreshIndicator(
        color: AppColores.acento,
        onRefresh: _cargar,
        child: SingleChildScrollView(
        // Deslizar para actualizar tiene que funcionar aunque el detalle
        // quepa entero en la pantalla.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColores.acento.withValues(alpha: 0.15),
                  child: Text(
                    pub.autor.isNotEmpty ? pub.autor[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppColores.acento, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pub.autor.isEmpty ? 'Anónimo' : pub.autor,
                          style: TextStyle(
                              color: textoPrincipal,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text(pub.tiempoRelativo,
                          style: TextStyle(color: textoSec, fontSize: 12)),
                    ],
                  ),
                ),
                _badgeEstado(pub.estado),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (pub.categoria.isNotEmpty)
                  _chip(pub.categoria, AppColores.acento),
                if (pub.plazo.isNotEmpty)
                  _chip(pub.plazo, AppColores.azulProfesional),
              ],
            ),
            const SizedBox(height: 12),
            Text(pub.titulo,
                style: TextStyle(
                    color: textoPrincipal,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: superficie,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borde, width: 1),
              ),
              child: Column(
                children: [
                  _fila(context, Icons.location_on_outlined, 'Ubicación',
                      pub.ubicacionDetallada.isEmpty ? 'Honduras' : pub.ubicacionDetallada),
                  Divider(height: 1, color: borde, indent: 16, endIndent: 16),
                  _fila(context, Icons.payments_outlined, 'Presupuesto',
                      pub.presupuesto.isEmpty ? 'A convenir' : pub.presupuesto),
                  if (pub.uidTrabajadorAsignado.isNotEmpty) ...[
                    Divider(height: 1, color: borde, indent: 16, endIndent: 16),
                    _fila(context, Icons.assignment_ind_outlined, 'Asignado a',
                        pub.nombreTrabajadorAsignado),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Descripción',
                style: TextStyle(
                    color: textoPrincipal,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              pub.descripcion.isEmpty ? 'Sin descripción.' : pub.descripcion,
              style: TextStyle(color: textoSec, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            ..._acciones(context, pub),
            const SizedBox(height: 24),
          ],
        ),
        ),
      ),
    );
  }

  // ── Acciones contextuales (máquina de estados del flujo) ───
  List<Widget> _acciones(BuildContext context, Publicacion pub) {
    final esDueno = _esDueno(pub);
    final esTrab = _esAsignado(pub);
    final e = pub.estado;

    // ── No participante ──
    if (!esDueno && !esTrab) {
      if (usuario.esEmpleador) return [];
      if (e != EstadosTrabajo.activo) {
        return [
          const ElevatedButton(
            onPressed: null,
            child: Text('Este trabajo ya no está disponible'),
          ),
        ];
      }
      return [_botonPostular(context, pub)];
    }

    // ── Dueño con trabajo aún abierto ──
    if (esDueno && e == EstadosTrabajo.activo) {
      return [
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PostulantesScreen(publicacion: pub))),
          icon: const Icon(Icons.people_outline_rounded),
          label: const Text('Ver postulantes'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => EditarTrabajoScreen(publicacion: pub))),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar trabajo'),
        ),
      ];
    }
    if (pub.uidTrabajadorAsignado.isEmpty) return [];

    final w = <Widget>[];

    // Contrato (desde 'acordado' en adelante)
    const conContrato = [
      EstadosTrabajo.acordado, EstadosTrabajo.enProgreso,
      EstadosTrabajo.esperandoConfirmacion, EstadosTrabajo.completado,
      EstadosTrabajo.finalizado,
    ];
    if (conContrato.contains(e)) {
      w.add(_tarjetaContrato(context, pub));
      w.add(const SizedBox(height: 16));
    }

    // Chat
    w.add(_botonChat(context, pub));

    // Aviso de corrección solicitada (para el trabajador)
    if (pub.correccionSolicitada && e == EstadosTrabajo.enProgreso && esTrab) {
      w.add(const SizedBox(height: 12));
      w.add(_infoBanner('Correcciones solicitadas: ${pub.motivoCorreccion}',
          color: AppColores.advertencia));
    }

    // Evidencias / avances
    if ([EstadosTrabajo.enProgreso, EstadosTrabajo.esperandoConfirmacion,
         EstadosTrabajo.enDisputa, EstadosTrabajo.completado,
         EstadosTrabajo.finalizado].contains(e)) {
      w.add(const SizedBox(height: 16));
      w.add(_seccionEvidencias(context, pub,
          puedeAgregar: esTrab && e == EstadosTrabajo.enProgreso));
    }

    w.add(const SizedBox(height: 16));

    switch (e) {
      case EstadosTrabajo.asignado: // negociación
        if (esTrab) {
          w.add(_infoBanner('Acuerden el pago y el tiempo en el chat.'));
          w.add(const SizedBox(height: 4));
          w.add(_botonCancelar(context, pub, false));
        } else {
          w.add(ElevatedButton.icon(
            onPressed: () => _reservarPago(context, pub),
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Confirmar acuerdo y depositar pago'),
          ));
          w.add(const SizedBox(height: 4));
          w.add(_botonCancelar(context, pub, true));
        }
        break;
      case EstadosTrabajo.acordado: // contrato, pendiente de iniciar
        if (esTrab) {
          w.add(ElevatedButton.icon(
            onPressed: () => _accion(() => _pubService.iniciarTrabajo(pub.id),
                exito: '¡Trabajo iniciado!'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Iniciar trabajo'),
          ));
        } else {
          w.add(_infoBanner('Contrato creado. Esperando que el trabajador inicie.',
              color: AppColores.verde));
          w.add(const SizedBox(height: 4));
          w.add(_botonCancelar(context, pub, true));
        }
        break;
      case EstadosTrabajo.enProgreso:
        if (esTrab) {
          // El servidor rechaza la entrega sin evidencias (ADR-0007). Se dice
          // aquí, con el botón desactivado, en vez de dejar que lo descubra
          // con un error después de pulsarlo.
          final hayAvance = _evidencias.any((ev) => ev.autorUid == usuario.uid);
          w.add(ElevatedButton.icon(
            onPressed: hayAvance
                ? () => _accion(() => _pubService.marcarTerminado(pub.id),
                    exito: 'Marcado como terminado')
                : null,
            icon: const Icon(Icons.done_all_rounded),
            label: const Text('Marcar como terminado'),
          ));
          if (!hayAvance) {
            w.add(const SizedBox(height: 8));
            w.add(_infoBanner(
                'Agrega al menos un avance antes de entregar: es lo que el '
                'contratista va a revisar.',
                color: AppColores.advertencia));
          }
        } else {
          w.add(_infoBanner('En progreso. El trabajador está realizando el trabajo.'));
        }
        // Ya iniciado, nadie cancela (409). Lo que sí puede cualquiera de las
        // dos partes es reclamar a soporte.
        w.add(const SizedBox(height: 4));
        w.add(_botonReclamar(context, pub));
        break;
      case EstadosTrabajo.esperandoConfirmacion:
        if (esDueno) {
          w.add(ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColores.verde),
            onPressed: () => _accion(() => _pubService.aceptarTrabajo(pub.id),
                exito: '¡Trabajo completado y pago liberado!'),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text('Aceptar y pagar L. ${pub.montoAcordado.toStringAsFixed(0)}'),
          ));
          w.add(const SizedBox(height: 8));
          w.add(OutlinedButton.icon(
            onPressed: () => _solicitarCorreccion(context, pub),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Solicitar correcciones'),
          ));
        } else {
          w.add(_infoBanner('Terminado. Esperando la confirmación del contratista.'));
        }
        w.add(const SizedBox(height: 8));
        w.add(_botonReclamar(context, pub));
        break;
      case EstadosTrabajo.enDisputa:
        // El dinero está congelado y solo soporte puede moverlo. No hay
        // ninguna acción que ofrecer aquí: ofrecer alguna sería mentir.
        w.add(_infoBanner(
            'Soporte está revisando este trabajo. El pago queda retenido '
            'hasta que resuelvan; te avisaremos.',
            color: AppColores.advertencia));
        break;
      case EstadosTrabajo.completado:
        w.add(_calificarSegunRol(context, pub, esDueno));
        break;
      case EstadosTrabajo.finalizado:
        final hecho =
            esDueno ? pub.calificadoPorEmpleador : pub.calificadoPorTrabajador;
        if (!hecho) {
          w.add(_calificarSegunRol(context, pub, esDueno));
        } else {
          w.add(_infoBanner('Trabajo finalizado. ¡Gracias por usar Trabajito!',
              color: AppColores.verde));
        }
        break;
      default:
        break;
    }
    return w;
  }

  Widget _botonPostular(BuildContext context, Publicacion pub) {
    final mia = _miPostulacion;
    if (mia != null) {
      // También cuando está retirada: la restricción única de la BD no mira el
      // estado, así que un segundo intento respondería 409 igual. El texto
      // cambia para no dar a entender que sigue en pie.
      final retirada = mia.estado == EstadosPostulacion.retirada;
      return ElevatedButton.icon(
        onPressed: null,
        icon: Icon(retirada ? Icons.block_rounded : Icons.check_rounded),
        label: Text(retirada
            ? 'Retiraste tu postulación'
            : 'Ya te postulaste'),
      );
    }
    return ElevatedButton.icon(
      onPressed: () async {
        final ok = await mostrarPostularseSheet(context,
            publicacion: pub, usuario: usuario);
        if (ok == true && mounted) {
          mostrarSnackBar(this.context, '¡Postulación enviada!');
          await _cargar();
        }
      },
      icon: const Icon(Icons.send_rounded),
      label: const Text('Postularme'),
    );
  }

  Widget _calificarSegunRol(BuildContext context, Publicacion pub, bool esDueno) {
    return _botonCalificar(
      context, pub,
      hecho: esDueno ? pub.calificadoPorEmpleador : pub.calificadoPorTrabajador,
      paraUid: esDueno ? pub.uidTrabajadorAsignado : pub.uidEmpleador,
      paraNombre: esDueno ? pub.nombreTrabajadorAsignado : pub.autor,
      etiqueta: esDueno ? 'Calificar al trabajador' : 'Calificar al contratador',
    );
  }

  Future<void> _solicitarCorreccion(BuildContext context, Publicacion pub) async {
    final ctrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Solicitar correcciones',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: '¿Qué falta o hay que corregir?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (motivo == null || motivo.isEmpty || !mounted) return;
    await _accion(() => _pubService.solicitarCorreccion(pub.id, motivo),
        exito: 'Correcciones solicitadas');
  }

  /// Reclamo a soporte: la única salida de un trabajo ya iniciado que no acaba
  /// de común acuerdo (ADR-0007).
  ///
  /// Antes este botón solo enseñaba "próximamente" y no mandaba nada. Ahora es
  /// de verdad, y hace falta que lo sea: al migrar, cancelar dejó de estar
  /// permitido desde `en_progreso`, así que sin esto las dos partes se
  /// quedarían sin ninguna salida.
  Future<void> _reclamarProblema(BuildContext context, Publicacion pub) async {
    final motivoCtrl = TextEditingController();
    final detalleCtrl = TextEditingController();
    final enviar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reportar un problema',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'El pago quedará retenido hasta que soporte revise el caso. '
              'Ni tú ni la otra parte podrán moverlo mientras tanto.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Motivo *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: detalleCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Cuéntanos qué pasó'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColores.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    final motivo = motivoCtrl.text.trim();
    final descripcion = detalleCtrl.text.trim();
    motivoCtrl.dispose();
    detalleCtrl.dispose();
    if (enviar != true || !mounted) return;
    if (motivo.isEmpty) {
      // El backend responde 400 sin motivo; se ahorra el viaje.
      mostrarSnackBar(this.context, 'Explica el motivo del reclamo', esError: true);
      return;
    }
    await _accion(
        () => _pubService.reclamarProblema(
              idPublicacion: pub.id,
              motivo: motivo,
              descripcion: descripcion,
            ),
        exito: 'Reclamo enviado. Soporte revisará el caso.');
  }

  Widget _botonReclamar(BuildContext context, Publicacion pub) {
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: AppColores.error),
      onPressed: () => _reclamarProblema(context, pub),
      icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18),
      label: const Text('Reportar problema a soporte'),
    );
  }

  Widget _botonCalificar(
    BuildContext context,
    Publicacion pub, {
    required bool hecho,
    required String paraUid,
    required String paraNombre,
    required String etiqueta,
  }) {
    if (hecho) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.star_rounded),
        label: const Text('Ya calificaste'),
      );
    }
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: AppColores.dorado),
      onPressed: () async {
        final ok = await mostrarCalificarSheet(context,
            publicacion: pub,
            calificador: usuario,
            paraUid: paraUid,
            paraNombre: paraNombre);
        if (ok == true && context.mounted) {
          mostrarSnackBar(context, '¡Gracias por tu calificación!');
        }
      },
      icon: const Icon(Icons.star_outline_rounded),
      label: Text(etiqueta),
    );
  }

  Future<void> _reservarPago(BuildContext context, Publicacion pub) async {
    // El acuerdo (monto y tiempo) sigue viviendo en el chat de Firestore: ese
    // servicio se migra en la tarea siguiente. Cuando lo esté, esta lectura
    // pasará a `/api/chats/**` y el resto no cambia.
    await _accion(() async {
      final chat = await ChatService().obtenerChat(pub.id);
      if (chat == null || !chat.pagoAcordado || chat.pagoMonto <= 0) {
        return 'Primero acuerden el pago en el chat antes de depositarlo.';
      }
      if (!chat.tiempoAcordado || chat.tiempoValor.isEmpty) {
        return 'Primero acuerden el tiempo en el chat antes de depositar.';
      }
      return _pubService.reservarPago(
        idPublicacion: pub.id,
        uidEmpleador: usuario.uid,
        monto: chat.pagoMonto,
        tiempo: chat.tiempoValor,
      );
    }, exito: 'Pago depositado en garantía');
  }

  /// Cancelar obliga a **elegir el destino del trabajo**: el backend exige
  /// `reabrir` y sin él responde 400. No hay valor por defecto razonable —
  /// volver a publicarlo y cerrarlo son decisiones distintas—, así que se
  /// pregunta con dos botones en vez de un "¿seguro?".
  Future<void> _cancelarContratacion(BuildContext context, Publicacion pub) async {
    final hayEscrow = pub.pagoRetenido;
    final reabrir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Qué hacemos con el trabajo?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Se cancela la contratación de ${pub.nombreTrabajadorAsignado}.'
          '${hayEscrow ? '\n\nEl pago en garantía se te reembolsa entero.' : ''}'
          '\n\nElige qué pasa después:',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mejor no')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColores.error),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cerrarlo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Volver a publicarlo'),
          ),
        ],
      ),
    );
    if (reabrir == null || !mounted) return;
    await _accion(
        () => _pubService.cancelarContratacion(
              idPublicacion: pub.id,
              reabrir: reabrir,
            ),
        exito: reabrir
            ? 'Contratación cancelada. El trabajo vuelve al feed.'
            : 'Contratación cancelada y trabajo cerrado.');
  }

  Future<void> _rechazarTrabajo(BuildContext context, Publicacion pub) async {
    final ok = await _confirmar(context, '¿Rechazar este trabajo?',
        'El trabajo volverá a estar disponible para otros trabajadores.');
    if (ok != true || !mounted) return;
    await _accion(
        () => _pubService.rechazarAsignacion(idPublicacion: pub.id),
        exito: 'Rechazaste el trabajo');
  }

  Future<bool?> _confirmar(
      BuildContext context, String titulo, String mensaje) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(mensaje),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColores.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
  }

  Widget _botonCancelar(BuildContext context, Publicacion pub, bool esDueno) {
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: AppColores.error),
      onPressed: () => esDueno
          ? _cancelarContratacion(context, pub)
          : _rechazarTrabajo(context, pub),
      icon: const Icon(Icons.cancel_outlined, size: 18),
      label: Text(esDueno ? 'Cancelar contratación' : 'Rechazar trabajo'),
    );
  }

  Widget _infoBanner(String texto, {Color color = AppColores.azulProfesional}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
              color == AppColores.verde
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: color,
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _botonChat(BuildContext context, Publicacion pub) {
    return OutlinedButton.icon(
      onPressed: () {
        final chat = Chat(
          id: pub.id,
          idPublicacion: pub.id,
          tituloPublicacion: pub.titulo,
          uidEmpleador: pub.uidEmpleador,
          nombreEmpleador: pub.autor,
          uidTrabajador: pub.uidTrabajadorAsignado,
          nombreTrabajador: pub.nombreTrabajadorAsignado,
          participantes: [pub.uidEmpleador, pub.uidTrabajadorAsignado],
          fechaUltimoMensaje: DateTime.now(),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatScreen(chat: chat, usuario: usuario)),
        );
      },
      icon: const Icon(Icons.forum_outlined),
      label: const Text('Abrir chat'),
    );
  }

  Widget _chip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _badgeEstado(String estado) {
    Color color;
    switch (estado) {
      case EstadosTrabajo.activo:
        color = AppColores.verde; break;
      case EstadosTrabajo.asignado:
      case EstadosTrabajo.acordado:
        color = AppColores.azulProfesional; break;
      case EstadosTrabajo.enProgreso:
      case EstadosTrabajo.esperandoConfirmacion:
        color = AppColores.dorado; break;
      case EstadosTrabajo.completado:
      case EstadosTrabajo.finalizado:
        color = AppColores.verde; break;
      default:
        color = AppColores.grisMedio;
    }
    final texto = EstadosTrabajo.etiqueta(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _fila(BuildContext context, IconData icono, String titulo, String valor) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, color: AppColores.azulProfesional, size: 20),
          const SizedBox(width: 12),
          Text(titulo,
              style: TextStyle(
                  color: textoSec, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(valor,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: textoPrincipal,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de contrato (resumen del acuerdo) ─────────────
  Widget _tarjetaContrato(BuildContext context, Publicacion pub) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;

    Widget linea(IconData ic, String etiqueta, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(ic, size: 16, color: AppColores.azulProfesional),
              const SizedBox(width: 8),
              Text(etiqueta,
                  style: TextStyle(
                      color: textoSec, fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              Flexible(
                child: Text(valor,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: textoPrincipal,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

    final fecha = pub.fechaInicio ?? pub.fechaAcuerdo;
    final fechaTxt = fecha == null
        ? '—'
        : '${fecha.day.toString().padLeft(2, '0')}/'
            '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColores.azulProfesional.withValues(alpha: 0.10),
            AppColores.verde.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColores.azulProfesional.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: AppColores.azulProfesional, size: 20),
              const SizedBox(width: 8),
              Text('Contrato',
                  style: TextStyle(
                      color: textoPrincipal,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColores.azulProfesional.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(EstadosTrabajo.etiqueta(pub.estado),
                    style: const TextStyle(
                        color: AppColores.azulProfesional,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          linea(Icons.payments_rounded, 'Pago acordado',
              'L. ${pub.montoAcordado.toStringAsFixed(0)} / hora'),
          linea(Icons.schedule_rounded, 'Tiempo acordado',
              pub.tiempoAcordado.isEmpty ? '—' : pub.tiempoAcordado),
          linea(Icons.person_outline_rounded, 'Trabajador',
              pub.nombreTrabajadorAsignado.isEmpty
                  ? '—'
                  : pub.nombreTrabajadorAsignado),
          linea(Icons.business_center_outlined, 'Contratista',
              pub.autor.isEmpty ? '—' : pub.autor),
          linea(
              pub.fechaInicio != null
                  ? Icons.play_circle_outline_rounded
                  : Icons.event_available_outlined,
              pub.fechaInicio != null ? 'Iniciado' : 'Acordado',
              fechaTxt),
          if (pub.pagoRetenido && !pub.pagoLiberado) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 14, color: AppColores.verde),
                const SizedBox(width: 6),
                Text('Pago en garantía',
                    style: TextStyle(
                        color: AppColores.verde,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Sección de evidencias / avances ───────────────────────
  Widget _seccionEvidencias(BuildContext context, Publicacion pub,
      {required bool puedeAgregar}) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline_rounded,
                color: AppColores.azulProfesional, size: 18),
            const SizedBox(width: 8),
            Text('Avances del trabajo',
                style: TextStyle(
                    color: textoPrincipal,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        Builder(
          builder: (context) {
            final lista = _evidencias;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lista.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: superficie,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borde),
                    ),
                    child: Text(
                      'Aún no hay avances registrados.',
                      style: TextStyle(color: textoSec, fontSize: 13),
                    ),
                  )
                else
                  ...lista.map((e) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: superficie,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borde),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor:
                                      AppColores.azulProfesional.withValues(alpha: 0.15),
                                  child: Text(
                                    e.autorNombre.isNotEmpty
                                        ? e.autorNombre[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppColores.azulProfesional,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  e.autorNombre.isEmpty ? 'Trabajador' : e.autorNombre,
                                  style: TextStyle(
                                      color: textoPrincipal,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                Text(e.tiempoRelativo,
                                    style: TextStyle(
                                        color: textoSec, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(e.texto,
                                style: TextStyle(
                                    color: textoSec,
                                    fontSize: 13,
                                    height: 1.4)),
                          ],
                        ),
                      )),
                if (puedeAgregar) ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => _agregarEvidencia(context, pub),
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text('Agregar avance'),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _agregarEvidencia(BuildContext context, Publicacion pub) async {
    final ctrl = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Agregar avance',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Describe el avance realizado'),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Adjuntar fotos y videos estará disponible pronto.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    if (texto == null || texto.isEmpty || !mounted) return;
    await _accion(
      () => _pubService.agregarEvidencia(
        pub.id,
        Evidencia(
          texto: texto,
          autorUid: usuario.uid,
          autorNombre: usuario.nombreVisible,
          fecha: DateTime.now(),
        ),
      ),
      exito: 'Avance publicado',
    );
  }
}
