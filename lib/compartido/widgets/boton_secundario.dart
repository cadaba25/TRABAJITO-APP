import 'package:flutter/material.dart';

import 'contenido_boton.dart';

/// Botón secundario del sistema de diseño (`docs/design-system-frontend.md`
/// sección 6, tarea 050, ADR-0016 hallazgo 1). Envuelve [OutlinedButton] con
/// el mismo contrato que [BotonPrimario].
///
/// Altura (52), radio y tipografía salen de `outlinedButtonTheme` en
/// `app_tema.dart` — este widget no los duplica.
class BotonSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final IconData? icono;

  /// Ver el docstring de [BotonPrimario.expandido]: mismo criterio.
  final bool expandido;

  /// Escape hatch para variantes de color puntuales (p. ej. el borde/verde de
  /// "Ya te postulaste" en `tarjeta_trabajo.dart`). `null` deja el color que
  /// ya define el tema.
  final Color? color;

  const BotonSecundario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.icono,
    this.expandido = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: cargando ? null : onPressed,
      style: _estilo(context),
      child: ContenidoBoton(texto: texto, cargando: cargando, icono: icono),
    );
  }

  ButtonStyle? _estilo(BuildContext context) {
    if (expandido && color == null) return null;
    final alto = expandido
        ? null
        : Theme.of(context)
                .outlinedButtonTheme
                .style
                ?.minimumSize
                ?.resolve(const {})
                ?.height ??
            52;
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      side: color == null ? null : BorderSide(color: color!),
      minimumSize: expandido ? null : Size(0, alto!),
    );
  }
}
