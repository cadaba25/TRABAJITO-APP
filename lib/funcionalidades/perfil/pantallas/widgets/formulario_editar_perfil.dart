import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../compartido/datos/datos_honduras.dart';
import '../../../../compartido/widgets/custom_textfield.dart';
import '../../../../compartido/widgets/entrada_etiquetas.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Formulario de "Editar perfil": los campos editables más los botones de CV y
/// contraseña.
///
/// Extraído de `editar_perfil_screen.dart` en la tarea 027 B-2b. No tiene
/// estado propio: recibe los controladores, la lista de habilidades (que
/// `EntradaEtiquetas` modifica en el sitio), y los callbacks. La carga del
/// perfil, la validación y el guardado siguen en el `State` de la pantalla.
class FormularioEditarPerfil extends StatelessWidget {
  final String iniciales;
  final bool esEmpleador;
  final bool cargando;

  final TextEditingController telefonoCtrl;
  final TextEditingController sitioWebCtrl;
  final TextEditingController presentacionCtrl;

  /// La misma instancia durante toda la vida de la pantalla: `EntradaEtiquetas`
  /// la modifica en el sitio.
  final List<String> habilidades;

  final VoidCallback onGuardar;
  final VoidCallback onCambiarContrasena;
  final ValueChanged<String> onProximamente;

  const FormularioEditarPerfil({
    super.key,
    required this.iniciales,
    required this.esEmpleador,
    required this.cargando,
    required this.telefonoCtrl,
    required this.sitioWebCtrl,
    required this.presentacionCtrl,
    required this.habilidades,
    required this.onGuardar,
    required this.onCambiarContrasena,
    required this.onProximamente,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppEspaciado.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foto de perfil (requiere Firebase Storage — próximamente)
            Center(
              child: GestureDetector(
                onTap: () => onProximamente('El cambio de foto'),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor:
                          AppColores.acento.withValues(alpha: 0.15),
                      child: Text(iniciales,
                          style: tt.tituloGrande.copyWith(color: AppColores.acento)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(AppEspaciado.sm),
                      decoration: const BoxDecoration(
                          color: AppColores.acento, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppEspaciado.xl),

            CustomTextField(
              controller: telefonoCtrl,
              label: 'Teléfono',
              iconoInicio: Icons.phone_outlined,
              tipoTeclado: TextInputType.phone,
              formateadores: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: AppEspaciado.lg),

            CustomTextField(
              controller: presentacionCtrl,
              label: esEmpleador
                  ? 'Descripción de la empresa'
                  : 'Presentación / sobre mí',
              hint: esEmpleador
                  ? 'A qué se dedica tu empresa...'
                  : 'Cuéntales a los contratistas por qué elegirte...',
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: AppEspaciado.lg),

            if (esEmpleador) ...[
              CustomTextField(
                controller: sitioWebCtrl,
                label: 'Sitio web (opcional)',
                hint: 'www.empresa.com',
                iconoInicio: Icons.language_outlined,
                tipoTeclado: TextInputType.url,
              ),
              const SizedBox(height: AppEspaciado.lg),
            ] else ...[
              Text('Habilidades',
                  style: tt.cuerpoChico.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorTextoFuerte(context))),
              const SizedBox(height: AppEspaciado.md),
              EntradaEtiquetas(
                etiquetas: habilidades,
                sugerencias: DatosHonduras.habilidadesSugeridas,
              ),
              const SizedBox(height: AppEspaciado.lg),
              OutlinedButton.icon(
                onPressed: () => onProximamente('La actualización de CV'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Cambiar CV'),
              ),
              const SizedBox(height: AppEspaciado.md),
            ],

            OutlinedButton.icon(
              onPressed: onCambiarContrasena,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Cambiar contraseña'),
            ),
            const SizedBox(height: AppEspaciado.xl),

            ElevatedButton(
              onPressed: cargando ? null : onGuardar,
              child: cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Guardar cambios'),
            ),
            const SizedBox(height: AppEspaciado.sm),
            Text(
              'La foto de perfil y el CV requieren almacenamiento (Firebase '
              'Storage), que se habilitará más adelante.',
              style: tt.etiqueta.copyWith(
                  color: colorTextoSuave(context), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
