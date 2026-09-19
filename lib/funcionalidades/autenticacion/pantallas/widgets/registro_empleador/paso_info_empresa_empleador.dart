import 'package:flutter/material.dart';
import '../../../../../compartido/datos/datos_empleador.dart';
import '../../../../../compartido/widgets/custom_dropdown.dart';
import '../../../../../compartido/widgets/custom_textfield.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/textos/mensajes_error.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';
import '../registro/boton_continuar_paso.dart';
import '../registro/titulo_paso_registro.dart';

/// Paso 3 (solo empresas) del registro de empleador: sector, tamaño, sitio
/// web y descripción. Extraído de `registro_empleador_screen.dart`
/// (ADR-0016, tarea 033).
class PasoInfoEmpresaEmpleador extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? sectorEmpresa;
  final ValueChanged<String?> alCambiarSector;
  final String? tamanoEmpresa;
  final ValueChanged<String?> alCambiarTamano;
  final TextEditingController sitioWebCtrl;
  final TextEditingController descripcionCtrl;
  final bool cargando;
  final VoidCallback onFinalizar;

  const PasoInfoEmpresaEmpleador({
    super.key,
    required this.formKey,
    required this.sectorEmpresa,
    required this.alCambiarSector,
    required this.tamanoEmpresa,
    required this.alCambiarTamano,
    required this.sitioWebCtrl,
    required this.descripcionCtrl,
    required this.cargando,
    required this.onFinalizar,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppEspaciado.lg),
          const TituloPasoRegistro('Sobre tu empresa'),
          const SizedBox(height: AppEspaciado.sm),
          Text(
            'Esta información ayuda a los profesionales a conocer mejor tu empresa.',
            style: Theme.of(context)
                .textTheme
                .cuerpo
                .copyWith(color: colorTextoSuave(context)),
          ),
          const SizedBox(height: AppEspaciado.xl),
          CustomDropdown(
            label: 'Sector / Rubro *',
            valor: sectorEmpresa,
            opciones: DatosEmpleador.sectores,
            icono: Icons.category_outlined,
            alCambiar: alCambiarSector,
            validador: (v) =>
                (v == null || v.isEmpty) ? MensajesError.campoObligatorio : null,
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomDropdown(
            label: 'Tamaño de la empresa *',
            valor: tamanoEmpresa,
            opciones: DatosEmpleador.tamanos,
            icono: Icons.groups_outlined,
            alCambiar: alCambiarTamano,
            validador: (v) =>
                (v == null || v.isEmpty) ? MensajesError.campoObligatorio : null,
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomTextField(
            controller: sitioWebCtrl,
            label: 'Sitio web (opcional)',
            hint: 'www.empresa.com',
            iconoInicio: Icons.language_outlined,
            tipoTeclado: TextInputType.url,
            validador: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final patron =
                  RegExp(r'^(https?:\/\/)?([\w-]+\.)+[\w-]{2,}(\/\S*)?$');
              return patron.hasMatch(v.trim())
                  ? null
                  : MensajesError.sitioWebInvalido;
            },
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomTextField(
            controller: descripcionCtrl,
            label: 'Descripción de la empresa (opcional)',
            hint: 'A qué se dedica tu empresa...',
            maxLines: 4,
            maxLength: 500,
          ),
          const SizedBox(height: AppEspaciado.xxl),
          BotonContinuarPaso(
            cargando: cargando,
            onPresionar: cargando ? null : onFinalizar,
            etiqueta: 'Finalizar registro',
          ),
          const SizedBox(height: AppEspaciado.xxl),
        ],
      ),
    );
  }
}
