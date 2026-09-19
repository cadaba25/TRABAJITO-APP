import 'package:flutter/material.dart';

import '../../nucleo/tema/app_colores.dart';
import '../../nucleo/textos/mensajes_error.dart';
import 'mostrar_snackbar.dart';

// Ejecutar una accion con un loader modal que bloquea la pantalla.
//
// Tiene archivo propio desde la tarea 027 (parte B-1) por lo de abajo: aqui
// vive un candado GLOBAL, y estaba escondido al final de un archivo llamado
// `custom_textfield.dart`.

/// Candado **global**, no por pantalla: mientras una accion corre, ninguna
/// otra pantalla puede lanzar la suya. Es a proposito —evita el doble toque y
/// las acciones duplicadas— pero es estado compartido, no un detalle.
bool _ejecutando = false;

/// Muestra un loader modal no descartable mientras corre [accion] (una
/// operación que devuelve null en éxito o un mensaje de error). El barrier
/// bloquea toques adicionales, evitando ejecuciones duplicadas por
/// multi-toque. Al terminar cierra el loader y muestra el resultado.
Future<bool> ejecutarConCarga(
  BuildContext context,
  Future<String?> Function() accion, {
  String exito = 'Listo',
  bool mostrarExito = true,
}) async {
  if (_ejecutando) return false; // guard global anti doble-ejecución
  _ejecutando = true;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColores.acento)),
  );
  String? err;
  try {
    err = await accion();
  } catch (_) {
    err = MensajesError.errorGeneral;
  } finally {
    _ejecutando = false;
  }
  if (!context.mounted) return err == null;
  Navigator.of(context, rootNavigator: true).pop(); // cierra el loader
  if (err != null) {
    mostrarSnackBar(context, err, esError: true);
  } else if (mostrarExito) {
    mostrarSnackBar(context, exito);
  }
  return err == null;
}
