import 'package:flutter/material.dart';

/// Botón primario de "avanzar" de un paso de registro: texto o spinner
/// mientras `cargando` es verdadero. El mismo bloque
/// (`ElevatedButton` + `SizedBox`/`CircularProgressIndicator`) se repetía
/// literal 8 veces entre los dos registros (uno por paso) antes de esta
/// tarea (ADR-0016, tarea 033).
///
/// **Decisión de comportamiento (para no cambiarlo sin querer):** [onPresionar]
/// es exactamente lo que antes se le pasaba a `onPressed` en cada paso, sin
/// gatear aquí por [cargando]. Los pasos 1 y 2 de ambos registros ya pasaban
/// `_cargando ? null : _avanzar` (botón se deshabilita mientras carga); los
/// pasos 4 y 5 del registro de trabajador pasaban `puedeAvanzar ? _avanzar :
/// null` **sin** mirar `_cargando` (el botón se ve habilitado mientras
/// carga, solo cambia a spinner; el reintento doble ya lo bloquea
/// `_avanzar()` con su `if (_cargando) return`). Si este widget forzara
/// `cargando ? null : onPresionar` cambiaría el aspecto de esos dos pasos.
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
    return ElevatedButton(
      onPressed: onPresionar,
      child: cargando
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            )
          : Text(etiqueta),
    );
  }
}
