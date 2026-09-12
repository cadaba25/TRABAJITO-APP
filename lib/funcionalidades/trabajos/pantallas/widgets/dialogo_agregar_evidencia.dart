import 'package:flutter/material.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Diálogo para que el trabajador registre un avance ("evidencia") del
/// trabajo en curso.
///
/// Extraído de `detalle_trabajo_screen.dart` en la tarea 035 (ADR-0016).
/// Devuelve el texto del avance (puede venir vacío) o `null` si se
/// cancela/descarta. Adjuntar fotos/videos sigue sin estar disponible (hace
/// falta almacenamiento de archivos, fuera de alcance — el aviso se
/// conserva tal cual).
Future<String?> mostrarDialogoAgregarEvidencia(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _DialogoAgregarEvidencia(),
  );
}

class _DialogoAgregarEvidencia extends StatefulWidget {
  const _DialogoAgregarEvidencia();

  @override
  State<_DialogoAgregarEvidencia> createState() =>
      _DialogoAgregarEvidenciaState();
}

class _DialogoAgregarEvidenciaState extends State<_DialogoAgregarEvidencia> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
      title: Text('Agregar avance',
          style: tt.subtitulo.copyWith(color: colorTextoFuerte(context))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Describe el avance realizado'),
          ),
          const SizedBox(height: AppEspaciado.sm),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: colorTextoSuave(context)),
              const SizedBox(width: AppEspaciado.xs),
              Expanded(
                child: Text(
                  'Adjuntar fotos y videos estará disponible pronto.',
                  style:
                      tt.etiqueta.copyWith(color: colorTextoSuave(context)),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Publicar'),
        ),
      ],
    );
  }
}
