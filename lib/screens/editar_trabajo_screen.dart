import 'package:flutter/material.dart';
import '../models/publicacion.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';

/// Permite al contratista editar una publicación activa.
class EditarTrabajoScreen extends StatefulWidget {
  final Publicacion publicacion;
  const EditarTrabajoScreen({super.key, required this.publicacion});

  @override
  State<EditarTrabajoScreen> createState() => _EditarTrabajoScreenState();
}

class _EditarTrabajoScreenState extends State<EditarTrabajoScreen> {
  final _form = GlobalKey<FormState>();
  final _servicio = PublicacionService();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _presupuestoCtrl;
  late String? _categoria;
  late String _plazo;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.publicacion;
    _tituloCtrl = TextEditingController(text: p.titulo);
    _descripcionCtrl = TextEditingController(text: p.descripcion);
    _presupuestoCtrl = TextEditingController(text: p.presupuesto);
    _categoria = DatosEmpleador.sectores.contains(p.categoria) ? p.categoria : null;
    _plazo = p.plazo.isNotEmpty ? p.plazo : 'Corto plazo';
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _presupuestoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_cargando) return;
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    final err = await _servicio.actualizarPublicacion(widget.publicacion.id, {
      'titulo': _tituloCtrl.text.trim(),
      'categoria': _categoria ?? '',
      'plazo': _plazo,
      'descripcion': _descripcionCtrl.text.trim(),
      'presupuesto': _presupuestoCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _cargando = false);
    if (err != null) {
      mostrarSnackBar(context, err, esError: true);
      return;
    }
    mostrarSnackBar(context, 'Trabajo actualizado');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar trabajo',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _tituloCtrl,
                  label: 'Título *',
                  iconoInicio: Icons.title_rounded,
                  validador: (v) => (v == null || v.trim().isEmpty)
                      ? MensajesError.campoObligatorio : null,
                ),
                const SizedBox(height: 14),
                CustomDropdown(
                  label: 'Categoría *',
                  valor: _categoria,
                  opciones: DatosEmpleador.sectores,
                  icono: Icons.category_outlined,
                  alCambiar: (v) => setState(() => _categoria = v),
                  validador: (v) => (v == null || v.isEmpty)
                      ? MensajesError.campoObligatorio : null,
                ),
                const SizedBox(height: 16),
                Text('Plazo de contratación',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorTextoFuerte(context))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: DatosEmpleador.plazos.map((p) {
                    final activo = _plazo == p;
                    return ChoiceChip(
                      label: Text(p),
                      selected: activo,
                      onSelected: (_) => setState(() => _plazo = p),
                      labelStyle: TextStyle(
                          color: activo ? Colors.white : colorTextoFuerte(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      selectedColor: AppColores.acento,
                      backgroundColor: colorSuperficie(context),
                      side: BorderSide(
                          color: activo ? AppColores.acento : colorBorde(context)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _descripcionCtrl,
                  label: 'Descripción *',
                  maxLines: 5,
                  maxLength: 600,
                  validador: (v) => (v == null || v.trim().isEmpty)
                      ? MensajesError.campoObligatorio : null,
                ),
                const SizedBox(height: 4),
                CustomTextField(
                  controller: _presupuestoCtrl,
                  label: 'Presupuesto (opcional)',
                  iconoInicio: Icons.payments_outlined,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _cargando ? null : _guardar,
                  child: _cargando
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
