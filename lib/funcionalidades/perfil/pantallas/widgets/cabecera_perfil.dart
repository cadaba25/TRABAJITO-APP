import 'package:flutter/material.dart';
import '../../../../compartido/modelos/usuario.dart';
import '../../../../compartido/widgets/boton_icono.dart';
import '../../../../compartido/widgets/estrellas.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Cabecera de la pestaña "Perfil": avatar, nombre, badge de rol y estrellas,
/// sobre un degradado. Extraída de `perfil_tab.dart` en la tarea 027 B-2b.
///
/// **El degradado tiene 3 paradas, no 2 (tarea 039)**: mismo defecto de
/// banding y mismo arreglo que en `EncabezadoFeed` (`encabezado_feed.dart`,
/// mismo par de colores exacto) — ver el docstring de esa clase para la
/// causa real (confirmada en el emulador, no asumida). **No tocado por la
/// tarea 037** (tokens de tipografía/espaciado/radios, ADR-0016): se
/// conserva tal cual.
///
/// Tokens de la 037: `BorderRadius.circular(18)` pasó a `AppRadios.tarjeta`
/// (16, -2px) por ser el rol más cercano entre `campo`/`tarjeta`/`chip` para
/// un contenedor de tarjeta — mismo criterio de redondeo por distancia que
/// usaron 034/035/036.
class CabeceraPerfil extends StatelessWidget {
  final Usuario usuario;
  final bool esEmpleador;
  final VoidCallback onConfiguracion;

  const CabeceraPerfil({
    super.key,
    required this.usuario,
    required this.esEmpleador,
    required this.onConfiguracion,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColores.principal,
            AppColores.azulClaro,
            AppColores.azulProfesional,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: BotonIcono(
              onPressed: onConfiguracion,
              icono: Icons.settings_outlined,
              color: Colors.white,
              tooltip: 'Configuración',
            ),
          ),
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              usuario.iniciales,
              style: tt.tituloGrande.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          Text(
            usuario.nombreVisible,
            textAlign: TextAlign.center,
            style: tt.titulo.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppEspaciado.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppEspaciado.md, vertical: AppEspaciado.xs),
            decoration: BoxDecoration(
              color: AppColores.dorado.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(AppRadios.chip),
            ),
            child: Text(
              esEmpleador ? 'EMPLEADOR' : 'TRABAJADOR',
              style: tt.etiqueta
                  .copyWith(color: AppColores.dorado, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          Estrellas(
            valor: usuario.calificacionPromedio,
            total: usuario.totalCalificaciones,
            colorTexto: Colors.white,
          ),
        ],
      ),
    );
  }
}
