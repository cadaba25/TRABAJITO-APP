import 'package:flutter/material.dart';
import '../../../../compartido/modelos/publicacion.dart';
import '../../../../nucleo/dominio/estados.dart';
import '../../../../nucleo/tema/app_colores.dart';

/// Cabecera de la bandeja de postulantes: título del trabajo y, debajo, o el
/// número de postulantes o a quién se asignó.
///
/// Extraída de `postulantes_screen.dart` en la tarea 027 B-2b.
class CabeceraPostulantes extends StatelessWidget {
  final Publicacion publicacion;
  final int numeroPostulantes;
  final bool oscuro;

  const CabeceraPostulantes({
    super.key,
    required this.publicacion,
    required this.numeroPostulantes,
    required this.oscuro,
  });

  @override
  Widget build(BuildContext context) {
    final pub = publicacion;
    final n = numeroPostulantes;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final asignado = pub.estado != EstadosTrabajo.activo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pub.titulo,
              style: TextStyle(
                  color: oscuro ? AppColores.textoOscuro : AppColores.texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            asignado
                ? 'Trabajo asignado a ${pub.nombreTrabajadorAsignado}'
                : '$n ${n == 1 ? 'postulante' : 'postulantes'}',
            style: TextStyle(color: textoSec, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
