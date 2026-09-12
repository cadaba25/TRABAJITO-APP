import 'package:flutter/material.dart';
import '../../../../compartido/modelos/publicacion.dart';
import '../../../../compartido/widgets/pulsa_con_escala.dart';
import '../../../../nucleo/dominio/estados.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Tarjeta de una publicación propia en "Mis publicaciones".
///
/// Extraída de `mis_publicaciones_screen.dart` en la tarea 027 B-2b. Contiene
/// la única lógica de presentación no trivial de esa pantalla: el badge con la
/// etiqueta real del estado (ADR-0007, diez estados) y la rama de si el trabajo
/// **todavía se puede cerrar**. El estado y las acciones viven en la pantalla;
/// aquí solo se decide qué se pinta y se despachan los eventos.
class TarjetaMiPublicacion extends StatelessWidget {
  final Publicacion publicacion;
  final bool oscuro;

  /// Abrir el detalle del trabajo.
  final VoidCallback onAbrir;

  /// Cerrar la publicación. La tarjeta decide sola si el botón se ofrece
  /// (`sePuedeCerrar`, según el estado): cerrar solo vale antes de que el
  /// trabajo inicie (ADR-0007), después el servidor responde 409.
  final VoidCallback onCerrar;

  /// Pulsar "Eliminar" (que en realidad explica que no se borra y ofrece
  /// cerrar).
  final VoidCallback onEliminar;

  const TarjetaMiPublicacion({
    super.key,
    required this.publicacion,
    required this.oscuro,
    required this.onAbrir,
    required this.onCerrar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final p = publicacion;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final activo = p.estado == EstadosTrabajo.activo;
    // Cerrar solo es posible antes de que el trabajo inicie (ADR-0007).
    // Después el servidor responde 409, así que no se ofrece el botón.
    final sePuedeCerrar = const [
      EstadosTrabajo.activo,
      EstadosTrabajo.asignado,
      EstadosTrabajo.acordado,
    ].contains(p.estado);
    final tt = Theme.of(context).textTheme;

    return PulsaConEscala(
      onTap: onAbrir,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppEspaciado.md),
        padding: const EdgeInsets.all(AppEspaciado.lg),
        decoration: BoxDecoration(
          color: superficie,
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          border: Border.all(color: borde, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.titulo, style: tt.subtitulo.copyWith(color: textoPrincipal)),
                ),
                const SizedBox(width: AppEspaciado.sm),
                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppEspaciado.md, vertical: AppEspaciado.xs),
                  decoration: BoxDecoration(
                    color: (activo ? AppColores.exito : AppColores.grisMedio)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadios.chip),
                  ),
                  child: Text(
                    // Los estados ya no son dos: el backend tiene diez
                    // (ADR-0007). Enseñar "Cerrado" para un trabajo en progreso
                    // sería mentir, así que se usa la etiqueta real.
                    EstadosTrabajo.etiqueta(p.estado),
                    style: tt.etiqueta.copyWith(
                        color: activo ? AppColores.exito : AppColores.grisMedio,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppEspaciado.sm),
            Text(
              p.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.cuerpoChico.copyWith(color: textoSec),
            ),
            const SizedBox(height: AppEspaciado.sm),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: textoSec),
                const SizedBox(width: AppEspaciado.xs),
                Text(p.tiempoRelativo, style: tt.etiqueta.copyWith(color: textoSec)),
                if (p.presupuesto.isNotEmpty) ...[
                  const Spacer(),
                  // Rol `numero`: montos y precios. Mismo criterio y misma
                  // nota de contraste que `tarjeta_trabajo.dart` (034).
                  Text(p.presupuesto, style: tt.numero.copyWith(color: AppColores.acento)),
                ],
              ],
            ),
            const SizedBox(height: AppEspaciado.md),
            Divider(height: 1, color: borde),
            const SizedBox(height: AppEspaciado.xs),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    // Sin `onPressed` el botón queda desactivado, que es la
                    // forma honesta de decir "esto ya no se puede": antes ponía
                    // "Reabrir" y no había forma de reabrir nada.
                    onPressed: sePuedeCerrar ? onCerrar : null,
                    icon: Icon(Icons.lock_outline_rounded,
                        size: 18, color: sePuedeCerrar ? textoSec : null),
                    label: Text(sePuedeCerrar ? 'Cerrar' : 'Ya no se puede cerrar',
                        style: tt.cuerpoChico.copyWith(color: sePuedeCerrar ? textoSec : null)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEliminar,
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColores.error),
                    label: Text('Eliminar',
                        style: tt.cuerpoChico.copyWith(color: AppColores.error)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
