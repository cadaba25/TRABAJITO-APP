import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../compartido/widgets/estado_pantalla.dart';
import '../../../../nucleo/api/api_excepciones.dart';
import '../../../../nucleo/textos/mensajes_error.dart';

/// Estado de error de "Mis publicaciones": no se pudo leer la lista.
///
/// Extraído de `mis_publicaciones_screen.dart` en la tarea 027 B-2b. Solo
/// presentación: el `error` y el gesto de reintentar los gestiona la pantalla
/// (desde la tarea 055 también hay un botón, vía [onReintentar]).
class EstadoErrorMisPublicaciones extends StatelessWidget {
  final Object? error;
  final bool oscuro;
  final VoidCallback? onReintentar;
  const EstadoErrorMisPublicaciones({
    super.key,
    required this.error,
    required this.oscuro,
    this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final e = error;
    final mensaje = e is ExcepcionApi ? e.mensaje : MensajesError.errorGeneral;
    return EstadoPantalla(
      icono: LucideIcons.cloudOff,
      mensaje: mensaje,
      detalle: 'Desliza hacia abajo para reintentar',
      etiquetaAccion: 'Reintentar',
      iconoAccion: LucideIcons.refreshCw,
      onAccion: onReintentar,
    );
  }
}

/// Estado vacío de "Mis publicaciones": el contratista aún no ha publicado nada.
class EstadoVacioMisPublicaciones extends StatelessWidget {
  final bool oscuro;
  final VoidCallback? onPublicar;
  const EstadoVacioMisPublicaciones({super.key, required this.oscuro, this.onPublicar});

  @override
  Widget build(BuildContext context) {
    return EstadoPantalla(
      icono: LucideIcons.filePlus,
      mensaje: 'Todavía no has publicado nada.\n¡Crea tu primera publicación!',
      detalle: 'Describe el trabajo y recibe postulaciones de trabajadores.',
      etiquetaAccion: 'Publicar un trabajo',
      iconoAccion: LucideIcons.plus,
      onAccion: onPublicar,
    );
  }
}
