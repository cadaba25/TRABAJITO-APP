import 'package:flutter/material.dart';
import '../models/chat.dart';
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
                      pub.ubicacion.isEmpty ? 'Honduras' : pub.ubicacion),
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

  // ── Acciones contextuales ──────────────────────────────────
  List<Widget> _acciones(BuildContext context, Publicacion pub) {
    final servicio = PublicacionService();

    // ── Dueño (contratador) ──
    if (_esDueno(pub)) {
      // Trabajo aún abierto: gestionar postulantes.
      if (pub.estado == EstadosTrabajo.activo) {
        return [
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PostulantesScreen(publicacion: pub)),
            ),
            icon: const Icon(Icons.people_outline_rounded),
            label: const Text('Ver postulantes'),
          ),
        ];
      }
      // Cerrado sin trabajador asignado.
      if (pub.uidTrabajadorAsignado.isEmpty) return [];

      final acciones = <Widget>[_botonChat(context, pub)];
      if (pub.pagoLiberado || pub.estado == EstadosTrabajo.completado) {
        acciones.add(const SizedBox(height: 12));
        acciones.add(_botonCalificar(
          context, pub,
          hecho: pub.calificadoPorEmpleador,
          paraUid: pub.uidTrabajadorAsignado,
          paraNombre: pub.nombreTrabajadorAsignado,
          etiqueta: 'Calificar al trabajador',
        ));
      } else if (!pub.pagoRetenido) {
        acciones.add(const SizedBox(height: 12));
        acciones.add(ElevatedButton.icon(
          onPressed: () => _reservarPago(context, pub),
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Depositar pago en garantía'),
        ));
      } else if (!pub.entregado) {
        acciones.add(const SizedBox(height: 12));
        acciones.add(_infoBanner(
            'Pago en garantía (L. ${pub.montoAcordado.toStringAsFixed(0)}). '
            'Esperando que el trabajador entregue.'));
      } else {
        acciones.add(const SizedBox(height: 12));
        acciones.add(ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColores.verde),
          onPressed: () async {
            final err = await servicio.confirmarYPagar(pub.id);
            if (context.mounted) {
              mostrarSnackBar(context,
                  err ?? '¡Pago liberado al trabajador!',
                  esError: err != null);
            }
          },
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(
              'Confirmar y pagar L. ${pub.montoAcordado.toStringAsFixed(0)}'),
        ));
      }
      // Cancelar contratación (mientras no se haya pagado).
      if (!pub.pagoLiberado && pub.estado != EstadosTrabajo.completado) {
        acciones.add(const SizedBox(height: 4));
        acciones.add(_botonCancelar(context, pub, true));
      }
      return acciones;
    }

    // ── Trabajador asignado ──
    if (_esAsignado(pub)) {
      final acciones = <Widget>[
        _infoBanner('¡Fuiste seleccionado para este trabajo!',
            color: AppColores.verde),
        const SizedBox(height: 12),
        _botonChat(context, pub),
      ];
      if (pub.pagoLiberado || pub.estado == EstadosTrabajo.completado) {
        acciones.add(const SizedBox(height: 12));
        acciones.add(_botonCalificar(
          context, pub,
          hecho: pub.calificadoPorTrabajador,
          paraUid: pub.uidEmpleador,
          paraNombre: pub.autor,
          etiqueta: 'Calificar al contratador',
        ));
      } else if (!pub.pagoRetenido) {
        acciones.add(const SizedBox(height: 12));
        acciones.add(_infoBanner(
            'Acuerden el pago en el chat. El contratista lo depositará en '
            'garantía antes de empezar.'));
      } else if (!pub.entregado) {
        acciones.add(const SizedBox(height: 12));
        acciones.add(ElevatedButton.icon(
          onPressed: () async {
            final err = await servicio.marcarEntregado(pub.id);
            if (context.mounted) {
              mostrarSnackBar(context, err ?? 'Marcado como entregado',
                  esError: err != null);
            }
          },
          icon: const Icon(Icons.done_all_rounded),
          label: const Text('Marcar trabajo como entregado'),
        ));
      } else {
        acciones.add(const SizedBox(height: 12));
        acciones.add(_infoBanner(
            'Entregado. Esperando la confirmación y el pago del contratista.'));
      }
      // Rechazar el trabajo solo antes de que haya pago en garantía.
      if (!pub.pagoRetenido &&
          !pub.pagoLiberado &&
          pub.estado != EstadosTrabajo.completado) {
        acciones.add(const SizedBox(height: 4));
        acciones.add(_botonCancelar(context, pub, false));
      }
      return acciones;
    }

    // ── Empleador viendo trabajo ajeno ──
    if (usuario.esEmpleador) return [];

    // ── Trabajador no asignado ──
    if (pub.estado != EstadosTrabajo.activo) {
      return [
        ElevatedButton(
          onPressed: null,
          child: const Text('Este trabajo ya no está disponible'),
        ),
      ];
    }
    return [
      StreamBuilder<Postulacion?>(
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
      ),
    ];
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
    final chat = await ChatService().obtenerChat(pub.id);
    if (!context.mounted) return;
    if (chat == null || !chat.pagoAcordado || chat.pagoMonto <= 0) {
      mostrarSnackBar(context,
          'Primero acuerden el pago en el chat antes de depositarlo.',
          esError: true);
      return;
    }
    final err = await PublicacionService().reservarPago(
      idPublicacion: pub.id,
      uidEmpleador: usuario.uid,
      monto: chat.pagoMonto,
    );
    if (context.mounted) {
      mostrarSnackBar(context, err ?? 'Pago depositado en garantía',
          esError: err != null);
    }
  }

  Future<void> _cancelarContratacion(BuildContext context, Publicacion pub) async {
    final ok = await _confirmar(context, '¿Cancelar la contratación?',
        'Se reabrirá el trabajo y, si hay pago en garantía, se te reembolsará.');
    if (ok != true) return;
    final err = await PublicacionService().cancelarContratacion(
      idPublicacion: pub.id,
      uidEmpleador: usuario.uid,
      uidTrabajador: pub.uidTrabajadorAsignado,
    );
    if (context.mounted) {
      mostrarSnackBar(context, err ?? 'Contratación cancelada',
          esError: err != null);
    }
  }

  Future<void> _rechazarTrabajo(BuildContext context, Publicacion pub) async {
    final ok = await _confirmar(context, '¿Rechazar este trabajo?',
        'El trabajo volverá a estar disponible para otros trabajadores.');
    if (ok != true) return;
    final err = await PublicacionService().rechazarAsignacion(
      idPublicacion: pub.id,
      uidTrabajador: usuario.uid,
    );
    if (context.mounted) {
      mostrarSnackBar(context, err ?? 'Rechazaste el trabajo',
          esError: err != null);
    }
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
    String texto;
    switch (estado) {
      case EstadosTrabajo.activo:
        color = AppColores.verde; texto = 'Activo'; break;
      case EstadosTrabajo.asignado:
        color = AppColores.azulProfesional; texto = 'Asignado'; break;
      case EstadosTrabajo.enProgreso:
        color = AppColores.dorado; texto = 'En progreso'; break;
      case EstadosTrabajo.completado:
        color = AppColores.grisMedio; texto = 'Completado'; break;
      default:
        color = AppColores.grisMedio; texto = 'Cerrado';
    }
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
}
