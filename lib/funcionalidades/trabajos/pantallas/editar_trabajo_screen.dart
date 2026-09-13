import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../compartido/modelos/publicacion.dart';
import '../../../compartido/datos/datos_empleador.dart';
import '../datos/publicacion_service.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/textos/mensajes_error.dart';
import '../../../compartido/widgets/custom_dropdown.dart';
import '../../../compartido/widgets/custom_textfield.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import 'widgets/selector_tarifa.dart';

/// Edición de una publicación ya guardada (`PUT /api/trabajos/{id}`, tarea
/// 041, contraparte de la 040 en el backend).
///
/// Solo se llega aquí con el trabajo `activo` — `DetalleTrabajoScreen` ya
/// condiciona el botón "Editar trabajo" a eso, y el servidor lo vuelve a
/// comprobar por su cuenta: en cuanto hay un postulante elegido, el trabajo
/// pasa a `asignado` y guardar responde `409` (ver
/// `PublicacionService.actualizarPublicacion`). Ese caso se enseña como
/// cualquier otro error del formulario: el usuario se queda en la pantalla
/// con el mensaje del servidor, en vez de perder lo que escribió.
///
/// Solo viajan los ocho campos que el backend acepta en el `PUT`
/// (`Publicacion.aJson()`): título, descripción, categoría, presupuesto y
/// plazo salen del formulario; ubicación, estado, id y todo lo del contrato
/// (escrow, calificaciones...) se copian sin tocar de [publicacion] — esta
/// pantalla no expone edición de ubicación (ver tarea 041, "qué NO es").
class EditarTrabajoScreen extends StatefulWidget {
  final Publicacion publicacion;
  const EditarTrabajoScreen({super.key, required this.publicacion});

  @override
  State<EditarTrabajoScreen> createState() => _EditarTrabajoScreenState();
}

class _EditarTrabajoScreenState extends State<EditarTrabajoScreen> {
  final _form = GlobalKey<FormState>();
  late final _servicio = context.read<PublicacionService>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _presupuestoCtrl;
  late String? _categoria;
  late String _plazo;
  late String _unidadTarifa;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.publicacion;
    _tituloCtrl = TextEditingController(text: p.titulo);
    _descripcionCtrl = TextEditingController(text: p.descripcion);
    _presupuestoCtrl = TextEditingController(
        text: p.presupuesto.replaceAll(RegExp(r'[^0-9]'), ''));
    _categoria = DatosEmpleador.sectores.contains(p.categoria) ? p.categoria : null;
    _plazo = p.plazo.isNotEmpty ? p.plazo : 'Corto plazo';
    _unidadTarifa = _detectarUnidad(p.presupuesto);
  }

  /// Solo para prellenar el selector con lo que ya traía el texto libre de
  /// `presupuesto` (p. ej. `'L. 350/hora'`) — best effort, no un parser
  /// estricto: si no reconoce nada, cae en "hora" (la única unidad que
  /// existía antes de esta tarea).
  static String _detectarUnidad(String presupuesto) {
    if (presupuesto.contains('contratación')) return 'contratación completa';
    for (final u in DatosEmpleador.unidadesTarifa) {
      if (presupuesto.contains('/$u')) return u;
    }
    return 'hora';
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _presupuestoCtrl.dispose();
    super.dispose();
  }

  /// Arma la `Publicacion` que se manda al servidor: los cinco campos del
  /// formulario, y todo lo demás (ubicación, estado, id, contrato/escrow,
  /// calificaciones) copiado sin tocar de [Publicacion.aJson] — que de todas
  /// formas solo manda los ocho campos editables, pero construir el objeto
  /// completo evita reinventar un `Map` a mano (tarea 041).
  Publicacion _publicacionEditada() {
    final p = widget.publicacion;
    return Publicacion(
      id: p.id,
      uidEmpleador: p.uidEmpleador,
      autor: p.autor,
      categoria: _categoria ?? '',
      titulo: _tituloCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      departamento: p.departamento,
      ciudad: p.ciudad,
      zona: p.zona,
      presupuesto: SelectorTarifa.formatearPresupuesto(
          _presupuestoCtrl.text.trim(), _unidadTarifa),
      plazo: _plazo,
      fechaCreacion: p.fechaCreacion,
      estado: p.estado,
      uidTrabajadorAsignado: p.uidTrabajadorAsignado,
      nombreTrabajadorAsignado: p.nombreTrabajadorAsignado,
      calificadoPorEmpleador: p.calificadoPorEmpleador,
      calificadoPorTrabajador: p.calificadoPorTrabajador,
      montoAcordado: p.montoAcordado,
      tiempoAcordado: p.tiempoAcordado,
      fechaAcuerdo: p.fechaAcuerdo,
      fechaInicio: p.fechaInicio,
      pagoRetenido: p.pagoRetenido,
      entregado: p.entregado,
      pagoLiberado: p.pagoLiberado,
      correccionSolicitada: p.correccionSolicitada,
      motivoCorreccion: p.motivoCorreccion,
    );
  }

  /// Guarda los cambios. Si el servidor responde `409` (alguien aceptó una
  /// postulación mientras el empleador tenía el formulario abierto), se
  /// enseña ese mensaje y **se deja el formulario como está** — con foco en
  /// que el usuario no pierda lo que escribió y pueda decidir (cerrar la
  /// pantalla y ver el estado real del trabajo, o reintentar si fue un error
  /// pasajero). No se navega a ciegas: quien vuelve al detalle sabe por qué.
  Future<void> _guardar() async {
    if (_cargando) return;
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);

    final error = await _servicio.actualizarPublicacion(_publicacionEditada());
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    mostrarSnackBar(context, 'Cambios guardados');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar trabajo', style: Theme.of(context).textTheme.titulo),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppEspaciado.xl),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _tituloCtrl,
                  label: 'Título *',
                  iconoInicio: Icons.title_rounded,
                  maxLength: 50,
                  validador: (v) => (v == null || v.trim().isEmpty)
                      ? MensajesError.campoObligatorio : null,
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
                const SizedBox(height: AppEspaciado.xl),
                ElevatedButton(
                  onPressed: _cargando ? null : _guardar,
                  child: _cargando
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Guardar cambios'),
                ),
                const SizedBox(height: AppEspaciado.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
