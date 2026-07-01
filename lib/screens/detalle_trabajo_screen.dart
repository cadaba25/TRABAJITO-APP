import 'package:flutter/material.dart';
import '../models/postulacion.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
import '../services/postulacion_service.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import 'calificar_sheet.dart';
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
            if (pub.categoria.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColores.acento.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(pub.categoria,
                    style: const TextStyle(
                        color: AppColores.acento,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
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
      final acciones = <Widget>[
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
      if (pub.estado == EstadosTrabajo.asignado ||
          pub.estado == EstadosTrabajo.enProgreso) {
        acciones.add(const SizedBox(height: 12));
        acciones.add(ElevatedButton.icon(
          onPressed: () async {
            final error = await servicio.marcarCompletado(pub.id);
            if (context.mounted) {
              mostrarSnackBar(context, error ?? '¡Trabajo completado!',
                  esError: error != null);
            }
          },
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('Marcar como completado'),
        ));
      }
      if (pub.estado == EstadosTrabajo.completado) {
        acciones.add(const SizedBox(height: 12));
        acciones.add(_botonCalificar(
          context, pub,
          hecho: pub.calificadoPorEmpleador,
          paraUid: pub.uidTrabajadorAsignado,
          paraNombre: pub.nombreTrabajadorAsignado,
          etiqueta: 'Calificar al trabajador',
        ));
      }
      return acciones;
    }

    // ── Trabajador asignado ──
    if (_esAsignado(pub)) {
      if (pub.estado == EstadosTrabajo.completado) {
        return [
          _botonCalificar(
            context, pub,
            hecho: pub.calificadoPorTrabajador,
            paraUid: pub.uidEmpleador,
            paraNombre: pub.autor,
            etiqueta: 'Calificar al contratador',
          ),
        ];
      }
      return [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColores.verde.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColores.verde.withOpacity(0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColores.verde, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('¡Fuiste seleccionado para este trabajo!',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppColores.texto)),
              ),
            ],
          ),
        ),
      ];
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
