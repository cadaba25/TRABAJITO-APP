import 'package:flutter/material.dart';
import '../../../../../compartido/datos/datos_honduras.dart';
import '../../../../../compartido/widgets/botones_si_no.dart';
import '../../../../../compartido/widgets/custom_textfield.dart';
import '../../../../../compartido/widgets/entrada_etiquetas.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/textos/mensajes_error.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';
import '../registro/boton_continuar_paso.dart';
import '../registro/titulo_paso_registro.dart';

/// Paso 4 del registro de trabajador: habilidades y experiencia laboral.
/// Extraído de `registro_trabajador_screen.dart` (ADR-0016, tarea 033).
class PasoExperienciaTrabajador extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<String> habilidades;
  final bool? trabajaActualmente;
  final ValueChanged<bool> alCambiarTrabajaActualmente;
  final bool? hasTrabajado;
  final ValueChanged<bool> alCambiarHasTrabajado;
  final TextEditingController empresaCtrl;
  final TextEditingController puestoCtrl;
  final TextEditingController habilidadesCtrl;
  final TextEditingController descripcionCtrl;
  final TextEditingController fInicioExpCtrl;
  final TextEditingController fFinExpCtrl;
  final bool cargando;
  final VoidCallback onAvanzar;

  const PasoExperienciaTrabajador({
    super.key,
    required this.formKey,
    required this.habilidades,
    required this.trabajaActualmente,
    required this.alCambiarTrabajaActualmente,
    required this.hasTrabajado,
    required this.alCambiarHasTrabajado,
    required this.empresaCtrl,
    required this.puestoCtrl,
    required this.habilidadesCtrl,
    required this.descripcionCtrl,
    required this.fInicioExpCtrl,
    required this.fFinExpCtrl,
    required this.cargando,
    required this.onAvanzar,
  });

  @override
  Widget build(BuildContext context) {
    final puedeAvanzar = trabajaActualmente != null;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppEspaciado.lg),
          const TituloPasoRegistro('Tus habilidades'),
          const SizedBox(height: AppEspaciado.xs),
          Text(
            'Agrega lo que sabes hacer. Esto ayuda a que te encuentren.',
            style: Theme.of(context)
                .textTheme
                .cuerpo
                .copyWith(color: colorTextoSuave(context)),
          ),
          const SizedBox(height: AppEspaciado.lg),
          EntradaEtiquetas(
            etiquetas: habilidades,
            sugerencias: DatosHonduras.habilidadesSugeridas,
            etiquetaCampo: 'Agregar habilidad',
          ),
          const SizedBox(height: AppEspaciado.xl),
          const TituloPasoRegistro('Añadir experiencia'),
          const SizedBox(height: AppEspaciado.xl),
          BotonesSiNo(
            pregunta: '¿Estás trabajando actualmente?',
            valorActual: trabajaActualmente,
            alCambiar: alCambiarTrabajaActualmente,
          ),
          if (trabajaActualmente == false) ...[
            const SizedBox(height: AppEspaciado.lg),
            BotonesSiNo(
              pregunta: '¿Has trabajado anteriormente?',
              valorActual: hasTrabajado,
              alCambiar: alCambiarHasTrabajado,
            ),
          ],
          if (trabajaActualmente == true ||
              (trabajaActualmente == false && hasTrabajado == true)) ...[
            const SizedBox(height: AppEspaciado.lg),
            CustomTextField(
              controller: empresaCtrl,
              label: 'Nombre de la empresa *',
              iconoInicio: Icons.business_outlined,
              validador: (v) => (v == null || v.trim().isEmpty)
                  ? MensajesError.campoObligatorio
                  : null,
            ),
            const SizedBox(height: AppEspaciado.md),
            CustomTextField(
              controller: puestoCtrl,
              label: 'Puesto / Cargo *',
              iconoInicio: Icons.work_outline,
              validador: (v) => (v == null || v.trim().isEmpty)
                  ? MensajesError.campoObligatorio
                  : null,
            ),
            const SizedBox(height: AppEspaciado.md),
            CustomTextField(
              controller: habilidadesCtrl,
              label: 'Habilidades (opcional)',
              hint: 'p. ej. Excel, atención al cliente',
              iconoInicio: Icons.star_outline,
            ),
            const SizedBox(height: AppEspaciado.md),
            CustomTextField(
              controller: descripcionCtrl,
              label: 'Descripción del puesto (opcional)',
              hint: 'Describe tus funciones y logros...',
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: AppEspaciado.md),
            CustomTextField(
              controller: fInicioExpCtrl,
              label: 'Fecha de inicio * (MM/AAAA)',
              hint: '01/2022',
              iconoInicio: Icons.calendar_today_outlined,
              tipoTeclado: TextInputType.datetime,
              validador: (v) => (v == null || v.trim().isEmpty)
                  ? MensajesError.campoObligatorio
                  : null,
            ),
            if (trabajaActualmente == false) ...[
              const SizedBox(height: AppEspaciado.md),
              CustomTextField(
                controller: fFinExpCtrl,
                label: 'Fecha de fin * (MM/AAAA)',
                hint: '06/2023',
                iconoInicio: Icons.calendar_today_outlined,
                tipoTeclado: TextInputType.datetime,
                validador: (v) => (v == null || v.trim().isEmpty)
                    ? MensajesError.campoObligatorio
                    : null,
              ),
            ],
          ],
          const SizedBox(height: AppEspaciado.xxl),
          BotonContinuarPaso(
            cargando: cargando,
            onPresionar: puedeAvanzar ? onAvanzar : null,
            etiqueta: 'Siguiente',
          ),
          const SizedBox(height: AppEspaciado.xxl),
        ],
      ),
    );
  }
}
