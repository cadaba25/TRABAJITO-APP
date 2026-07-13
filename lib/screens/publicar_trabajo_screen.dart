import 'package:flutter/material.dart';
import '../models/publicacion.dart';
import '../models/usuario.dart';
import '../services/publicacion_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';

/// Formulario para que un empleador publique un nuevo trabajo/servicio.
class PublicarTrabajoScreen extends StatefulWidget {
  final Usuario usuario;
  const PublicarTrabajoScreen({super.key, required this.usuario});

  @override
  State<PublicarTrabajoScreen> createState() => _PublicarTrabajoScreenState();
}

class _PublicarTrabajoScreenState extends State<PublicarTrabajoScreen> {
  final _form = GlobalKey<FormState>();
  final _servicio = PublicacionService();

  final _tituloCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _presupuestoCtrl = TextEditingController();
  String? _categoria;
  String? _departamento;
  String? _ciudad;
  String _plazo = 'Corto plazo';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    // Prellenar con la ubicación del empleador (si vive en Honduras).
    if (widget.usuario.viveEnHonduras) {
      if (DatosHonduras.departamentos.contains(widget.usuario.departamento)) {
        _departamento = widget.usuario.departamento;
        final ciudades =
            DatosHonduras.ciudadesPorDepartamento[_departamento] ?? [];
        if (ciudades.contains(widget.usuario.ciudad)) {
          _ciudad = widget.usuario.ciudad;
        }
      }
    }
    if (DatosEmpleador.sectores.contains(widget.usuario.sectorEmpresa)) {
      _categoria = widget.usuario.sectorEmpresa;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _presupuestoCtrl.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    if (_cargando) return;
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);

    final publicacion = Publicacion(
      uidEmpleador: widget.usuario.uid,
      autor: widget.usuario.nombreVisible,
      categoria: _categoria ?? '',
      titulo: _tituloCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      departamento: _departamento ?? '',
      ciudad: _ciudad ?? '',
      presupuesto: _presupuestoCtrl.text.trim(),
      plazo: _plazo,
      fechaCreacion: DateTime.now(),
    );

    final error = await _servicio.crearPublicacion(publicacion);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    mostrarSnackBar(context, '¡Trabajo publicado!');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar trabajo',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Describe el trabajo o servicio que necesitas.',
                  style: TextStyle(
                      color: colorTextoSuave(context), fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  controller: _tituloCtrl,
                  label: 'Título *',
                  hint: 'p. ej. Electricista para instalar lámparas',
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

                // Plazo del trabajo
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
                  hint: 'Detalla qué necesitas, cuándo y cualquier requisito...',
                  maxLines: 5,
                  maxLength: 600,
                  validador: (v) => (v == null || v.trim().isEmpty)
                      ? MensajesError.campoObligatorio : null,
                ),
                const SizedBox(height: 4),

                CustomTextField(
                  controller: _presupuestoCtrl,
                  label: 'Presupuesto (opcional)',
                  hint: 'p. ej. L. 800 o A convenir',
                  iconoInicio: Icons.payments_outlined,
                ),
                const SizedBox(height: 14),

                CustomDropdown(
                  label: 'Departamento *',
                  valor: _departamento,
                  opciones: DatosHonduras.departamentos,
                  icono: Icons.map_outlined,
                  alCambiar: (v) => setState(() {
                    _departamento = v;
                    _ciudad = null;
                  }),
                  validador: (v) => (v == null || v.isEmpty)
                      ? MensajesError.campoObligatorio : null,
                ),
                if (_departamento != null) ...[
                  const SizedBox(height: 14),
                  CustomDropdown(
                    label: 'Ciudad / Municipio *',
                    valor: _ciudad,
                    opciones:
                        DatosHonduras.ciudadesPorDepartamento[_departamento] ?? [],
                    icono: Icons.location_city_outlined,
                    alCambiar: (v) => setState(() => _ciudad = v),
                    validador: (v) => (v == null || v.isEmpty)
                        ? MensajesError.campoObligatorio : null,
                  ),
                ],

                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _cargando ? null : _publicar,
                  child: _cargando
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Publicar'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
