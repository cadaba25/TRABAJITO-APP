import 'package:flutter/material.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/textos/app_textos.dart';

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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColores.acento),
        ),
      );
    }
    if (conTexto) {
      return OutlinedButton.icon(
        onPressed: onReintentar,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Reintentar'),
      );
    }
    return IconButton(
      onPressed: onReintentar,
      icon: const Icon(Icons.refresh_rounded, color: AppColores.advertencia),
      tooltip: 'Actualizar',
      visualDensity: VisualDensity.compact,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColores.advertencia.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColores.advertencia.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 20, color: AppColores.advertencia),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTextos.datosDeTuUltimaVisita,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorTextoFuerte(context))),
                const SizedBox(height: 2),
                Text(AppTextos.datosSinConfirmarDetalle,
                    style: TextStyle(
                        fontSize: 12, color: colorTextoSuave(context))),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSuperficie(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorde(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 20, color: AppColores.grisMedio),
              const SizedBox(width: 10),
              Expanded(
                child: Text(AppTextos.cvSinCargar,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorTextoFuerte(context))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(AppTextos.cvSinCargarDetalle,
              style: TextStyle(fontSize: 12, color: colorTextoSuave(context))),
          const SizedBox(height: 10),
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
