import 'package:flutter/material.dart';
import '../../../../compartido/modelos/publicacion.dart';
import '../../../../compartido/widgets/pulsa_con_escala.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Tarjeta de una publicación en el feed de "Trabajos".
///
/// Extraída de `trabajos_tab.dart` en la tarea 027 B-2b. La lógica de
/// presentación que concentra: los chips de categoría/plazo y la rama del botón
/// según el trabajador ya se haya postulado o no. La navegación al detalle y la
/// carga viven en el `State` de la pestaña; aquí solo se despacha [onAbrir].
class TarjetaTrabajo extends StatelessWidget {
  final Publicacion publicacion;
  final bool oscuro;
  final bool esEmpleador;

  /// `true` si este trabajador ya se postuló a este trabajo. Ignorado para el
  /// empleador.
  final bool yaPostulado;

  /// Abrir el detalle del trabajo (que es también donde el trabajador se
  /// postula).
  final VoidCallback onAbrir;

  const TarjetaTrabajo({
    super.key,
    required this.publicacion,
    required this.oscuro,
    required this.esEmpleador,
    required this.yaPostulado,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final p = publicacion;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
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
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColores.acento.withValues(alpha: 0.15),
                  child: Text(
                    p.autor.isNotEmpty ? p.autor[0].toUpperCase() : '?',
                    style: tt.cuerpoChico
                        .copyWith(color: AppColores.acento, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: AppEspaciado.md),
                Expanded(
                  child: Text(
                    p.autor.isEmpty ? 'Anónimo' : p.autor,
                    style: tt.cuerpoChico
                        .copyWith(color: textoPrincipal, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(p.tiempoRelativo, style: tt.etiqueta.copyWith(color: textoSec)),
              ],
            ),
            const SizedBox(height: AppEspaciado.md),
            Wrap(
              spacing: AppEspaciado.sm,
              runSpacing: AppEspaciado.sm,
              children: [
                if (p.categoria.isNotEmpty)
                  _Chip(texto: p.categoria, color: AppColores.acento),
                if (p.plazo.isNotEmpty)
                  _Chip(texto: p.plazo, color: AppColores.azulProfesional),
              ],
            ),
            if (p.categoria.isNotEmpty || p.plazo.isNotEmpty)
              const SizedBox(height: AppEspaciado.md),
            Text(p.titulo, style: tt.subtitulo.copyWith(color: textoPrincipal)),
            const SizedBox(height: AppEspaciado.sm),
            Text(p.descripcion, style: tt.cuerpoChico.copyWith(color: textoSec)),
            const SizedBox(height: AppEspaciado.md),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: textoSec),
                const SizedBox(width: AppEspaciado.xs),
                Expanded(
                  child: Text(p.ubicacion.isEmpty ? 'Honduras' : p.ubicacion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.etiqueta.copyWith(color: textoSec)),
                ),
                if (p.presupuesto.isNotEmpty)
                  // Rol `numero`: es literalmente "montos y precios", el uso
                  // que documenta `AppTipografia`. `colorPrecio()` corrige el
                  // contraste del dorado como texto sobre fondo claro (034).
                  Text(p.presupuesto, style: tt.numero.copyWith(color: colorPrecio(context))),
              ],
            ),
            const SizedBox(height: AppEspaciado.md),
            SizedBox(
              width: double.infinity,
              child: (!esEmpleador && yaPostulado)
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: AppColores.verde,
                          side: const BorderSide(color: AppColores.verde)),
                      onPressed: onAbrir,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Ya te postulaste'),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      onPressed: onAbrir,
                      child: Text(esEmpleador ? 'Ver detalles' : 'Postularme'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final Color color;
  const _Chip({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppEspaciado.md, vertical: AppEspaciado.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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
