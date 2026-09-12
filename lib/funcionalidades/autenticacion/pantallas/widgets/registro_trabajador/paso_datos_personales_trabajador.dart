import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../compartido/datos/datos_honduras.dart';
import '../../../../../compartido/widgets/custom_dropdown.dart';
import '../../../../../compartido/widgets/custom_textfield.dart';
import '../../../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/textos/mensajes_error.dart';
import '../registro/boton_continuar_paso.dart';
import '../registro/campo_fecha_nacimiento.dart';
import '../registro/selector_pais_honduras.dart';
import '../registro/titulo_paso_registro.dart';

/// Paso 2 del registro de trabajador: datos personales (fecha de
/// nacimiento, género, teléfonos, ubicación). Extraído de
/// `registro_trabajador_screen.dart` (ADR-0016, tarea 033).
class PasoDatosPersonalesTrabajador extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController diaCtrl;
  final TextEditingController mesCtrl;
  final TextEditingController anioCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController telEmergCtrl;
  final TextEditingController cpCtrl;
  final String? genero;
  final ValueChanged<String?> alCambiarGenero;
  final String? departamento;
  final ValueChanged<String?> alCambiarDepartamento;
  final String? ciudad;
  final ValueChanged<String?> alCambiarCiudad;
  final bool cargando;
  final VoidCallback onAvanzar;

  const PasoDatosPersonalesTrabajador({
    super.key,
    required this.formKey,
    required this.diaCtrl,
    required this.mesCtrl,
    required this.anioCtrl,
    required this.telefonoCtrl,
    required this.telEmergCtrl,
    required this.cpCtrl,
    required this.genero,
    required this.alCambiarGenero,
    required this.departamento,
    required this.alCambiarDepartamento,
    required this.ciudad,
    required this.alCambiarCiudad,
    required this.cargando,
    required this.onAvanzar,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppEspaciado.lg),
          const TituloPasoRegistro('Datos Personales'),
          const SizedBox(height: AppEspaciado.xl),
          CampoFechaNacimiento(diaCtrl: diaCtrl, mesCtrl: mesCtrl, anioCtrl: anioCtrl),
          const SizedBox(height: AppEspaciado.lg),
          CustomDropdown(
            label: 'Género (opcional)',
            valor: genero,
            opciones: DatosHonduras.generos,
            icono: Icons.wc_outlined,
            alCambiar: alCambiarGenero,
          ),
          const SizedBox(height: AppEspaciado.lg),
          CustomTextField(
            controller: telefonoCtrl,
            label: 'Teléfono personal *',
            iconoInicio: Icons.phone_outlined,
            tipoTeclado: TextInputType.phone,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
            validador: (v) {
              if (v == null || v.trim().isEmpty) {
                return MensajesError.campoObligatorio;
              }
              if (v.trim().length < 8) return MensajesError.telefonoInvalido;
              return null;
            },
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomTextField(
            controller: telEmergCtrl,
            label: 'Teléfono de emergencia *',
            iconoInicio: Icons.phone_in_talk_outlined,
            tipoTeclado: TextInputType.phone,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
            validador: (v) {
              if (v == null || v.trim().isEmpty) {
                return MensajesError.campoObligatorio;
              }
              if (v.trim().length < 8) return MensajesError.telefonoInvalido;
              return null;
            },
          ),
          const SizedBox(height: AppEspaciado.lg),
          SelectorPaisHonduras(
              alTocarFuera: () =>
                  mostrarSnackBar(context, MensajesError.soloHonduras)),
          const SizedBox(height: AppEspaciado.lg),
          CustomTextField(
            controller: cpCtrl,
            label: 'Código postal',
            iconoInicio: Icons.markunread_mailbox_outlined,
            tipoTeclado: TextInputType.number,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomDropdown(
            label: 'Departamento *',
            valor: departamento,
            opciones: DatosHonduras.departamentos,
            icono: Icons.map_outlined,
            alCambiar: alCambiarDepartamento,
            validador: (v) =>
                (v == null || v.isEmpty) ? MensajesError.campoObligatorio : null,
          ),
          if (departamento != null) ...[
            const SizedBox(height: AppEspaciado.md),
            CustomDropdown(
              label: 'Ciudad / Municipio *',
              valor: ciudad,
              opciones: DatosHonduras.ciudadesPorDepartamento[departamento] ?? [],
              icono: Icons.location_city_outlined,
              alCambiar: alCambiarCiudad,
              validador: (v) => (v == null || v.isEmpty)
                  ? MensajesError.campoObligatorio
                  : null,
            ),
          ],
          const SizedBox(height: AppEspaciado.xxl),
          BotonContinuarPaso(
            cargando: cargando,
            onPresionar: cargando ? null : onAvanzar,
            etiqueta: 'Guardar y continuar',
          ),
          const SizedBox(height: AppEspaciado.xxl),
        ],
      ),
    );
  }
}
