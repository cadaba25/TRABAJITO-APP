import 'package:flutter/material.dart';
import '../../../../compartido/datos/datos_empleador.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/movimiento/app_movimiento.dart';
import '../../../../nucleo/movimiento/movimiento_accesible.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Barra de búsqueda del feed de "Trabajos" + los chips de filtro por plazo.
///
/// Extraída de `trabajos_tab.dart` en la tarea 027 B-2b. Sin estado: el texto
/// de búsqueda y el plazo elegido viven en el `State` de la pestaña; aquí solo
/// se despachan los cambios.
class BarraBusquedaTrabajos extends StatelessWidget {
  final bool oscuro;

  /// Hay categoría o departamento aplicados: el icono de filtros se pinta en
  /// color de acento.
  final bool filtrosActivos;

  /// Plazo actualmente seleccionado (`''` = "Todos").
  final String plazoActivo;

  final ValueChanged<String> onBusquedaCambia;
  final ValueChanged<String> onPlazoCambia;
  final VoidCallback onAbrirFiltros;

  const BarraBusquedaTrabajos({
    super.key,
    required this.oscuro,
    required this.filtrosActivos,
    required this.plazoActivo,
    required this.onBusquedaCambia,
    required this.onPlazoCambia,
    required this.onAbrirFiltros,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppEspaciado.lg, AppEspaciado.md, AppEspaciado.lg, 0),
      child: Column(
        children: [
          TextField(
            onChanged: onBusquedaCambia,
            style: TextStyle(color: colorTextoFuerte(context)),
            decoration: InputDecoration(
              hintText: 'Buscar trabajos u oficios…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: IconButton(
                onPressed: onAbrirFiltros,
                icon: Icon(Icons.tune_rounded,
                    color: filtrosActivos
                        ? AppColores.acento
                        : AppColores.grisMedio),
                tooltip: 'Filtros',
              ),
              isDense: true,
              filled: true,
              fillColor:
                  oscuro ? AppColores.superficieOscura : AppColores.blanco,
              // 24 no cae exacto en AppRadios: `chip` (20) es el más cercano
              // de los tres roles para esta píldora casi del todo redondeada.
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadios.chip),
                borderSide: BorderSide(
                    color: oscuro
                        ? AppColores.bordeOscuro
                        : AppColores.grisClaro),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadios.chip),
                borderSide: BorderSide(
                    color: oscuro
                        ? AppColores.bordeOscuro
                        : AppColores.grisClaro),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppEspaciado.sm, vertical: AppEspaciado.md),
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _ChipPlazo(
                    texto: 'Todos',
                    valor: '',
                    activo: plazoActivo.isEmpty,
                    onTap: onPlazoCambia),
                ...DatosEmpleador.plazos.map((p) => _ChipPlazo(
                    texto: p,
                    valor: p,
                    activo: plazoActivo == p,
                    onTap: onPlazoCambia)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipPlazo extends StatelessWidget {
  final String texto;
  final String valor;
  final bool activo;
  final ValueChanged<String> onTap;
  const _ChipPlazo({
    required this.texto,
    required this.valor,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppEspaciado.sm),
      child: GestureDetector(
        onTap: () => onTap(valor),
        child: AnimatedContainer(
          duration: duracionMov(context, AppMovimiento.chico),
          curve: curvaMov(context, AppMovimiento.estandar),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.md),
          decoration: BoxDecoration(
            color: activo
                ? AppColores.acento.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadios.chip),
            border: Border.all(
                color: activo ? AppColores.acento : AppColores.grisMedio),
          ),
          child: Text(texto,
              style: Theme.of(context).textTheme.etiqueta.copyWith(
                  fontWeight: FontWeight.w700,
                  color:
                      activo ? AppColores.acento : colorTextoSuave(context))),
        ),
      ),
    );
  }
}
