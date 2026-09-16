import 'package:flutter/material.dart';

import '../../nucleo/espaciado/app_espaciado.dart';

/// Contenido interno de los botones "grandes" del sistema de diseño
/// (`BotonPrimario`/`BotonSecundario`/`BotonTerciario`/`BotonDestructivo`,
/// tarea 050, ADR-0016 hallazgo 1): texto con icono opcional, o un spinner
/// pequeño mientras `cargando` es verdadero.
///
/// Antes de esta tarea el bloque `SizedBox`+`CircularProgressIndicator` se
/// escribía a mano en cada pantalla (`login_screen.dart`,
/// `boton_continuar_paso.dart`, `formulario_editar_perfil.dart`...), cada
/// vez con el mismo tamaño (20×20, `strokeWidth: 2.5`) copiado literal. Un
/// solo sitio para ese detalle es el punto de esta clase; no se expone fuera
/// de `compartido/widgets/` a propósito.
class ContenidoBoton extends StatelessWidget {
  final String texto;
  final bool cargando;
  final IconData? icono;

  /// Color del spinner mientras `cargando` es verdadero. `null` deja que
  /// [CircularProgressIndicator] use el color que le da el tema (el mismo
  /// criterio que ya corrige el contraste blanco/dorado en `AppTema`).
  final Color? colorSpinner;

  const ContenidoBoton({
    super.key,
    required this.texto,
    this.cargando = false,
    this.icono,
    this.colorSpinner,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: colorSpinner,
        ),
      );
    }
    if (icono == null) return Text(texto);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 20),
        const SizedBox(width: AppEspaciado.sm),
        Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
