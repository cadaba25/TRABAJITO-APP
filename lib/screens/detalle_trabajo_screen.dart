import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/evidencia.dart';
import '../models/postulacion.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
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

/// Detalle completo de una publicación de trabajo, con la acción
/// contextual según el rol del usuario y el estado del trabajo.
class DetalleTrabajoScreen extends StatelessWidget {
  final Publicacion publicacion;
  final Usuario usuario;
  const DetalleTrabajoScreen({
    super.key,
    required this.publicacion,
    required this.usuario,
  });

  @override
  Widget build(BuildContext context) {
    final servicio = PublicacionService();
    // Escuchamos la publicación en vivo para reflejar cambios de estado.
    return StreamBuilder<Publicacion?>(
      stream: servicio.streamPublicacion(publicacion.id),
      builder: (context, snap) {
        final pub = snap.data ?? publicacion;
        return _contenido(context, pub);
      },
    );
  }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColores.acento.withOpacity(0.15),
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
    );
  }

  // ── Acciones contextuales (máquina de estados del flujo) ───
  List<Widget> _acciones(BuildContext context, Publicacion pub) {
    final servicio = PublicacionService();
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
         EstadosTrabajo.completado, EstadosTrabajo.finalizado].contains(e)) {
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
            onPressed: () => ejecutarConCarga(
                context, () => servicio.iniciarTrabajo(pub.id),
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
          w.add(ElevatedButton.icon(
            onPressed: () => ejecutarConCarga(
                context, () => servicio.marcarTerminado(pub.id),
                exito: 'Marcado como terminado'),
            icon: const Icon(Icons.done_all_rounded),
            label: const Text('Marcar como terminado'),
          ));
        } else {
          w.add(_infoBanner('En progreso. El trabajador está realizando el trabajo.'));
          w.add(const SizedBox(height: 4));
          w.add(_botonCancelar(context, pub, true));
        }
        break;
      case EstadosTrabajo.esperandoConfirmacion:
        if (esDueno) {
          w.add(ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColores.verde),
            onPressed: () => ejecutarConCarga(
                context, () => servicio.aceptarTrabajo(pub.id),
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
          w.add(const SizedBox(height: 8));
          w.add(TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColores.error),
            onPressed: () => mostrarSnackBar(context,
                'Reporte enviado. Un mediador revisará el caso (próximamente).'),
            icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18),
            label: const Text('Reportar problema'),
          ));
        } else {
          w.add(_infoBanner('Terminado. Esperando la confirmación del contratista.'));
        }
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
    return StreamBuilder<Postulacion?>(
      stream: PostulacionService().streamMiPostulacion(pub.id, usuario.uid),
      builder: (context, snap) {
        final yaPostulado = snap.data != null &&
            snap.data!.estado != EstadosPostulacion.retirada;
        if (yaPostulado) {
          return ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Ya te postulaste'),
          );
        }
        return ElevatedButton.icon(
          onPressed: () async {
            final ok = await mostrarPostularseSheet(context,
                publicacion: pub, usuario: usuario);
            if (ok == true && context.mounted) {
              mostrarSnackBar(context, '¡Postulación enviada!');
            }
          },
          icon: const Icon(Icons.send_rounded),
          label: const Text('Postularme'),
        );
      },
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
    if (motivo == null || motivo.isEmpty || !context.mounted) return;
    await ejecutarConCarga(
        context, () => PublicacionService().solicitarCorreccion(pub.id, motivo),
        exito: 'Correcciones solicitadas');
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
    await ejecutarConCarga(context, () async {
      final chat = await ChatService().obtenerChat(pub.id);
      if (chat == null || !chat.pagoAcordado || chat.pagoMonto <= 0) {
        return 'Primero acuerden el pago en el chat antes de depositarlo.';
      }
      if (!chat.tiempoAcordado || chat.tiempoValor.isEmpty) {
        return 'Primero acuerden el tiempo en el chat antes de depositar.';
      }
      return PublicacionService().reservarPago(
        idPublicacion: pub.id,
        uidEmpleador: usuario.uid,
        monto: chat.pagoMonto,
        tiempo: chat.tiempoValor,
      );
    }, exito: 'Pago depositado en garantía');
  }

  Future<void> _cancelarContratacion(BuildContext context, Publicacion pub) async {
    final ok = await _confirmar(context, '¿Cancelar la contratación?',
        'Se reabrirá el trabajo y, si hay pago en garantía, se te reembolsará.');
    if (ok != true || !context.mounted) return;
    await ejecutarConCarga(
        context,
        () => PublicacionService().cancelarContratacion(
              idPublicacion: pub.id,
              uidEmpleador: usuario.uid,
              uidTrabajador: pub.uidTrabajadorAsignado,
            ),
        exito: 'Contratación cancelada');
  }

  Future<void> _rechazarTrabajo(BuildContext context, Publicacion pub) async {
    final ok = await _confirmar(context, '¿Rechazar este trabajo?',
        'El trabajo volverá a estar disponible para otros trabajadores.');
    if (ok != true || !context.mounted) return;
    await ejecutarConCarga(
        context,
        () => PublicacionService().rechazarAsignacion(
              idPublicacion: pub.id,
              uidTrabajador: usuario.uid,
            ),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
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
        color: color.withOpacity(0.12),
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
        color: color.withOpacity(0.15),
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
            AppColores.azulProfesional.withOpacity(0.10),
            AppColores.verde.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColores.azulProfesional.withOpacity(0.25)),
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
                  color: AppColores.azulProfesional.withOpacity(0.15),
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
        StreamBuilder<List<Evidencia>>(
          stream: PublicacionService().streamEvidencias(pub.id),
          builder: (context, snap) {
            final lista = snap.data ?? const <Evidencia>[];
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
                                      AppColores.azulProfesional.withOpacity(0.15),
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
    if (texto == null || texto.isEmpty || !context.mounted) return;
    await ejecutarConCarga(
      context,
      () => PublicacionService().agregarEvidencia(
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
