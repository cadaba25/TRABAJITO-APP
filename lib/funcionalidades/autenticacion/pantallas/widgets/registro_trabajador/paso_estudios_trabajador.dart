import 'package:flutter/material.dart';
import '../../../../../compartido/datos/datos_honduras.dart';
import '../../../../../compartido/widgets/botones_si_no.dart';
import '../../../../../compartido/widgets/custom_dropdown.dart';
import '../../../../../compartido/widgets/custom_textfield.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/textos/mensajes_error.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';
import '../registro/boton_continuar_paso.dart';
import '../registro/titulo_paso_registro.dart';

/// Paso 5 (último) del registro de trabajador: estudios. Extraído de
/// `registro_trabajador_screen.dart` (ADR-0016, tarea 033).
class PasoEstudiosTrabajador extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool? tieneEstudios;
  final ValueChanged<bool> alCambiarTieneEstudios;
  final String? nivelEstudio;
  final ValueChanged<String?> alCambiarNivel;
  final TextEditingController centroCtrl;
  final TextEditingController fInicioEstCtrl;
  final TextEditingController fFinEstCtrl;
  final bool cursandoActualmente;
  final ValueChanged<bool> alCambiarCursando;
  final bool cargando;
  final VoidCallback onFinalizar;

  const PasoEstudiosTrabajador({
    super.key,
    required this.formKey,
    required this.tieneEstudios,
    required this.alCambiarTieneEstudios,
    required this.nivelEstudio,
    required this.alCambiarNivel,
    required this.centroCtrl,
    required this.fInicioEstCtrl,
    required this.fFinEstCtrl,
    required this.cursandoActualmente,
    required this.alCambiarCursando,
    required this.cargando,
    required this.onFinalizar,
  });

  @override
  Widget build(BuildContext context) {
    final puedeAvanzar = tieneEstudios != null;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppEspaciado.lg),
          const TituloPasoRegistro('Añadir estudios'),
          const SizedBox(height: AppEspaciado.xl),
          BotonesSiNo(
            pregunta: '¿Tienes estudios?',
            valorActual: tieneEstudios,
            alCambiar: alCambiarTieneEstudios,
          ),
          if (tieneEstudios == true) ...[
            const SizedBox(height: AppEspaciado.lg),
            CustomDropdown(
              label: 'Nivel de estudios *',
              valor: nivelEstudio,
              opciones: DatosHonduras.nivelesEstudio,
              icono: Icons.school_outlined,
              alCambiar: alCambiarNivel,
              validador: (v) => (v == null || v.isEmpty)
                  ? MensajesError.campoObligatorio
                  : null,
            ),
            const SizedBox(height: AppEspaciado.md),
            CustomTextField(
              controller: centroCtrl,
              label: 'Centro / Institución *',
              iconoInicio: Icons.account_balance_outlined,
              validador: (v) => (v == null || v.trim().isEmpty)
                  ? MensajesError.campoObligatorio
                  : null,
            ),
            const SizedBox(height: AppEspaciado.md),
            CustomTextField(
              controller: fInicioEstCtrl,
              label: 'Fecha de inicio * (MM/AAAA)',
              hint: '01/2018',
              iconoInicio: Icons.calendar_today_outlined,
              tipoTeclado: TextInputType.datetime,
              validador: (v) => (v == null || v.trim().isEmpty)
                  ? MensajesError.campoObligatorio
                  : null,
            ),
            const SizedBox(height: AppEspaciado.md),
            if (!cursandoActualmente)
              CustomTextField(
                controller: fFinEstCtrl,
                label: 'Fecha de fin (MM/AAAA)',
                hint: '12/2022',
                iconoInicio: Icons.calendar_today_outlined,
                tipoTeclado: TextInputType.datetime,
              ),
            const SizedBox(height: AppEspaciado.md),
            Row(
              children: [
                Checkbox(
                  value: cursandoActualmente,
                  onChanged: (v) => alCambiarCursando(v ?? false),
                ),
                Text(
                  'Cursando actualmente',
                  style: Theme.of(context)
                      .textTheme
                      .cuerpo
                      .copyWith(color: colorTextoFuerte(context)),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppEspaciado.xxl),
          BotonContinuarPaso(
            cargando: cargando,
            onPresionar: puedeAvanzar ? onFinalizar : null,
            etiqueta: 'Finalizar registro',
          ),
          const SizedBox(height: AppEspaciado.xxl),
        ],
      ),
    );
  }
}
