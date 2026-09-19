import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../compartido/widgets/estado_pantalla.dart';
import '../../../../nucleo/api/api_excepciones.dart';
import '../../../../nucleo/textos/mensajes_error.dart';

/// Estado de error de la bandeja de postulantes: no se pudo leer el trabajo o
/// sus postulantes. Extraído de `postulantes_screen.dart` en la tarea 027 B-2b.
/// Desde la tarea 055 ofrece un botón "Reintentar" opcional ([onReintentar]).
class EstadoErrorPostulantes extends StatelessWidget {
  final Object? error;
  final bool oscuro;
  final VoidCallback? onReintentar;
  const EstadoErrorPostulantes({
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

/// Estado vacío. Por defecto es el de "el trabajo todavía no tiene
/// postulantes"; [icono]/[mensaje] existen para que
/// `mis_postulaciones_screen.dart` (tarea 049) reutilice la misma estructura
/// visual con su propio contenido ("todavía no te has postulado a ningún
/// trabajo") sin cambiar lo que ya enseña `postulantes_screen.dart`.
class EstadoVacioPostulantes extends StatelessWidget {
  final bool oscuro;
  final IconData icono;
  final String mensaje;
  final String? detalle;
  const EstadoVacioPostulantes({
    super.key,
    required this.oscuro,
    this.icono = LucideIcons.users,
    this.mensaje = 'Todavía no hay postulantes.',
    this.detalle = 'Cuando alguien se postule, aparecerá aquí.',
  });

  @override
  Widget build(BuildContext context) {
    return EstadoPantalla(icono: icono, mensaje: mensaje, detalle: detalle);
  }
}
