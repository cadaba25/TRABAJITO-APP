import 'package:flutter/material.dart';
import '../../../../compartido/widgets/boton_primario.dart';
import '../../../../compartido/widgets/boton_texto.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Diálogo con el que el contratista pide correcciones antes de aceptar la
/// entrega (`esperando_confirmacion` → vuelve a `en_progreso`).
///
/// Extraído de `detalle_trabajo_screen.dart` en la tarea 035 (ADR-0016).
/// Devuelve el motivo escrito (puede ser cadena vacía) o `null` si se
/// cancela/descarta el diálogo. Quien llama decide qué hacer con cada caso
/// — misma lógica que antes de extraerlo, solo cambió dónde vive el
/// `TextEditingController`.
Future<String?> mostrarDialogoSolicitarCorreccion(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _DialogoSolicitarCorreccion(),
  );
}

class _DialogoSolicitarCorreccion extends StatefulWidget {
  const _DialogoSolicitarCorreccion();

  @override
  State<_DialogoSolicitarCorreccion> createState() =>
      _DialogoSolicitarCorreccionState();
}

class _DialogoSolicitarCorreccionState
    extends State<_DialogoSolicitarCorreccion> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
      title: Text('Solicitar correcciones',
          style: Theme.of(context)
              .textTheme
              .subtitulo
              .copyWith(color: colorTextoFuerte(context))),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        decoration:
            const InputDecoration(labelText: '¿Qué falta o hay que corregir?'),
      ),
      actions: [
        BotonTexto(
          texto: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        BotonPrimario(
          texto: 'Enviar',
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
        ),
      ],
    );
  }
}
