import 'package:flutter/material.dart';

import '../../nucleo/tema/app_colores.dart';
import 'contenido_boton.dart';

/// Botón destructivo del sistema de diseño (`docs/design-system-frontend.md`
/// sección 6, tarea 050, ADR-0016 hallazgo 1). Envuelve [ElevatedButton] con
/// `backgroundColor: AppColores.error`.
///
/// Antes de esta tarea este mismo bloque se reimplementaba a mano en 7+
/// sitios (diálogos de confirmación de cierre de sesión, baja de cuenta,
/// cerrar publicación, reclamar problema...), cada uno con su propio
/// `minimumSize` suelto — algunos `Size(100, 40)`, que rompía el criterio de
/// altura del resto del sistema (52). Este componente usa el mismo alto que
/// [BotonPrimario]/[BotonSecundario] (sale de `elevatedButtonTheme`, no se
/// duplica aquí): unificar esas alturas es parte del arreglo, no un efecto
/// secundario.
class BotonDestructivo extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final IconData? icono;

  /// Ver el docstring de [BotonPrimario.expandido]: mismo criterio.
  final bool expandido;

  const BotonDestructivo({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.icono,
    this.expandido = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: cargando ? null : onPressed,
      style: _estilo(context),
      child: ContenidoBoton(texto: texto, cargando: cargando, icono: icono),
    );
  }

  ButtonStyle _estilo(BuildContext context) {
    final alto = Theme.of(context)
            .elevatedButtonTheme
            .style
            ?.minimumSize
            ?.resolve(const {})
            ?.height ??
        52;
    return ElevatedButton.styleFrom(
      backgroundColor: AppColores.error,
      minimumSize: Size(expandido ? double.infinity : 0, alto),
    );
  }
}
