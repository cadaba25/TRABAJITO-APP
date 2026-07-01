import 'package:flutter/material.dart';
import '../models/calificacion.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
import '../services/calificacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';

/// Modal para calificar al otro participante de un trabajo completado.
Future<bool?> mostrarCalificarSheet(
  BuildContext context, {
  required Publicacion publicacion,
  required Usuario calificador,
  required String paraUid,
  required String paraNombre,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CalificarSheet(
      publicacion: publicacion,
      calificador: calificador,
      paraUid: paraUid,
      paraNombre: paraNombre,
    ),
  );
}

class _CalificarSheet extends StatefulWidget {
  final Publicacion publicacion;
  final Usuario calificador;
  final String paraUid;
  final String paraNombre;
  const _CalificarSheet({
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
  final _servicio = CalificacionService();
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
    final porEmpleador = widget.calificador.esEmpleador;
    final cal = Calificacion(
      idPublicacion: widget.publicacion.id,
      deUid: widget.calificador.uid,
      deNombre: widget.calificador.nombreVisible,
      paraUid: widget.paraUid,
      rolCalificado: porEmpleador ? 'trabajador' : 'empleador',
      estrellas: _estrellas,
      comentario: _comentarioCtrl.text.trim(),
      fecha: DateTime.now(),
    );
    final error =
        await _servicio.calificar(calificacion: cal, porEmpleador: porEmpleador);
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
