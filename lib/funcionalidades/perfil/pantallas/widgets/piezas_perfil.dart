import 'package:flutter/material.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

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
      padding: const EdgeInsets.only(left: AppEspaciado.xs, bottom: AppEspaciado.md),
      child: Text(texto,
          style: Theme.of(context).textTheme.cuerpoChico.copyWith(
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
        conDivisores.add(Divider(
            height: 1,
            color: borde,
            indent: AppEspaciado.lg,
            endIndent: AppEspaciado.lg));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
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
    final tt = Theme.of(context).textTheme;
    return Padding(
      // El 14 vertical se deja literal: mismo caso suelto de redondeo entre
      // `md` (12) y `lg` (16) que ya documentaron 031/035.
      padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.lg, vertical: 14),
      child: Row(
        children: [
          Icon(icono, color: AppColores.azulProfesional, size: 20),
          const SizedBox(width: AppEspaciado.md),
          Text(titulo, style: tt.cuerpoChico.copyWith(color: textoSec)),
          const Spacer(),
          Flexible(
            child: Text(valor,
                textAlign: TextAlign.end,
                style: tt.cuerpoChico
                    .copyWith(color: textoPrincipal, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
