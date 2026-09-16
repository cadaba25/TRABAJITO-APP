import 'package:flutter/material.dart';
import '../../../../compartido/widgets/boton_icono.dart';
import '../../../../compartido/widgets/boton_secundario.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/textos/app_textos.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Avisos "honestos" de la pestaña "Perfil" (tarea 023), extraídos de
/// `perfil_tab.dart` en la 027 B-2b: no prometer datos que no se tienen.
///
/// El estado de la recarga (`_recargando`) y la acción (`_recargar`) siguen en
/// el `State` de la pestaña; estos widgets solo reciben [recargando] y
/// [onReintentar].

/// Botón de reintentar de los avisos. Mientras hay una recarga en marcha
/// enseña la rueda en el sitio del botón.
class BotonReintentarPerfil extends StatelessWidget {
  final bool recargando;
  final VoidCallback onReintentar;
  final bool conTexto;

  const BotonReintentarPerfil({
    super.key,
    required this.recargando,
    required this.onReintentar,
    this.conTexto = false,
  });

  @override
  Widget build(BuildContext context) {
    if (recargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppEspaciado.md, vertical: AppEspaciado.sm),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColores.acento),
        ),
      );
    }
    if (conTexto) {
      return BotonSecundario(
        texto: 'Reintentar',
        icono: Icons.refresh_rounded,
        expandido: false,
        onPressed: onReintentar,
      );
    }
    return BotonIcono(
      icono: Icons.refresh_rounded,
      color: AppColores.advertencia,
      onPressed: onReintentar,
      tooltip: 'Actualizar',
    );
  }
}

/// Aviso de que lo que se ve puede no ser lo que hay en el servidor. Va arriba
/// del todo y con tono de advertencia, no de error.
class AvisoSinConexionPerfil extends StatelessWidget {
  final bool recargando;
  final VoidCallback onReintentar;

  const AvisoSinConexionPerfil({
    super.key,
    required this.recargando,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      // El 14 se deja literal a propósito: mismo caso suelto de redondeo
      // entre `campo` (12) y `tarjeta` (16) que ya documentó la 031/035, no
      // un patrón repetido.
      padding: const EdgeInsets.fromLTRB(14, AppEspaciado.md, 14, AppEspaciado.md),
      decoration: BoxDecoration(
        color: AppColores.advertencia.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadios.campo),
        border: Border.all(
            color: AppColores.advertencia.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 20, color: AppColores.advertencia),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTextos.datosDeTuUltimaVisita,
                    style: tt.cuerpoChico.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorTextoFuerte(context))),
                const SizedBox(height: AppEspaciado.xs),
                Text(AppTextos.datosSinConfirmarDetalle,
                    style: tt.cuerpoChico
                        .copyWith(color: colorTextoSuave(context))),
              ],
            ),
          ),
          const SizedBox(width: AppEspaciado.sm),
          BotonReintentarPerfil(
              recargando: recargando, onReintentar: onReintentar),
        ],
      ),
    );
  }
}

/// El CV no vino en esta lectura. Decirlo y, sobre todo, decir que **no se ha
/// borrado**: es exactamente lo que el usuario teme al ver su perfil a cero.
class AvisoCvSinCargar extends StatelessWidget {
  final bool recargando;
  final VoidCallback onReintentar;

  const AvisoCvSinCargar({
    super.key,
    required this.recargando,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.lg),
      decoration: BoxDecoration(
        color: colorSuperficie(context),
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        border: Border.all(color: colorBorde(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 20, color: AppColores.grisMedio),
              const SizedBox(width: AppEspaciado.sm),
              Expanded(
                child: Text(AppTextos.cvSinCargar,
                    style: tt.cuerpoChico.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorTextoFuerte(context))),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          Text(AppTextos.cvSinCargarDetalle,
              style: tt.cuerpoChico.copyWith(color: colorTextoSuave(context))),
          const SizedBox(height: AppEspaciado.md),
          Align(
            alignment: Alignment.centerLeft,
            child: BotonReintentarPerfil(
                recargando: recargando,
                onReintentar: onReintentar,
                conTexto: true),
          ),
        ],
      ),
    );
  }
}
