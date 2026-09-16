import 'package:flutter/material.dart';
import '../../../../compartido/modelos/postulacion.dart';
import '../../../../compartido/modelos/publicacion.dart';
import '../../../../compartido/widgets/boton_primario.dart';
import '../../../../compartido/widgets/boton_secundario.dart';
import '../../../../nucleo/dominio/estados.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

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
    final tt = Theme.of(context).textTheme;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final esElegido = pub.uidTrabajadorAsignado == p.uidTrabajador;
    final trabajoActivo = pub.estado == EstadosTrabajo.activo;

    return Container(
      margin: const EdgeInsets.only(bottom: AppEspaciado.md),
      padding: const EdgeInsets.all(AppEspaciado.lg),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
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
                  style: tt.cuerpoChico
                      .copyWith(color: AppColores.acento, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppEspaciado.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombreTrabajador,
                        style:
                            tt.subtitulo.copyWith(color: textoPrincipal)),
                    Text('Postuló ${p.tiempoRelativo}',
                        style: tt.etiqueta.copyWith(color: textoSec)),
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
          const SizedBox(height: AppEspaciado.md),
          // Mensaje del postulante destacado (o aviso si no dejó mensaje).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppEspaciado.md),
            decoration: BoxDecoration(
              color: AppColores.acento.withValues(alpha: oscuro ? 0.10 : 0.06),
              borderRadius: BorderRadius.circular(AppRadios.campo),
              border:
                  Border.all(color: AppColores.acento.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 18, color: AppColores.acento.withValues(alpha: 0.7)),
                const SizedBox(width: AppEspaciado.sm),
                Expanded(
                  child: Text(
                    p.mensaje.isNotEmpty
                        ? p.mensaje
                        : 'No dejó un mensaje. Revisa su perfil.',
                    style: tt.cuerpoChico.copyWith(
                        color: p.mensaje.isNotEmpty ? textoPrincipal : textoSec,
                        fontStyle: p.mensaje.isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          Row(
            children: [
              Expanded(
                child: BotonSecundario(
                  texto: 'Ver perfil',
                  expandido: false,
                  onPressed: onVerPerfil,
                ),
              ),
              const SizedBox(width: AppEspaciado.md),
              if (trabajoActivo)
                Expanded(
                  child: BotonPrimario(
                    texto: 'Seleccionar',
                    expandido: false,
                    onPressed: onSeleccionar,
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.md, vertical: AppEspaciado.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadios.chip),
      ),
      child: Text(texto,
          style: Theme.of(context)
              .textTheme
              .etiqueta
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
