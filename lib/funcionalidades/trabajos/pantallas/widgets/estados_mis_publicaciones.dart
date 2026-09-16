import 'package:flutter/material.dart';
import '../../../../nucleo/api/api_excepciones.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/textos/mensajes_error.dart';

/// Estado de error de "Mis publicaciones": no se pudo leer la lista.
///
/// Extraído de `mis_publicaciones_screen.dart` en la tarea 027 B-2b. Solo
/// presentación: el `error` y el gesto de reintentar (deslizar) los gestiona
/// la pantalla.
class EstadoErrorMisPublicaciones extends StatelessWidget {
  final Object? error;
  final bool oscuro;
  const EstadoErrorMisPublicaciones({
    super.key,
    required this.error,
    required this.oscuro,
  });

  @override
  Widget build(BuildContext context) {
    final e = error;
    final mensaje =
        e is ExcepcionApi ? e.mensaje : MensajesError.errorGeneral;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColores.grisMedio),
            const SizedBox(height: 14),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: textoSec, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Desliza hacia abajo para reintentar',
                style: TextStyle(fontSize: 12, color: AppColores.grisMedio)),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío de "Mis publicaciones": el contratista aún no ha publicado nada.
class EstadoVacioMisPublicaciones extends StatelessWidget {
  final bool oscuro;
  const EstadoVacioMisPublicaciones({super.key, required this.oscuro});

  @override
  Widget build(BuildContext context) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.post_add_rounded,
              size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text(
            'Todavía no has publicado nada.\n¡Crea tu primera publicación!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textoSec, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
