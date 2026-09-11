import 'package:flutter/material.dart';
import '../../../../nucleo/tema/app_colores.dart';

/// Piezas de maquetación compartidas por la pestaña "Perfil" y sus secciones.
///
/// Extraídas de `perfil_tab.dart` en la tarea 027 B-2b (eran `_seccion`,
/// `_tarjeta` y `_fila`). Solo presentación.

/// Título de sección ("Información", "Reputación"…).
class SeccionPerfil extends StatelessWidget {
  final String texto;
  const SeccionPerfil(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(texto,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: oscuro ? AppColores.grisMedio : AppColores.grisTexto,
              letterSpacing: 0.3)),
    );
  }
}

/// Tarjeta con borde que agrupa filas, poniéndoles un divisor entre medias.
class TarjetaPerfil extends StatelessWidget {
  final List<Widget> hijos;
  const TarjetaPerfil({super.key, required this.hijos});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final conDivisores = <Widget>[];
    for (var i = 0; i < hijos.length; i++) {
      conDivisores.add(hijos[i]);
      if (i < hijos.length - 1) {
        conDivisores
            .add(Divider(height: 1, color: borde, indent: 16, endIndent: 16));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde, width: 1),
      ),
      child: Column(children: conDivisores),
    );
  }
}

/// Fila "icono · título · valor" dentro de una [TarjetaPerfil].
class FilaPerfil extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  const FilaPerfil(this.icono, this.titulo, this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, color: AppColores.azulProfesional, size: 20),
          const SizedBox(width: 12),
          Text(titulo,
              style: TextStyle(
                  color: textoSec, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(valor,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: textoPrincipal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
