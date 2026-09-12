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

/// Paso 2 del registro de empleador: contacto y ubicación. Extraído de
/// `registro_empleador_screen.dart` (ADR-0016, tarea 033).
///
/// Para una persona particular (`esEmpresa == false`) este paso es el
/// último ("Finalizar registro"); para una empresa hay un paso 3 más
/// ("Guardar y continuar") — la misma regla que ya tenía la pantalla, sin
/// cambios de comportamiento.
class PasoContactoEmpleador extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool esEmpresa;
  final TextEditingController diaCtrl;
  final TextEditingController mesCtrl;
  final TextEditingController anioCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController telAltCtrl;
  final TextEditingController cpCtrl;
  final String? departamento;
  final ValueChanged<String?> alCambiarDepartamento;
  final String? ciudad;
  final ValueChanged<String?> alCambiarCiudad;
  final bool cargando;
  final VoidCallback onAvanzar;

  const PasoContactoEmpleador({
    super.key,
    required this.formKey,
    required this.esEmpresa,
    required this.diaCtrl,
    required this.mesCtrl,
    required this.anioCtrl,
    required this.telefonoCtrl,
    required this.telAltCtrl,
    required this.cpCtrl,
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
          const TituloPasoRegistro('Datos de contacto'),
          const SizedBox(height: AppEspaciado.xl),
          CampoFechaNacimiento(diaCtrl: diaCtrl, mesCtrl: mesCtrl, anioCtrl: anioCtrl),
          const SizedBox(height: AppEspaciado.lg),
          CustomTextField(
            controller: telefonoCtrl,
            label: esEmpresa ? 'Teléfono de la empresa *' : 'Teléfono *',
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
            controller: telAltCtrl,
            label: 'Teléfono alternativo (opcional)',
            iconoInicio: Icons.phone_in_talk_outlined,
            tipoTeclado: TextInputType.phone,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
            validador: (v) {
              if (v != null && v.trim().isNotEmpty && v.trim().length < 8) {
                return MensajesError.telefonoInvalido;
              }
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
            etiqueta: esEmpresa ? 'Guardar y continuar' : 'Finalizar registro',
          ),
          const SizedBox(height: AppEspaciado.xxl),
        ],
      ),
    );
  }
}
