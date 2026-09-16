import 'package:flutter/material.dart';

import '../../nucleo/tema/app_colores.dart';

/// Botón de icono del sistema de diseño (`docs/design-system-frontend.md`
/// sección 6 y 14, tarea 050, ADR-0016 hallazgo 1). Envuelve [IconButton].
///
/// **[tooltip] es obligatorio, no nullable**: así ningún caso nuevo puede
/// repetir el hallazgo 6 (labels semánticos ausentes) por construcción — el
/// tipo no compila sin él, no hace falta acordarse.
///
/// Tamaño mínimo fijo de 48×48 (sección 9, ergonomía de targets táctiles):
/// nunca uses `visualDensity: VisualDensity.compact` ni nada que lo reduzca
/// por fuera de este widget.
class BotonIcono extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onPressed;
  final String tooltip;

  /// Para los casos de toggle (p. ej. el icono de filtro de
  /// `barra_busqueda_trabajos.dart`): `true` lo pinta con
  /// [AppColores.acento], igual que antes se hacía a mano con un ternario.
  final bool seleccionado;

  /// Override puntual si hace falta; el valor por defecto sale del tema
  /// (el `IconTheme` heredado), no de un color suelto.
  final Color? color;

  const BotonIcono({
    super.key,
    required this.icono,
    required this.onPressed,
    required this.tooltip,
    this.seleccionado = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        icono,
        color: color ?? (seleccionado ? AppColores.acento : null),
      ),
    );
  }
}
