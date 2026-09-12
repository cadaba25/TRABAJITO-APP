import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../nucleo/dominio/reglas_cuenta.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/textos/mensajes_error.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';
import '../../../../../compartido/widgets/custom_textfield.dart';
import '../../../../../compartido/widgets/indicador_fuerza_contrasena.dart';
import '../registro/boton_continuar_paso.dart';
import '../registro/terminos_condiciones_checkbox.dart';
import '../registro/titulo_paso_registro.dart';
import 'tarjeta_tipo_empleador.dart';

/// Paso 1 del registro de empleador: tipo (persona/empresa) y cuenta.
/// Extraído de `registro_empleador_screen.dart` (ADR-0016, tarea 033).
class PasoCuentaEmpleador extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool esEmpresa;
  final ValueChanged<bool> alCambiarTipo;
  final TextEditingController nombreEmpresaCtrl;
  final TextEditingController rtnCtrl;
  final TextEditingController cargoCtrl;
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

  const PasoCuentaEmpleador({
    super.key,
    required this.formKey,
    required this.esEmpresa,
    required this.alCambiarTipo,
    required this.nombreEmpresaCtrl,
    required this.rtnCtrl,
    required this.cargoCtrl,
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
          const SizedBox(height: AppEspaciado.sm),
          Text(
            'Cuéntanos quién contratará en Trabajito.',
            style: Theme.of(context)
                .textTheme
                .cuerpo
                .copyWith(color: colorTextoSuave(context)),
          ),
          const SizedBox(height: AppEspaciado.xl),
          Row(
            children: [
              Expanded(
                child: TarjetaTipoEmpleador(
                  titulo: 'Persona',
                  descripcion: 'Contrato para mí o mi hogar',
                  icono: Icons.person_outline,
                  seleccionado: !esEmpresa,
                  onTap: () => alCambiarTipo(false),
                ),
              ),
              const SizedBox(width: AppEspaciado.md),
              Expanded(
                child: TarjetaTipoEmpleador(
                  titulo: 'Empresa',
                  descripcion: 'Contrato en nombre de un negocio',
                  icono: Icons.business_outlined,
                  seleccionado: esEmpresa,
                  onTap: () => alCambiarTipo(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.xl),
          if (esEmpresa) ...[
            CustomTextField(
              controller: nombreEmpresaCtrl,
              label: 'Nombre de la empresa *',
              iconoInicio: Icons.business_outlined,
              validador: (v) => (v == null || v.trim().isEmpty)
                  ? MensajesError.campoObligatorio
                  : null,
            ),
            const SizedBox(height: AppEspaciado.md),
            CustomTextField(
              controller: rtnCtrl,
              label: 'RTN (opcional)',
              hint: '08011985123456',
              iconoInicio: Icons.badge_outlined,
              tipoTeclado: TextInputType.number,
              formateadores: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: AppEspaciado.md),
            Text(
              'Datos de la persona de contacto',
              style: Theme.of(context).textTheme.cuerpoChico.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorTextoFuerte(context)),
            ),
            const SizedBox(height: AppEspaciado.md),
          ],
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
          if (esEmpresa) ...[
            const SizedBox(height: AppEspaciado.md),
            CustomTextField(
              controller: cargoCtrl,
              label: 'Cargo en la empresa (opcional)',
              hint: 'p. ej. Gerente, Propietario',
              iconoInicio: Icons.work_outline,
            ),
          ],
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
