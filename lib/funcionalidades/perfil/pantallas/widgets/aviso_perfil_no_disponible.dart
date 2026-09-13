import 'package:flutter/material.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Se llegó a "Editar perfil" con un perfil a medias y no se pudo completar
/// (casi siempre, sin conexión). Enseñar el formulario sería peor que no
/// enseñarlo: el usuario guardaría campos vacíos encima de datos buenos.
///
/// Extraído de `editar_perfil_screen.dart` en la tarea 027 B-2b. La recarga
/// del perfil la sigue gestionando el `State` de la pantalla.
class AvisoPerfilNoDisponible extends StatelessWidget {
  final VoidCallback onReintentar;
  const AvisoPerfilNoDisponible({super.key, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppEspaciado.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColores.grisMedio),
            // 14 se deja literal: mismo caso suelto de redondeo entre `md`
            // (12) y `lg` (16) que ya documentaron 031/035.
            const SizedBox(height: 14),
            Text(
              'No pudimos cargar tu perfil completo.',
              textAlign: TextAlign.center,
              style: tt.cuerpo.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorTextoFuerte(context)),
            ),
            const SizedBox(height: AppEspaciado.sm),
            Text(
              'Para no borrar sin querer lo que ya tienes guardado, la edición '
              'se abre solo con tu perfil al día. Revisa tu conexión e '
              'inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: tt.cuerpoChico.copyWith(color: colorTextoSuave(context)),
            ),
            const SizedBox(height: AppEspaciado.xl),
            ElevatedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
