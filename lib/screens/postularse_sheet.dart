import 'package:flutter/material.dart';
import '../models/postulacion.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
import '../services/postulacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';

/// Muestra el modal para postularse a un trabajo.
/// Devuelve true si la postulación se envió.
Future<bool?> mostrarPostularseSheet(
  BuildContext context, {
  required Publicacion publicacion,
  required Usuario usuario,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostularseSheet(publicacion: publicacion, usuario: usuario),
  );
}

class _PostularseSheet extends StatefulWidget {
  final Publicacion publicacion;
  final Usuario usuario;
  const _PostularseSheet({required this.publicacion, required this.usuario});

  @override
  State<_PostularseSheet> createState() => _PostularseSheetState();
}

class _PostularseSheetState extends State<_PostularseSheet> {
  final _mensajeCtrl = TextEditingController();
  final _servicio = PostulacionService();
  bool _cargando = false;

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    final postulacion = Postulacion(
      idPublicacion: widget.publicacion.id,
      tituloPublicacion: widget.publicacion.titulo,
      uidTrabajador: widget.usuario.uid,
      nombreTrabajador: widget.usuario.nombreCorto,
      uidEmpleador: widget.publicacion.uidEmpleador,
      mensaje: _mensajeCtrl.text.trim(),
      fechaPostulacion: DateTime.now(),
    );
    final error = await _servicio.postular(postulacion);
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
            Text('Postularme',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colorTextoFuerte(context))),
            const SizedBox(height: 4),
            Text(widget.publicacion.titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorTextoSuave(context), fontSize: 13)),
            const SizedBox(height: 18),
            CustomTextField(
              controller: _mensajeCtrl,
              label: 'Mensaje al contratador (opcional)',
              hint: 'Cuéntale por qué eres ideal para este trabajo...',
              maxLines: 4,
              maxLength: 400,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _cargando ? null : _enviar,
              child: _cargando
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Enviar postulación'),
            ),
          ],
        ),
      ),
    );
  }
}
