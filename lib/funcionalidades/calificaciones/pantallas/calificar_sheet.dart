import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/publicacion.dart';
import '../../../compartido/modelos/usuario.dart';
import '../datos/calificacion_service.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../compartido/widgets/custom_textfield.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../nucleo/tema/colores_por_tema.dart';

/// Modal para calificar al otro participante de un trabajo completado.
Future<bool?> mostrarCalificarSheet(
  BuildContext context, {
  required Publicacion publicacion,
  required Usuario calificador,
  required String paraUid,
  required String paraNombre,
}) {
  // El servicio se lee aquí, con el contexto de quien abre la hoja, y se pasa
  // hacia dentro: así la hoja no depende de dónde cuelgue su Navigator.
  final servicio = context.read<CalificacionService>();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CalificarSheet(
      servicio: servicio,
      publicacion: publicacion,
      calificador: calificador,
      paraUid: paraUid,
      paraNombre: paraNombre,
    ),
  );
}

class _CalificarSheet extends StatefulWidget {
  final CalificacionService servicio;
  final Publicacion publicacion;
  final Usuario calificador;
  final String paraUid;
  final String paraNombre;
  const _CalificarSheet({
    required this.servicio,
    required this.publicacion,
    required this.calificador,
    required this.paraUid,
    required this.paraNombre,
  });

  @override
  State<_CalificarSheet> createState() => _CalificarSheetState();
}

class _CalificarSheetState extends State<_CalificarSheet> {
  final _comentarioCtrl = TextEditingController();
  int _estrellas = 5;
  bool _cargando = false;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    final error = await widget.servicio.calificar(
      idTrabajo: widget.publicacion.id,
      estrellas: _estrellas,
      comentario: _comentarioCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final padInf = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: padInf),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: superficie,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColores.grisMedio,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Calificar a ${widget.paraNombre}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colorTextoFuerte(context))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final valor = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _estrellas = valor),
                  icon: Icon(
                    valor <= _estrellas
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColores.dorado,
                    size: 38,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _comentarioCtrl,
              label: 'Comentario (opcional)',
              hint: '¿Cómo fue tu experiencia?',
              maxLines: 3,
              maxLength: 300,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _cargando ? null : _enviar,
              child: _cargando
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Enviar calificación'),
            ),
          ],
        ),
      ),
    );
  }
}
