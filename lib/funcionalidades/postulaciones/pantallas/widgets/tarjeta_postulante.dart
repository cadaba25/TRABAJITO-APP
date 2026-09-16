import 'package:flutter/material.dart';
import '../../../../compartido/modelos/postulacion.dart';
import '../../../../compartido/modelos/publicacion.dart';
import '../../../../nucleo/dominio/estados.dart';
import '../../../../nucleo/tema/app_colores.dart';

/// Tarjeta de un postulante en la bandeja del contratador.
///
/// Extraída de `postulantes_screen.dart` en la tarea 027 B-2b. Concentra la
/// lógica de presentación de esa pantalla: el marco verde y el check del
/// elegido, el badge de estado de la postulación y el botón "Seleccionar" que
/// solo aparece si el trabajo sigue activo. El estado y las acciones
/// (`_verPerfil`, `_seleccionar`) viven en la pantalla.
class TarjetaPostulante extends StatelessWidget {
  final Publicacion publicacion;
  final Postulacion postulacion;
  final bool oscuro;

  /// Abrir el perfil del trabajador.
  final VoidCallback onVerPerfil;

  /// Elegir a este postulante. La tarjeta solo ofrece el botón si el trabajo
  /// sigue activo.
  final VoidCallback onSeleccionar;

  const TarjetaPostulante({
    super.key,
    required this.publicacion,
    required this.postulacion,
    required this.oscuro,
    required this.onVerPerfil,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final pub = publicacion;
    final p = postulacion;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final esElegido = pub.uidTrabajadorAsignado == p.uidTrabajador;
    final trabajoActivo = pub.estado == EstadosTrabajo.activo;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: esElegido ? AppColores.verde : borde,
            width: esElegido ? 1.5 : 1),
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
                  p.nombreTrabajador.isNotEmpty
                      ? p.nombreTrabajador[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColores.acento, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombreTrabajador,
                        style: TextStyle(
                            color: textoPrincipal,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text('Postuló ${p.tiempoRelativo}',
                        style: TextStyle(color: textoSec, fontSize: 12)),
                  ],
                ),
              ),
              if (esElegido)
                const Icon(Icons.check_circle_rounded,
                    color: AppColores.verde, size: 22)
              else
                _Badge(estado: p.estado),
            ],
          ),
          const SizedBox(height: 12),
          // Mensaje del postulante destacado (o aviso si no dejó mensaje).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColores.acento.withValues(alpha: oscuro ? 0.10 : 0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColores.acento.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 18, color: AppColores.acento.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.mensaje.isNotEmpty
                        ? p.mensaje
                        : 'No dejó un mensaje. Revisa su perfil.',
                    style: TextStyle(
                        color: p.mensaje.isNotEmpty ? textoPrincipal : textoSec,
                        fontSize: 13,
                        height: 1.4,
                        fontStyle: p.mensaje.isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onVerPerfil,
                  child: const Text('Ver perfil'),
                ),
              ),
              const SizedBox(width: 10),
              if (trabajoActivo)
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSeleccionar,
                    child: const Text('Seleccionar'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String estado;
  const _Badge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color = AppColores.grisMedio;
    String texto = 'Pendiente';
    if (estado == EstadosPostulacion.aceptada) {
      color = AppColores.verde;
      texto = 'Aceptada';
    } else if (estado == EstadosPostulacion.rechazada) {
      color = AppColores.error;
      texto = 'Rechazada';
    }
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
}
