import 'package:flutter/material.dart';

import '../../nucleo/tema/app_colores.dart';
import '../../nucleo/tema/colores_por_tema.dart';
import 'contenido_boton.dart';

/// Botón de énfasis medio del sistema de diseño
/// (`docs/design-system-frontend.md` sección 6, tarea 050, ADR-0016 hallazgo
/// 1): entre el peso visual de [BotonPrimario] (relleno sólido) y
/// [BotonSecundario] (solo borde).
///
/// **Hoy ninguna pantalla lo necesita** (ver el reporte de la tarea 050): se
/// deja construido y documentado para que la próxima que necesite un botón
/// de énfasis medio no vuelva a inventar uno a mano. Fondo
/// `AppColores.acento` muy tenue (`alpha: 0.12`, el mismo valor que ya usa
/// `colorSuperficieAlterna`/las insignias de icono) y texto con la variante
/// WCAG-segura de [colorAcentoTexto] (mismo criterio que [BotonTexto]).
///
/// Altura y radio salen de `elevatedButtonTheme` (mismo criterio que el
/// resto de botones "grandes"): es un `ElevatedButton` con el fondo y el
/// texto sobrescritos, no un componente de Material distinto.
class BotonTerciario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final IconData? icono;

  /// Ver el docstring de [BotonPrimario.expandido]: mismo criterio.
  final bool expandido;

  const BotonTerciario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.icono,
    this.expandido = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = colorAcentoTexto(context);
    return ElevatedButton(
      onPressed: cargando ? null : onPressed,
      style: _estilo(context, colorTexto),
      child: ContenidoBoton(
        texto: texto,
        cargando: cargando,
        icono: icono,
        colorSpinner: colorTexto,
      ),
    );
  }

  ButtonStyle _estilo(BuildContext context, Color colorTexto) {
    final alto = Theme.of(context)
            .elevatedButtonTheme
            .style
            ?.minimumSize
            ?.resolve(const {})
            ?.height ??
        52;
    return ElevatedButton.styleFrom(
      backgroundColor: AppColores.acento.withValues(alpha: 0.12),
      foregroundColor: colorTexto,
      elevation: 0,
      minimumSize: Size(expandido ? double.infinity : 0, alto),
    );
  }
}
