import 'package:flutter/material.dart';

import 'contenido_boton.dart';

/// Botón primario del sistema de diseño (`docs/design-system-frontend.md`
/// sección 6, tarea 050, ADR-0016 hallazgo 1). Envuelve [ElevatedButton] y le
/// añade el contrato de loading/disabled/expandido que antes se repetía a
/// mano en cada pantalla (ver `login_screen.dart` antes de esta tarea).
///
/// Altura (52), radio (`AppRadios.campo`) y tipografía salen de
/// `elevatedButtonTheme` en `app_tema.dart` — este widget no los duplica.
class BotonPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;

  /// Mientras es `true`, el contenido se reemplaza por un spinner pequeño y
  /// [onPressed] se fuerza a `null` (no se puede tocar dos veces).
  final bool cargando;

  /// Icono opcional junto al texto (reemplaza a `ElevatedButton.icon`).
  final IconData? icono;

  /// `true` (por defecto) ocupa todo el ancho disponible, que es lo que ya
  /// hacía `elevatedButtonTheme` para todos los usos actuales. Pásalo en
  /// `false` cuando el botón va dos-en-una-fila (p. ej. dentro de un
  /// `Expanded`) y no debe reclamar más ancho del que le toca.
  final bool expandido;

  /// Escape hatch para acentos puntuales de estado que no tienen su propio
  /// componente en el sistema (p. ej. el verde de "aceptar y pagar" o el
  /// dorado de "calificar" en `detalle_trabajo_screen.dart`). `null` (por
  /// defecto) deja el color que ya define el tema — no lo uses para
  /// reintroducir un destructivo a mano, para eso existe [BotonDestructivo].
  final Color? color;

  const BotonPrimario({
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
    return ElevatedButton(
      onPressed: cargando ? null : onPressed,
      style: _estilo(context),
      child: ContenidoBoton(texto: texto, cargando: cargando, icono: icono),
    );
  }

  ButtonStyle? _estilo(BuildContext context) {
    if (expandido && color == null) return null;
    // Solo se ajusta el ancho mínimo a 0 cuando no debe expandirse; el alto
    // sale del tema (no se duplica el valor 52 aquí).
    final alto = expandido
        ? null
        : Theme.of(context)
                .elevatedButtonTheme
                .style
                ?.minimumSize
                ?.resolve(const {})
                ?.height ??
            52;
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      minimumSize: expandido ? null : Size(0, alto!),
    );
  }
}
