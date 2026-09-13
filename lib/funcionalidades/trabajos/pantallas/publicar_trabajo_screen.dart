import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/publicacion.dart';
import '../../../compartido/modelos/usuario.dart';
import '../datos/publicacion_service.dart';
import '../../../compartido/datos/datos_empleador.dart';
import '../../../compartido/datos/datos_honduras.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import '../../../compartido/widgets/custom_dropdown.dart';
import '../../../compartido/widgets/custom_textfield.dart';
import '../../../compartido/widgets/estado_exito.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import 'widgets/selector_tarifa.dart';

/// Formulario para que un empleador publique un nuevo trabajo/servicio.
class PublicarTrabajoScreen extends StatefulWidget {
  final Usuario usuario;
  const PublicarTrabajoScreen({super.key, required this.usuario});

  @override
  State<PublicarTrabajoScreen> createState() => _PublicarTrabajoScreenState();
}

class _PublicarTrabajoScreenState extends State<PublicarTrabajoScreen> {
  final _form = GlobalKey<FormState>();
  late final _servicio = context.read<PublicacionService>();

  final _tituloCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _presupuestoCtrl = TextEditingController();
  final _zonaCtrl        = TextEditingController();
  String? _categoria;
  String? _departamento;
  String? _ciudad;
  String _plazo = 'Corto plazo';
  String _unidadTarifa = 'hora';
  bool _cargando = false;

  /// `true` mientras se enseña el check de éxito (ADR-0015, fase 6), justo
  /// antes de cerrar la pantalla. Quien vuelve a "Mis publicaciones" ya
  /// ignoraba el valor de retorno del `pop` (siempre recarga), así que
  /// retrasarlo unos milisegundos no cambia nada del flujo.
  bool _exito = false;

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
    _zonaCtrl.dispose();
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
      zona: _zonaCtrl.text.trim(),
      presupuesto: SelectorTarifa.formatearPresupuesto(
          _presupuestoCtrl.text.trim(), _unidadTarifa),
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
    setState(() => _exito = true);
    await Future.delayed(duracionExitoVisible);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Publicar trabajo', style: Theme.of(context).textTheme.titulo),
      ),
      body: _exito
          ? const EstadoExito(mensaje: '¡Trabajo publicado!')
          : _formulario(),
    );
  }

  Widget _formulario() {
    return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppEspaciado.xl, vertical: AppEspaciado.lg),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Describe el trabajo o servicio que necesitas.',
                  style: Theme.of(context)
                      .textTheme
                      .cuerpo
                      .copyWith(color: colorTextoSuave(context)),
                ),
                const SizedBox(height: AppEspaciado.lg),

                CustomTextField(
                  controller: _tituloCtrl,
                  label: 'Título *',
                  hint: 'p. ej. Electricista para lámparas',
                  iconoInicio: Icons.title_rounded,
                  maxLength: 50,
                  validador: (v) {
                    if (v == null || v.trim().isEmpty) return MensajesError.campoObligatorio;
                    if (v.trim().length < 5) return 'Título muy corto';
                    return null;
                  },
                ),
                const SizedBox(height: AppEspaciado.md),

                CustomDropdown(
                  label: 'Categoría *',
                  valor: _categoria,
                  opciones: DatosEmpleador.sectores,
                  icono: Icons.category_outlined,
                  alCambiar: (v) => setState(() => _categoria = v),
                  validador: (v) => (v == null || v.isEmpty)
                      ? MensajesError.campoObligatorio : null,
                ),
                const SizedBox(height: AppEspaciado.lg),

                // Plazo del trabajo
                Text('Plazo de contratación',
                    style: Theme.of(context)
                        .textTheme
                        .cuerpoChico
                        .copyWith(fontWeight: FontWeight.w600, color: colorTextoFuerte(context))),
                const SizedBox(height: AppEspaciado.sm),
                Wrap(
                  spacing: AppEspaciado.sm,
                  children: DatosEmpleador.plazos.map((p) {
                    final activo = _plazo == p;
                    return ChoiceChip(
                      label: Text(p),
                      selected: activo,
                      onSelected: (_) => setState(() => _plazo = p),
                      labelStyle: Theme.of(context).textTheme.cuerpoChico.copyWith(
                          color: activo ? Colors.white : colorTextoFuerte(context),
                          fontWeight: FontWeight.w600),
                      selectedColor: AppColores.acento,
                      backgroundColor: colorSuperficie(context),
                      side: BorderSide(
                          color: activo ? AppColores.acento : colorBorde(context)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppEspaciado.md),

                CustomTextField(
                  controller: _descripcionCtrl,
                  label: 'Descripción *',
                  hint: 'Detalla qué necesitas, cuándo y cualquier requisito...',
                  maxLines: 5,
                  maxLength: 600,
                  validador: (v) => (v == null || v.trim().isEmpty)
                      ? MensajesError.campoObligatorio : null,
                ),
                const SizedBox(height: AppEspaciado.xs),

                SelectorTarifa(
                  controller: _presupuestoCtrl,
                  unidad: _unidadTarifa,
                  onUnidadCambia: (v) => setState(() => _unidadTarifa = v),
                ),
                const SizedBox(height: AppEspaciado.md),

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
                  const SizedBox(height: AppEspaciado.md),
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
                const SizedBox(height: AppEspaciado.md),
                CustomTextField(
                  controller: _zonaCtrl,
                  label: 'Zona / Colonia / Referencia',
                  hint: 'p. ej. Col. Kennedy, cerca del parque',
                  iconoInicio: Icons.pin_drop_outlined,
                  maxLength: 80,
                ),

                const SizedBox(height: AppEspaciado.xl),
                ElevatedButton(
                  onPressed: _cargando ? null : _publicar,
                  child: _cargando
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Publicar'),
                ),
                const SizedBox(height: AppEspaciado.xxl),
              ],
            ),
          ),
        ),
    );
  }
}

