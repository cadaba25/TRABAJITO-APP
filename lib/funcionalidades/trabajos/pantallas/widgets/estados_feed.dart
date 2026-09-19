import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../compartido/widgets/estado_pantalla.dart';
import '../../../../nucleo/api/api_excepciones.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/textos/mensajes_error.dart';

/// Estados y piezas sueltas del feed de "Trabajos": error, vacío y el pie de
/// "cargando más". Extraídos de `trabajos_tab.dart` en la tarea 027 B-2b; desde
/// la tarea 055 dibujan con [EstadoPantalla] (icono en círculo, copy y CTA).

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
    final mensaje = e is ExcepcionApi ? e.mensaje : MensajesError.errorGeneral;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: EstadoPantalla(
        icono: LucideIcons.cloudOff,
        mensaje: mensaje,
        detalle: 'Desliza hacia abajo para reintentar',
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
      child: EstadoPantalla(
        icono: esEmpleador ? LucideIcons.filePlus : LucideIcons.inbox,
        mensaje: esEmpleador
            ? 'Aún no hay publicaciones.\n¡Publica el primer trabajo!'
            : 'Aún no hay trabajos publicados.\nVuelve pronto.',
        detalle: esEmpleador
            ? 'Toca "Publicar" para que los trabajadores te encuentren.'
            : 'Desliza hacia abajo para actualizar.',
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
      padding: EdgeInsets.symmetric(vertical: AppEspaciado.lg),
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
