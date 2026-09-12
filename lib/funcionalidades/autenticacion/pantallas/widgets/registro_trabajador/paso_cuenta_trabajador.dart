import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../nucleo/dominio/reglas_cuenta.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/textos/mensajes_error.dart';
import '../../../../../compartido/widgets/custom_textfield.dart';
import '../../../../../compartido/widgets/indicador_fuerza_contrasena.dart';
import '../registro/boton_continuar_paso.dart';
import '../registro/terminos_condiciones_checkbox.dart';
import '../registro/titulo_paso_registro.dart';

/// Paso 1 del registro de trabajador: cuenta (nombres, DNI, correo,
/// contraseña, términos). Extraído de `registro_trabajador_screen.dart`
/// (ADR-0016, tarea 033) — el estado (controllers, `_cargando`,
/// `_terminosAceptados`) se queda en la pantalla; este widget solo pinta el
/// formulario y avisa con callbacks, mismo patrón que usó la tarea 027 B-2b.
class PasoCuentaTrabajador extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nombresCtrl;
  final TextEditingController apellidosCtrl;
  final TextEditingController dniCtrl;
  final TextEditingController correoCtrl;
  final TextEditingController contrasenaCtrl;
  final TextEditingController confirmarCtrl;
  final bool terminosAceptados;
  final ValueChanged<bool> alCambiarTerminos;
  final bool cargando;
  final VoidCallback onAvanzar;

  const PasoCuentaTrabajador({
    super.key,
    required this.formKey,
    required this.nombresCtrl,
    required this.apellidosCtrl,
    required this.dniCtrl,
    required this.correoCtrl,
    required this.contrasenaCtrl,
    required this.confirmarCtrl,
    required this.terminosAceptados,
    required this.alCambiarTerminos,
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
          const TituloPasoRegistro('Crea tu cuenta'),
          const SizedBox(height: AppEspaciado.xl),
          CustomTextField(
            controller: nombresCtrl,
            label: 'Nombres *',
            hint: 'Como aparece en tu documento',
            iconoInicio: Icons.person_outline,
            validador: (v) => (v == null || v.trim().isEmpty)
                ? MensajesError.campoObligatorio
                : null,
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomTextField(
            controller: apellidosCtrl,
            label: 'Apellidos *',
            iconoInicio: Icons.person_outline,
            validador: (v) => (v == null || v.trim().isEmpty)
                ? MensajesError.campoObligatorio
                : null,
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomTextField(
            controller: dniCtrl,
            label: 'DNI *',
            hint: '0801199912345',
            iconoInicio: Icons.badge_outlined,
            tipoTeclado: TextInputType.number,
            formateadores: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
            ],
            validador: (v) {
              if (v == null || v.trim().isEmpty) {
                return MensajesError.campoObligatorio;
              }
              if (v.trim().length != 13) return MensajesError.dniInvalido;
              return null;
            },
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomTextField(
            controller: correoCtrl,
            label: 'Correo electrónico *',
            hint: 'ejemplo@correo.com',
            iconoInicio: Icons.email_outlined,
            tipoTeclado: TextInputType.emailAddress,
            validador: (v) {
              if (v == null || v.trim().isEmpty) {
                return MensajesError.campoObligatorio;
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(v.trim())) {
                return MensajesError.correoInvalido;
              }
              return null;
            },
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomTextField(
            controller: contrasenaCtrl,
            label: 'Contraseña *',
            iconoInicio: Icons.lock_outline,
            esContrasena: true,
            validador: (v) {
              if (v == null || v.isEmpty) return MensajesError.campoObligatorio;
              // De 10 a 72 caracteres: lo que exige el backend (ADR-0010).
              // Pedir menos aqui haria que el usuario rellenara todos los
              // pasos para que el servidor lo rechazara al final.
              if (v.length < ReglasCuenta.contrasenaMinima) {
                return MensajesError.contrasenaMuyCorta;
              }
              if (v.length > ReglasCuenta.contrasenaMaxima) {
                return MensajesError.contrasenaMuyLarga;
              }
              return null;
            },
          ),
          ValueListenableBuilder(
            valueListenable: contrasenaCtrl,
            builder: (_, _, _) => Column(
              children: [
                const SizedBox(height: AppEspaciado.sm),
                IndicadorFuerzaContrasena(contrasena: contrasenaCtrl.text),
              ],
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          CustomTextField(
            controller: confirmarCtrl,
            label: 'Confirmar contraseña *',
            iconoInicio: Icons.lock_outline,
            esContrasena: true,
            accionTeclado: TextInputAction.done,
            validador: (v) {
              if (v == null || v.isEmpty) return MensajesError.campoObligatorio;
              if (v != contrasenaCtrl.text) {
                return MensajesError.contrasenasNoCoinc;
              }
              return null;
            },
          ),
          const SizedBox(height: AppEspaciado.lg),
          TerminosCondicionesCheckbox(
            aceptado: terminosAceptados,
            alCambiar: alCambiarTerminos,
          ),
          const SizedBox(height: AppEspaciado.xl),
          BotonContinuarPaso(
            cargando: cargando,
            onPresionar: cargando ? null : onAvanzar,
            etiqueta: 'Crear cuenta',
          ),
          const SizedBox(height: AppEspaciado.xxl),
        ],
      ),
    );
  }
}
