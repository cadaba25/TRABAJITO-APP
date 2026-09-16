import 'package:flutter/material.dart';
import '../../../../../compartido/widgets/boton_primario.dart';
import '../../../../../compartido/widgets/boton_secundario.dart';
import '../../../../../compartido/widgets/boton_texto.dart';
import '../../../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/tema/app_colores.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';
import '../registro/titulo_paso_registro.dart';

/// Paso 3 del registro de trabajador: subir CV (opcional; la subida de
/// archivos real es v0.3, ver el `onPressed` del botón "Seleccionar
/// archivo"). Extraído de `registro_trabajador_screen.dart` (ADR-0016,
/// tarea 033).
class PasoCvTrabajador extends StatelessWidget {
  final VoidCallback onAvanzar;
  const PasoCvTrabajador({super.key, required this.onAvanzar});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppEspaciado.lg),
        const TituloPasoRegistro('Subir CV'),
        const SizedBox(height: AppEspaciado.sm),
        Text(
          'Sube tu CV en PDF y ahorra tiempo en tus aplicaciones.',
          style: Theme.of(context)
              .textTheme
              .cuerpo
              .copyWith(color: colorTextoSuave(context)),
        ),
        const SizedBox(height: AppEspaciado.xxl),
        // Área de carga (solo UI, subida de archivos en v0.3)
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: colorSuperficie(context),
            border: Border.all(
              color: AppColores.acento.withValues(alpha: 0.35),
              width: 1.5,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_outlined,
                  size: 40, color: AppColores.acento.withValues(alpha: 0.6)),
              const SizedBox(height: AppEspaciado.md),
              Text('Adjunta tu CV aquí',
                  style: Theme.of(context)
                      .textTheme
                      .cuerpo
                      .copyWith(color: colorTextoSuave(context))),
              const SizedBox(height: AppEspaciado.xs),
              Text('PDF, DOC o DOCX — Máx. 5MB',
                  style: Theme.of(context)
                      .textTheme
                      .etiqueta
                      .copyWith(color: AppColores.grisMedio)),
              const SizedBox(height: AppEspaciado.md),
              BotonSecundario(
                texto: 'Seleccionar archivo',
                expandido: false,
                onPressed: () {
                  mostrarSnackBar(context,
                      'Subida de archivos disponible en la próxima versión');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppEspaciado.xxl),
        BotonPrimario(
          texto: 'Continuar',
          onPressed: onAvanzar,
        ),
        const SizedBox(height: AppEspaciado.md),
        BotonTexto(
          texto: 'Ahora no',
          color: colorTextoSuave(context),
          onPressed: onAvanzar,
        ),
        const SizedBox(height: AppEspaciado.xxl),
      ],
    );
  }
}
