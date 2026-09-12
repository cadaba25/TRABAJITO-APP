import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../../nucleo/tema/app_colores.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';
import 'decoracion_campo_fecha.dart';

/// Fila "Fecha de nacimiento *" con los tres campos DD/MM/AAAA.
///
/// Compartida entre los dos registros (antes duplicada línea por línea en
/// `_paso2()` de `registro_trabajador_screen.dart` y
/// `registro_empleador_screen.dart`). La validación ("Requerido" por campo,
/// mayoría de edad al avanzar) sigue viviendo en la pantalla que la usa —
/// este widget solo pinta los tres campos y expone sus controladores.
class CampoFechaNacimiento extends StatelessWidget {
  final TextEditingController diaCtrl;
  final TextEditingController mesCtrl;
  final TextEditingController anioCtrl;

  const CampoFechaNacimiento({
    super.key,
    required this.diaCtrl,
    required this.mesCtrl,
    required this.anioCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha de nacimiento *',
          style: Theme.of(context)
              .textTheme
              .cuerpoChico
              .copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorTextoFuerte(context)),
        ),
        const SizedBox(height: AppEspaciado.sm),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: diaCtrl,
                decoration: decoracionCampoFecha(context, 'DD'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppEspaciado.sm),
              child: Text('/',
                  style: TextStyle(fontSize: 20, color: AppColores.grisMedio)),
            ),
            Expanded(
              child: TextFormField(
                controller: mesCtrl,
                decoration: decoracionCampoFecha(context, 'MM'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppEspaciado.sm),
              child: Text('/',
                  style: TextStyle(fontSize: 20, color: AppColores.grisMedio)),
            ),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: anioCtrl,
                decoration: decoracionCampoFecha(context, 'AAAA'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
