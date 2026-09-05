import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/publicacion.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';

/// Edición de una publicación. **Hoy no se puede guardar.**
///
/// El backend no expone `PUT` ni `PATCH` sobre `/api/trabajos/{id}`
/// (comprobado contra el servidor el 2026-09-04), así que desde la migración
/// de la tarea 026 esta pantalla no puede hacer lo que promete su título.
///
/// Se decidió **dejarla, avisando arriba y con el botón desactivado**, en vez
/// de quitarla o de dejar que el usuario rellene el formulario para recibir un
/// error al final:
///
/// - Quitarla escondería que la app perdió una capacidad que tenía.
/// - Dejar el botón activo sería hacerle escribir para nada.
/// - Los campos siguen rellenos y se pueden copiar, que es justo lo que hace
///   falta para volver a publicar el trabajo corregido.
///
/// Cuando el backend tenga el endpoint, esto vuelve a ser una pantalla normal:
/// basta con reactivar el botón y devolverle su implementación a
/// `PublicacionService.actualizarPublicacion`.
class EditarTrabajoScreen extends StatefulWidget {
  final Publicacion publicacion;
  const EditarTrabajoScreen({super.key, required this.publicacion});

  @override
  State<EditarTrabajoScreen> createState() => _EditarTrabajoScreenState();
}

class _EditarTrabajoScreenState extends State<EditarTrabajoScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _presupuestoCtrl;
  late String? _categoria;
  late String _plazo;

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
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _presupuestoCtrl.dispose();
    super.dispose();
  }

  /// El aviso que sustituye al formulario que sí guardaba. Mismo lenguaje
  /// visual que el aviso de "sin conexión" de la pestaña Perfil (tarea 023):
  /// amarillo de advertencia, no rojo de error — no es que algo haya fallado,
  /// es que todavía no existe.
  Widget _avisoNoSePuedeEditar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColores.advertencia.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColores.advertencia.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_off_outlined,
              size: 20, color: AppColores.advertencia),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Todavía no se puede editar un trabajo publicado',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorTextoFuerte(context))),
                const SizedBox(height: 2),
                Text(
                    'Puedes copiar lo de aquí abajo, cerrar la publicación y '
                    'volver a publicarla corregida.',
                    style: TextStyle(
                        fontSize: 12, color: colorTextoSuave(context))),
              ],
            ),
          ),
        ],
      ),
    );
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
                _avisoNoSePuedeEditar(),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _tituloCtrl,
                  label: 'Título *',
                  iconoInicio: Icons.title_rounded,
                  maxLength: 50,
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
                  label: 'Pago por hora en Lempiras (opcional)',
                  hint: 'Solo el monto, p. ej. 150',
                  iconoInicio: Icons.payments_outlined,
                  tipoTeclado: TextInputType.number,
                  formateadores: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 28),
                // Desactivado a propósito: no hay endpoint al que mandarlo.
                // Ver la documentación de la clase.
                const ElevatedButton(
                  onPressed: null,
                  child: Text('Guardar cambios'),
                ),
                const SizedBox(height: 10),
                Text(MensajesError.sinEdicionDeTrabajo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: colorTextoSuave(context))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
