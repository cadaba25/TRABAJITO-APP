import 'package:flutter/material.dart';
import '../../../../compartido/modelos/publicacion.dart';
import '../../../../compartido/widgets/pulsa_con_escala.dart';
import '../../../../nucleo/tema/app_colores.dart';

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

    return PulsaConEscala(
      onTap: onAbrir,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: superficie,
          borderRadius: BorderRadius.circular(16),
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
                    style: const TextStyle(
                        color: AppColores.acento,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.autor.isEmpty ? 'Anónimo' : p.autor,
                    style: TextStyle(
                        color: textoPrincipal,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
                Text(p.tiempoRelativo,
                    style: TextStyle(color: textoSec, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (p.categoria.isNotEmpty)
                  _Chip(texto: p.categoria, color: AppColores.acento),
                if (p.plazo.isNotEmpty)
                  _Chip(texto: p.plazo, color: AppColores.azulProfesional),
              ],
            ),
            if (p.categoria.isNotEmpty || p.plazo.isNotEmpty)
              const SizedBox(height: 10),
            Text(
              p.titulo,
              style: TextStyle(
                  color: textoPrincipal,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            Text(
              p.descripcion,
              style: TextStyle(color: textoSec, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: textoSec),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      p.ubicacion.isEmpty ? 'Honduras' : p.ubicacion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textoSec, fontSize: 12)),
                ),
                if (p.presupuesto.isNotEmpty)
                  Text(
                    p.presupuesto,
                    style: const TextStyle(
                        color: AppColores.acento,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: (!esEmpleador && yaPostulado)
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          foregroundColor: AppColores.verde,
                          side: const BorderSide(color: AppColores.verde)),
                      onPressed: onAbrir,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Ya te postulaste'),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
