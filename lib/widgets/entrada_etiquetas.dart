import 'package:flutter/material.dart';
import '../utils/constantes.dart';
import 'custom_textfield.dart';

/// Entrada de etiquetas (habilidades): chips agregables/quitables + sugerencias.
class EntradaEtiquetas extends StatefulWidget {
  final List<String> etiquetas;
  final List<String> sugerencias;
  final String etiquetaCampo;

  const EntradaEtiquetas({
    super.key,
    required this.etiquetas,
    this.sugerencias = const [],
    this.etiquetaCampo = 'Agregar habilidad',
  });

  @override
  State<EntradaEtiquetas> createState() => _EntradaEtiquetasState();
}

class _EntradaEtiquetasState extends State<EntradaEtiquetas> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _agregar(String valor) {
    final v = valor.trim();
    if (v.isEmpty) return;
    final existe =
        widget.etiquetas.any((e) => e.toLowerCase() == v.toLowerCase());
    if (!existe && widget.etiquetas.length < 15) {
      setState(() => widget.etiquetas.add(v));
    }
    _ctrl.clear();
  }

  void _quitar(String e) => setState(() => widget.etiquetas.remove(e));

  @override
  Widget build(BuildContext context) {
    final sugerenciasDisponibles = widget.sugerencias
        .where((s) => !widget.etiquetas
            .any((e) => e.toLowerCase() == s.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _ctrl,
                label: widget.etiquetaCampo,
                iconoInicio: Icons.sell_outlined,
                accionTeclado: TextInputAction.done,
                alTerminar: _agregar,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AppColores.acento,
                minimumSize: const Size(52, 52),
              ),
              onPressed: () => _agregar(_ctrl.text),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ],
        ),
        if (widget.etiquetas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.etiquetas
                .map((e) => Chip(
                      label: Text(e),
                      labelStyle: const TextStyle(
                          color: AppColores.acento,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      backgroundColor: AppColores.acento.withOpacity(0.12),
                      side: BorderSide(color: AppColores.acento.withOpacity(0.4)),
                      deleteIconColor: AppColores.acento,
                      onDeleted: () => _quitar(e),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ],
        if (sugerenciasDisponibles.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Sugerencias',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorTextoSuave(context))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sugerenciasDisponibles
                .take(12)
                .map((s) => ActionChip(
                      label: Text(s),
                      labelStyle: TextStyle(
                          fontSize: 12, color: colorTextoFuerte(context)),
                      backgroundColor: colorSuperficie(context),
                      side: BorderSide(color: colorBorde(context)),
                      onPressed: () => _agregar(s),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

/// Muestra habilidades como chips de solo lectura.
class ChipsHabilidades extends StatelessWidget {
  final List<String> habilidades;
  const ChipsHabilidades({super.key, required this.habilidades});

  @override
  Widget build(BuildContext context) {
    if (habilidades.isEmpty) {
      return Text('Sin habilidades registradas',
          style: TextStyle(color: colorTextoSuave(context), fontSize: 13));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: habilidades
          .map((e) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColores.acento.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(e,
                    style: const TextStyle(
                        color: AppColores.acento,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ))
          .toList(),
    );
  }
}
