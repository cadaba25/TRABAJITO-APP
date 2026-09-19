import 'package:flutter/material.dart';

import '../../../../../compartido/widgets/boton_primario.dart';

/// Botón primario de "avanzar" de un paso de registro: texto o spinner
/// mientras `cargando` es verdadero. El mismo bloque
/// (`ElevatedButton` + `SizedBox`/`CircularProgressIndicator`) se repetía
/// literal 8 veces entre los dos registros (uno por paso) antes de esta
/// tarea (ADR-0016, tarea 033). Desde la tarea 050 delega el estilo en
/// [BotonPrimario], que es el componente compartido del sistema de botones.
///
/// **Decisión de comportamiento (para no cambiarlo sin querer, y lo que
/// cambió al pasar por [BotonPrimario]):** antes [onPresionar] era
/// exactamente lo que se le pasaba a `onPressed`, sin gatear aquí por
/// [cargando] — los pasos 4 y 5 del registro de trabajador pasaban
/// `puedeAvanzar ? _avanzar : null` **sin** mirar `_cargando` (el botón se
/// veía habilitado mientras cargaba, solo cambiaba a spinner; el reintento
/// doble ya lo bloqueaba `_avanzar()` con su `if (_cargando) return`).
/// [BotonPrimario] fuerza `onPressed` a `null` mientras `cargando` es
/// verdadero (parte de su contrato, tarea 050): en esos dos pasos el botón
/// ahora también se ve desactivado durante la carga, no solo con el
/// spinner — una capa extra de protección contra el doble toque, no una
/// pérdida de funcionalidad. Los pasos 1 y 2 no cambian: ya pasaban
/// `_cargando ? null : _avanzar`.
class BotonContinuarPaso extends StatelessWidget {
  final bool cargando;
  final VoidCallback? onPresionar;
  final String etiqueta;

  const BotonContinuarPaso({
    super.key,
    required this.cargando,
    required this.onPresionar,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return BotonPrimario(
      texto: etiqueta,
      cargando: cargando,
      onPressed: onPresionar,
    );
  }
}
