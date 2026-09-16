import 'package:flutter/material.dart';
import '../../../../nucleo/api/api_excepciones.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/textos/mensajes_error.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Estado de error de la bandeja de postulantes: no se pudo leer el trabajo o
/// sus postulantes. Extraído de `postulantes_screen.dart` en la tarea 027 B-2b.
class EstadoErrorPostulantes extends StatelessWidget {
  final Object? error;
  final bool oscuro;
  const EstadoErrorPostulantes({
    super.key,
    required this.error,
    required this.oscuro,
  });

  @override
  Widget build(BuildContext context) {
    final e = error;
    final mensaje =
        e is ExcepcionApi ? e.mensaje : MensajesError.errorGeneral;
    final tt = Theme.of(context).textTheme;
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
                style: tt.cuerpo.copyWith(
                    color: textoSec, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppEspaciado.sm),
            Text('Desliza hacia abajo para reintentar',
                style: tt.etiqueta.copyWith(color: AppColores.grisMedio)),
          ],
        ),
      ),
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
  const EstadoVacioPostulantes({
    super.key,
    required this.oscuro,
    this.icono = Icons.inbox_outlined,
    this.mensaje = 'Todavía no hay postulantes.',
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 56, color: AppColores.grisMedio),
          const SizedBox(height: AppEspaciado.md),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: tt.cuerpo.copyWith(
                  color: textoSec, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
