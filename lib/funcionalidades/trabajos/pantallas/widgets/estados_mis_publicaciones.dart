import 'package:flutter/material.dart';
import '../../../../nucleo/api/api_excepciones.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/textos/mensajes_error.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

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
        padding: const EdgeInsets.all(AppEspaciado.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColores.grisMedio),
            const SizedBox(height: AppEspaciado.md),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .cuerpo
                    .copyWith(color: textoSec, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppEspaciado.sm),
            Text('Desliza hacia abajo para reintentar',
                style:
                    Theme.of(context).textTheme.etiqueta.copyWith(color: AppColores.grisMedio)),
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
          const SizedBox(height: AppEspaciado.md),
          Text(
            'Todavía no has publicado nada.\n¡Crea tu primera publicación!',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .cuerpo
                .copyWith(color: textoSec, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
