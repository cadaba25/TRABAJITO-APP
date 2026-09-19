import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/evidencia.dart';
import '../../../compartido/modelos/postulacion.dart';
import '../../../compartido/modelos/publicacion.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../../nucleo/api/api_excepciones.dart';
import '../../chat/datos/chat.dart';
import '../../chat/datos/chat_service.dart';
import '../../postulaciones/datos/postulacion_service.dart';
import '../datos/publicacion_service.dart';
import '../../../nucleo/dominio/estados.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import '../../../compartido/widgets/boton_primario.dart';
import '../../../compartido/widgets/boton_secundario.dart';
import '../../../compartido/widgets/boton_texto.dart';
import '../../../compartido/widgets/ejecutar_con_carga.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../calificaciones/pantallas/calificar_sheet.dart';
import '../../chat/pantallas/chat_screen.dart';
import 'editar_trabajo_screen.dart';
import '../../postulaciones/pantallas/postularse_sheet.dart';
import '../../postulaciones/pantallas/postulantes_screen.dart';
import 'widgets/dialogo_agregar_evidencia.dart';
import 'widgets/dialogo_cancelar_contratacion.dart';
import 'widgets/dialogo_confirmacion.dart';
import 'widgets/dialogo_reclamar_problema.dart';
import 'widgets/dialogo_solicitar_correccion.dart';

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
///
/// ## Sobre el tamaño (ADR-0014 / ADR-0016, techo de 300 líneas)
///
/// Este archivo sigue **por encima del techo, a propósito** — excepción viva
/// documentada en el reporte de la tarea 035, igual que `gestor_sesion.dart`
/// y `publicacion_service.dart`. La tarea 035 aplicó los tokens de
/// tipografía/espaciado (ADR-0016) y sacó los cinco `AlertDialog` inline a
/// `pantallas/widgets/` (bajó de 1150 a bastante menos), pero **no partió la
/// máquina de estados de `_acciones()`**. La tarea 053 migró `_reservarPago`
/// y el botón de chat a la API REST pero tampoco la partió: sigue pendiente.
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
  late final _pubService = context.read<PublicacionService>();
  late final _postService = context.read<PostulacionService>();
  late final _chatService = context.read<ChatService>();

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
      final trabajo = await _pubService.recargarPublicacion(
        widget.publicacion.id,
      );
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
  Future<void> _accion(
    Future<String?> Function() accion, {
    required String exito,
  }) async {
    final ok = await ejecutarConCarga(context, accion, exito: exito);
    if (ok && mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) => _contenido(context, _pub);

  bool _esDueno(Publicacion pub) => usuario.uid == pub.uidEmpleador;
  bool _esAsignado(Publicacion pub) => usuario.uid == pub.uidTrabajadorAsignado;

  Widget _contenido(BuildContext context, Publicacion pub) {
    final tt = Theme.of(context).textTheme;
    final textoPrincipal = colorTextoFuerte(context);
    final textoSec = colorTextoSuave(context);
    final superficie = colorSuperficie(context);
    final borde = colorBorde(context);

    return Scaffold(
      appBar: AppBar(title: Text('Detalle del trabajo', style: tt.titulo)),
      body: RefreshIndicator(
        color: AppColores.acento,
        onRefresh: _cargar,
        child: SingleChildScrollView(
          // Deslizar para actualizar tiene que funcionar aunque el detalle
          // quepa entero en la pantalla.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppEspaciado.lg,
            AppEspaciado.lg,
            AppEspaciado.lg,
            AppEspaciado.xl,
          ),
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
                      // Contraste: dorado como texto sobre el fondo casi
                      // blanco del avatar (ADR-0016, tarea 051 — hallazgo
                      // nuevo del tech-lead, mismo patrón que tarjeta_trabajo).
                      style: tt.cuerpoChico.copyWith(
                        color: colorAcentoTexto(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppEspaciado.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pub.autor.isEmpty ? 'Anónimo' : pub.autor,
                          style: tt.cuerpo.copyWith(
                            color: textoPrincipal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          pub.tiempoRelativo,
                          style: tt.etiqueta.copyWith(color: textoSec),
                        ),
                      ],
                    ),
                  ),
                  _badgeEstado(context, pub.estado),
                ],
              ),
              const SizedBox(height: AppEspaciado.lg),
              Wrap(
                spacing: AppEspaciado.sm,
                runSpacing: AppEspaciado.sm,
                children: [
                  if (pub.categoria.isNotEmpty)
                    // El fondo del chip se queda dorado (tinte con alpha); el
                    // texto necesita `colorAcentoTexto` (tarea 051).
                    _chip(context, pub.categoria, AppColores.acento,
                        colorTexto: colorAcentoTexto(context)),
                  if (pub.plazo.isNotEmpty)
                    _chip(context, pub.plazo, AppColores.azulProfesional),
                ],
              ),
              const SizedBox(height: AppEspaciado.md),
              Text(
                pub.titulo,
                style: tt.titulo.copyWith(color: textoPrincipal),
              ),
              const SizedBox(height: AppEspaciado.lg),
              Container(
                decoration: BoxDecoration(
                  color: superficie,
                  borderRadius: BorderRadius.circular(AppRadios.tarjeta),
                  border: Border.all(color: borde, width: 1),
                ),
                child: Column(
                  children: [
                    _fila(
                      context,
                      Icons.location_on_outlined,
                      'Ubicación',
                      pub.ubicacionDetallada.isEmpty
                          ? 'Honduras'
                          : pub.ubicacionDetallada,
                    ),
                    Divider(
                      height: 1,
                      color: borde,
                      indent: AppEspaciado.lg,
                      endIndent: AppEspaciado.lg,
                    ),
                    _fila(
                      context,
                      Icons.payments_outlined,
                      'Presupuesto',
                      pub.presupuesto.isEmpty ? 'A convenir' : pub.presupuesto,
                    ),
                    if (pub.uidTrabajadorAsignado.isNotEmpty) ...[
                      Divider(
                        height: 1,
                        color: borde,
                        indent: AppEspaciado.lg,
                        endIndent: AppEspaciado.lg,
                      ),
                      _fila(
                        context,
                        Icons.assignment_ind_outlined,
                        'Asignado a',
                        pub.nombreTrabajadorAsignado,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppEspaciado.xl),
              Text(
                'Descripción',
                style: tt.subtitulo.copyWith(color: textoPrincipal),
              ),
              const SizedBox(height: AppEspaciado.sm),
              Text(
                pub.descripcion.isEmpty ? 'Sin descripción.' : pub.descripcion,
                style: tt.cuerpo.copyWith(color: textoSec),
              ),
              const SizedBox(height: AppEspaciado.xxl),
              ..._acciones(context, pub),
              const SizedBox(height: AppEspaciado.xl),
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
          const BotonPrimario(
            texto: 'Este trabajo ya no está disponible',
            onPressed: null,
          ),
        ];
      }
      return [_botonPostular(context, pub)];
    }

    // ── Dueño con trabajo aún abierto ──
    if (esDueno && e == EstadosTrabajo.activo) {
      return [
        BotonSecundario(
          texto: 'Ver postulantes',
          icono: Icons.people_outline_rounded,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostulantesScreen(publicacion: pub),
            ),
          ),
        ),
        const SizedBox(height: AppEspaciado.md),
        BotonSecundario(
          texto: 'Editar trabajo',
          icono: Icons.edit_outlined,
          onPressed: () async {
            final guardado = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => EditarTrabajoScreen(publicacion: pub),
              ),
            );
            if (guardado == true && mounted) await _cargar();
          },
        ),
      ];
    }
    if (pub.uidTrabajadorAsignado.isEmpty) return [];

    final w = <Widget>[];

    // Contrato (desde 'acordado' en adelante)
    const conContrato = [
      EstadosTrabajo.acordado,
      EstadosTrabajo.enProgreso,
      EstadosTrabajo.esperandoConfirmacion,
      EstadosTrabajo.completado,
      EstadosTrabajo.finalizado,
    ];
    if (conContrato.contains(e)) {
      w.add(_tarjetaContrato(context, pub));
      w.add(const SizedBox(height: AppEspaciado.lg));
    }

    // Chat
    w.add(_botonChat(context, pub));

    // Aviso de corrección solicitada (para el trabajador)
    if (pub.correccionSolicitada && e == EstadosTrabajo.enProgreso && esTrab) {
      w.add(const SizedBox(height: AppEspaciado.md));
      w.add(
        _infoBanner(
          context,
          'Correcciones solicitadas: ${pub.motivoCorreccion}',
          color: AppColores.advertencia,
        ),
      );
    }

    // Evidencias / avances
    if ([
      EstadosTrabajo.enProgreso,
      EstadosTrabajo.esperandoConfirmacion,
      EstadosTrabajo.enDisputa,
      EstadosTrabajo.completado,
      EstadosTrabajo.finalizado,
    ].contains(e)) {
      w.add(const SizedBox(height: AppEspaciado.lg));
      w.add(
        _seccionEvidencias(
          context,
          pub,
          puedeAgregar: esTrab && e == EstadosTrabajo.enProgreso,
        ),
      );
    }

    w.add(const SizedBox(height: AppEspaciado.lg));

    switch (e) {
      case EstadosTrabajo.asignado: // negociación
        if (esTrab) {
          w.add(
            _infoBanner(context, 'Acuerden el pago y el tiempo en el chat.'),
          );
          w.add(const SizedBox(height: AppEspaciado.xs));
          w.add(_botonCancelar(context, pub, false));
        } else {
          w.add(
            BotonPrimario(
              texto: 'Confirmar acuerdo y depositar pago',
              icono: Icons.handshake_outlined,
              onPressed: () => _reservarPago(context, pub),
            ),
          );
          w.add(const SizedBox(height: AppEspaciado.xs));
          w.add(_botonCancelar(context, pub, true));
        }
        break;
      case EstadosTrabajo.acordado: // contrato, pendiente de iniciar
        if (esTrab) {
          w.add(
            BotonPrimario(
              texto: 'Iniciar trabajo',
              icono: Icons.play_arrow_rounded,
              onPressed: () => _accion(
                () => _pubService.iniciarTrabajo(pub.id),
                exito: '¡Trabajo iniciado!',
              ),
            ),
          );
        } else {
          w.add(
            _infoBanner(
              context,
              'Contrato creado. Esperando que el trabajador inicie.',
              color: AppColores.verde,
            ),
          );
          w.add(const SizedBox(height: AppEspaciado.xs));
          w.add(_botonCancelar(context, pub, true));
        }
        break;
      case EstadosTrabajo.enProgreso:
        if (esTrab) {
          // El servidor rechaza la entrega sin evidencias (ADR-0007). Se dice
          // aquí, con el botón desactivado, en vez de dejar que lo descubra
          // con un error después de pulsarlo.
          final hayAvance = _evidencias.any((ev) => ev.autorUid == usuario.uid);
          w.add(
            BotonPrimario(
              texto: 'Marcar como terminado',
              icono: Icons.done_all_rounded,
              onPressed: hayAvance
                  ? () => _accion(
                      () => _pubService.marcarTerminado(pub.id),
                      exito: 'Marcado como terminado',
                    )
                  : null,
            ),
          );
          if (!hayAvance) {
            w.add(const SizedBox(height: AppEspaciado.sm));
            w.add(
              _infoBanner(
                context,
                'Agrega al menos un avance antes de entregar: es lo que el '
                'contratista va a revisar.',
                color: AppColores.advertencia,
              ),
            );
          }
        } else {
          w.add(
            _infoBanner(
              context,
              'En progreso. El trabajador está realizando el trabajo.',
            ),
          );
        }
        // Ya iniciado, nadie cancela (409). Lo que sí puede cualquiera de las
        // dos partes es reclamar a soporte.
        w.add(const SizedBox(height: AppEspaciado.xs));
        w.add(_botonReclamar(context, pub));
        break;
      case EstadosTrabajo.esperandoConfirmacion:
        if (esDueno) {
          w.add(
            BotonPrimario(
              texto:
                  'Aceptar y pagar L. ${pub.montoAcordado.toStringAsFixed(0)}',
              icono: Icons.check_circle_outline_rounded,
              color: AppColores.verde,
              onPressed: () => _accion(
                () => _pubService.aceptarTrabajo(pub.id),
                exito: '¡Trabajo completado y pago liberado!',
              ),
            ),
          );
          w.add(const SizedBox(height: AppEspaciado.sm));
          w.add(
            BotonSecundario(
              texto: 'Solicitar correcciones',
              icono: Icons.edit_note_rounded,
              onPressed: () => _solicitarCorreccion(context, pub),
            ),
          );
        } else {
          w.add(
            _infoBanner(
              context,
              'Terminado. Esperando la confirmación del contratista.',
            ),
          );
        }
        w.add(const SizedBox(height: AppEspaciado.sm));
        w.add(_botonReclamar(context, pub));
        break;
      case EstadosTrabajo.enDisputa:
        // El dinero está congelado y solo soporte puede moverlo. No hay
        // ninguna acción que ofrecer aquí: ofrecer alguna sería mentir.
        w.add(
          _infoBanner(
            context,
            'Soporte está revisando este trabajo. El pago queda retenido '
            'hasta que resuelvan; te avisaremos.',
            color: AppColores.advertencia,
          ),
        );
        break;
      case EstadosTrabajo.completado:
        w.add(_calificarSegunRol(context, pub, esDueno));
        break;
      case EstadosTrabajo.finalizado:
        final hecho = esDueno
            ? pub.calificadoPorEmpleador
            : pub.calificadoPorTrabajador;
        if (!hecho) {
          w.add(_calificarSegunRol(context, pub, esDueno));
        } else {
          w.add(
            _infoBanner(
              context,
              'Trabajo finalizado. ¡Gracias por usar Trabajito!',
              color: AppColores.verde,
            ),
          );
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
      return BotonPrimario(
        texto: retirada ? 'Retiraste tu postulación' : 'Ya te postulaste',
        icono: retirada ? Icons.block_rounded : Icons.check_rounded,
        onPressed: null,
      );
    }
    return BotonPrimario(
      texto: 'Postularme',
      icono: Icons.send_rounded,
      onPressed: () async {
        final ok = await mostrarPostularseSheet(
          context,
          publicacion: pub,
          usuario: usuario,
        );
        if (ok == true && mounted) {
          mostrarSnackBar(this.context, '¡Postulación enviada!');
          await _cargar();
        }
      },
    );
  }

  Widget _calificarSegunRol(
    BuildContext context,
    Publicacion pub,
    bool esDueno,
  ) {
    return _botonCalificar(
      context,
      pub,
      hecho: esDueno ? pub.calificadoPorEmpleador : pub.calificadoPorTrabajador,
      paraUid: esDueno ? pub.uidTrabajadorAsignado : pub.uidEmpleador,
      paraNombre: esDueno ? pub.nombreTrabajadorAsignado : pub.autor,
      etiqueta: esDueno
          ? 'Calificar al trabajador'
          : 'Calificar al contratador',
    );
  }

  Future<void> _solicitarCorreccion(
    BuildContext context,
    Publicacion pub,
  ) async {
    final motivo = await mostrarDialogoSolicitarCorreccion(context);
    if (motivo == null || motivo.isEmpty || !mounted) return;
    await _accion(
      () => _pubService.solicitarCorreccion(pub.id, motivo),
      exito: 'Correcciones solicitadas',
    );
  }

  /// Reclamo a soporte: la única salida de un trabajo ya iniciado que no acaba
  /// de común acuerdo (ADR-0007).
  ///
  /// Antes este botón solo enseñaba "próximamente" y no mandaba nada. Ahora es
  /// de verdad, y hace falta que lo sea: al migrar, cancelar dejó de estar
  /// permitido desde `en_progreso`, así que sin esto las dos partes se
  /// quedarían sin ninguna salida.
  Future<void> _reclamarProblema(BuildContext context, Publicacion pub) async {
    final resultado = await mostrarDialogoReclamarProblema(context);
    if (resultado == null || !mounted) return;
    final (motivo, descripcion) = resultado;
    if (motivo.isEmpty) {
      // El backend responde 400 sin motivo; se ahorra el viaje.
      mostrarSnackBar(
        this.context,
        'Explica el motivo del reclamo',
        esError: true,
      );
      return;
    }
    await _accion(
      () => _pubService.reclamarProblema(
        idPublicacion: pub.id,
        motivo: motivo,
        descripcion: descripcion,
      ),
      exito: 'Reclamo enviado. Soporte revisará el caso.',
    );
  }

  Widget _botonReclamar(BuildContext context, Publicacion pub) {
    return BotonTexto(
      texto: 'Reportar problema a soporte',
      icono: Icons.report_gmailerrorred_rounded,
      color: AppColores.error,
      onPressed: () => _reclamarProblema(context, pub),
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
      return const BotonPrimario(
        texto: 'Ya calificaste',
        icono: Icons.star_rounded,
        onPressed: null,
      );
    }
    return BotonPrimario(
      texto: etiqueta,
      icono: Icons.star_outline_rounded,
      color: AppColores.dorado,
      onPressed: () async {
        final ok = await mostrarCalificarSheet(
          context,
          publicacion: pub,
          calificador: usuario,
          paraUid: paraUid,
          paraNombre: paraNombre,
        );
        if (ok == true && context.mounted) {
          mostrarSnackBar(context, '¡Gracias por tu calificación!');
        }
      },
    );
  }

  Future<void> _reservarPago(BuildContext context, Publicacion pub) async {
    // El acuerdo (monto y tiempo) sale del chat REST. OJO: el backend NO lo
    // valida (`reservar-pago` usa lo que le mandemos; reporte 054, brecha 1),
    // así que esta comprobación del cliente es la única barrera hasta la
    // tarea 055.
    await _accion(() async {
      final Chat? chat;
      try {
        chat = await _chatService.chatDeTrabajo(pub.id);
      } on ExcepcionApi catch (e) {
        return e.mensaje;
      }
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
  Future<void> _cancelarContratacion(
    BuildContext context,
    Publicacion pub,
  ) async {
    final reabrir = await mostrarDialogoCancelarContratacion(
      context,
      nombreTrabajador: pub.nombreTrabajadorAsignado,
      hayEscrow: pub.pagoRetenido,
    );
    if (reabrir == null || !mounted) return;
    await _accion(
      () => _pubService.cancelarContratacion(
        idPublicacion: pub.id,
        reabrir: reabrir,
      ),
      exito: reabrir
          ? 'Contratación cancelada. El trabajo vuelve al feed.'
          : 'Contratación cancelada y trabajo cerrado.',
    );
  }

  Future<void> _rechazarTrabajo(BuildContext context, Publicacion pub) async {
    final ok = await mostrarDialogoConfirmacion(
      context,
      titulo: '¿Rechazar este trabajo?',
      mensaje: 'El trabajo volverá a estar disponible para otros trabajadores.',
    );
    if (ok != true || !mounted) return;
    await _accion(
      () => _pubService.rechazarAsignacion(idPublicacion: pub.id),
      exito: 'Rechazaste el trabajo',
    );
  }

  Widget _botonCancelar(BuildContext context, Publicacion pub, bool esDueno) {
    return BotonTexto(
      texto: esDueno ? 'Cancelar contratación' : 'Rechazar trabajo',
      icono: Icons.cancel_outlined,
      color: AppColores.error,
      onPressed: () => esDueno
          ? _cancelarContratacion(context, pub)
          : _rechazarTrabajo(context, pub),
    );
  }

  Widget _infoBanner(
    BuildContext context,
    String texto, {
    Color color = AppColores.azulProfesional,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadios.campo),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            color == AppColores.verde
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.cuerpo.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonChat(BuildContext context, Publicacion pub) {
    return BotonSecundario(
      texto: 'Abrir chat',
      icono: Icons.forum_outlined,
      onPressed: () async {
        // El id del chat es un UUID propio: se resuelve por el del trabajo.
        final Chat? chat;
        try {
          chat = await _chatService.chatDeTrabajo(pub.id);
        } on ExcepcionApi catch (e) {
          if (context.mounted) mostrarSnackBar(context, e.mensaje, esError: true);
          return;
        }
        if (!context.mounted) return;
        if (chat == null) {
          mostrarSnackBar(context, 'El chat de este trabajo aún no está disponible.',
              esError: true);
          return;
        }
        final abierto = chat;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chat: abierto, usuario: usuario),
          ),
        );
      },
    );
  }

  // `colorTexto` distinto de `color` solo hace falta para el caso dorado: el
  // fondo se queda con el tinte de marca, pero el texto necesita el tono
  // corregido para el contraste (tarea 051).
  Widget _chip(BuildContext context, String texto, Color color, {Color? colorTexto}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppEspaciado.md,
        vertical: AppEspaciado.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadios.chip),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.etiqueta.copyWith(
          color: colorTexto ?? color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _badgeEstado(BuildContext context, String estado) {
    Color color;
    switch (estado) {
      case EstadosTrabajo.activo:
        color = AppColores.verde;
        break;
      case EstadosTrabajo.asignado:
      case EstadosTrabajo.acordado:
        color = AppColores.azulProfesional;
        break;
      case EstadosTrabajo.enProgreso:
      case EstadosTrabajo.esperandoConfirmacion:
        color = AppColores.acento;
        break;
      case EstadosTrabajo.completado:
      case EstadosTrabajo.finalizado:
        color = AppColores.verde;
        break;
      default:
        color = AppColores.grisMedio;
    }
    final texto = EstadosTrabajo.etiqueta(estado);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppEspaciado.md,
        vertical: AppEspaciado.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadios.chip),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.etiqueta.copyWith(
          // Dorado como texto: tono WCAG-seguro (ADR-0016, tarea 055).
          color: color == AppColores.acento ? colorAcentoTexto(context) : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _fila(
    BuildContext context,
    IconData icono,
    String titulo,
    String valor,
  ) {
    final textoPrincipal = colorTextoFuerte(context);
    final textoSec = colorTextoSuave(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppEspaciado.lg,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColores.azulProfesional, size: 20),
          const SizedBox(width: AppEspaciado.md),
          Text(titulo, style: tt.cuerpoChico.copyWith(color: textoSec)),
          const Spacer(),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: tt.cuerpoChico.copyWith(
                color: textoPrincipal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de contrato (resumen del acuerdo) ─────────────
  Widget _tarjetaContrato(BuildContext context, Publicacion pub) {
    final textoPrincipal = colorTextoFuerte(context);
    final textoSec = colorTextoSuave(context);
    final tt = Theme.of(context).textTheme;

    Widget linea(IconData ic, String etiqueta, String valor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppEspaciado.xs),
      child: Row(
        children: [
          Icon(ic, size: 16, color: AppColores.azulProfesional),
          const SizedBox(width: AppEspaciado.sm),
          Text(etiqueta, style: tt.cuerpoChico.copyWith(color: textoSec)),
          const Spacer(),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: tt.cuerpoChico.copyWith(
                color: textoPrincipal,
                fontWeight: FontWeight.w700,
              ),
            ),
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
      padding: const EdgeInsets.all(AppEspaciado.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColores.azulProfesional.withValues(alpha: 0.10),
            AppColores.verde.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        border: Border.all(
          color: AppColores.azulProfesional.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: AppColores.azulProfesional,
                size: 20,
              ),
              const SizedBox(width: AppEspaciado.sm),
              Text(
                'Contrato',
                style: tt.subtitulo.copyWith(color: textoPrincipal),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppEspaciado.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColores.azulProfesional.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadios.chip),
                ),
                child: Text(
                  EstadosTrabajo.etiqueta(pub.estado),
                  style: tt.etiqueta.copyWith(
                    color: AppColores.azulProfesional,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          linea(
            Icons.payments_rounded,
            'Pago acordado',
            'L. ${pub.montoAcordado.toStringAsFixed(0)} en total',
          ),
          linea(
            Icons.schedule_rounded,
            'Tiempo acordado',
            pub.tiempoAcordado.isEmpty ? '—' : pub.tiempoAcordado,
          ),
          linea(
            Icons.person_outline_rounded,
            'Trabajador',
            pub.nombreTrabajadorAsignado.isEmpty
                ? '—'
                : pub.nombreTrabajadorAsignado,
          ),
          linea(
            Icons.business_center_outlined,
            'Contratista',
            pub.autor.isEmpty ? '—' : pub.autor,
          ),
          linea(
            pub.fechaInicio != null
                ? Icons.play_circle_outline_rounded
                : Icons.event_available_outlined,
            pub.fechaInicio != null ? 'Iniciado' : 'Acordado',
            fechaTxt,
          ),
          if (pub.pagoRetenido && !pub.pagoLiberado) ...[
            const SizedBox(height: AppEspaciado.sm),
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: AppColores.verde,
                ),
                const SizedBox(width: AppEspaciado.xs),
                Text(
                  'Pago en garantía',
                  style: tt.etiqueta.copyWith(
                    color: AppColores.verde,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Sección de evidencias / avances ───────────────────────
  Widget _seccionEvidencias(
    BuildContext context,
    Publicacion pub, {
    required bool puedeAgregar,
  }) {
    final textoPrincipal = colorTextoFuerte(context);
    final textoSec = colorTextoSuave(context);
    final superficie = colorSuperficie(context);
    final borde = colorBorde(context);
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.timeline_rounded,
              color: AppColores.azulProfesional,
              size: 18,
            ),
            const SizedBox(width: AppEspaciado.sm),
            Text(
              'Avances del trabajo',
              style: tt.subtitulo.copyWith(color: textoPrincipal),
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.sm),
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
                      borderRadius: BorderRadius.circular(AppRadios.campo),
                      border: Border.all(color: borde),
                    ),
                    child: Text(
                      'Aún no hay avances registrados.',
                      style: tt.cuerpoChico.copyWith(color: textoSec),
                    ),
                  )
                else
                  ...lista.map(
                    (e) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AppEspaciado.sm),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: superficie,
                        borderRadius: BorderRadius.circular(AppRadios.campo),
                        border: Border.all(color: borde),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColores.azulProfesional
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  e.autorNombre.isNotEmpty
                                      ? e.autorNombre[0].toUpperCase()
                                      : '?',
                                  style: tt.etiqueta.copyWith(
                                    color: AppColores.azulProfesional,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppEspaciado.sm),
                              Text(
                                e.autorNombre.isEmpty
                                    ? 'Trabajador'
                                    : e.autorNombre,
                                style: tt.cuerpoChico.copyWith(
                                  color: textoPrincipal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                e.tiempoRelativo,
                                style: tt.etiqueta.copyWith(color: textoSec),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppEspaciado.sm),
                          Text(
                            e.texto,
                            style: tt.cuerpoChico.copyWith(color: textoSec),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (puedeAgregar) ...[
                  const SizedBox(height: AppEspaciado.xs),
                  BotonSecundario(
                    texto: 'Agregar avance',
                    icono: Icons.add_photo_alternate_outlined,
                    onPressed: () => _agregarEvidencia(context, pub),
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
    final texto = await mostrarDialogoAgregarEvidencia(context);
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
