import 'package:flutter/material.dart';
import '../../../../nucleo/api/api_excepciones.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/textos/mensajes_error.dart';

/// Estados y piezas sueltas del feed de "Trabajos": error, vacío y el pie de
/// "cargando más". Extraídos de `trabajos_tab.dart` en la tarea 027 B-2b.

/// Con Firestore un fallo se quedaba en una lista vacía y el usuario leía "aún
/// no hay trabajos", que era falso. Contra HTTP el error se distingue y se
/// enseña.
class EstadoErrorFeed extends StatelessWidget {
  final Object? error;
  final bool oscuro;
  const EstadoErrorFeed({super.key, required this.error, required this.oscuro});

  @override
  Widget build(BuildContext context) {
    final e = error;
    final mensaje =
        e is ExcepcionApi ? e.mensaje : MensajesError.errorGeneral;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          MensajeVacioFeed(
              oscuro: oscuro,
              icono: Icons.cloud_off_outlined,
              texto: mensaje),
          const SizedBox(height: 8),
          const Text('Desliza hacia abajo para reintentar',
              style: TextStyle(fontSize: 12, color: AppColores.grisMedio)),
        ],
      ),
    );
  }
}

class EstadoVacioFeed extends StatelessWidget {
  final bool oscuro;
  final bool esEmpleador;
  const EstadoVacioFeed({
    super.key,
    required this.oscuro,
    required this.esEmpleador,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: MensajeVacioFeed(
        oscuro: oscuro,
        icono: Icons.inbox_outlined,
        texto: esEmpleador
            ? 'Aún no hay publicaciones.\n¡Publica el primer trabajo!'
            : 'Aún no hay trabajos publicados.\nVuelve pronto.',
      ),
    );
  }
}

class MensajeVacioFeed extends StatelessWidget {
  final bool oscuro;
  final IconData icono;
  final String texto;
  const MensajeVacioFeed({
    super.key,
    required this.oscuro,
    required this.icono,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textoSec, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Fila final de la lista mientras se trae la siguiente página del feed.
class PieDeCargaFeed extends StatelessWidget {
  const PieDeCargaFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
              color: AppColores.acento, strokeWidth: 2.5),
        ),
      ),
    );
  }
}
