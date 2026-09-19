import 'package:flutter/material.dart';

import '../../nucleo/tema/app_colores.dart';
import '../../nucleo/tema/colores_por_tema.dart';

/// Cuatro barritas que puntuan la contrasena mientras se escribe.
///
/// **Es solo una pista visual, no una regla.** Quien decide si la contrasena
/// vale es `ReglasCuenta` en el cliente y el backend en el servidor (10 a 72
/// caracteres, ADR-0010).
class IndicadorFuerzaContrasena extends StatelessWidget {
  final String contrasena;

  const IndicadorFuerzaContrasena({super.key, required this.contrasena});

  int get _fuerza {
    if (contrasena.isEmpty) return 0;
    int pts = 0;
    if (contrasena.length >= 8) pts++;
    if (RegExp(r'[A-Z]').hasMatch(contrasena)) pts++;
    if (RegExp(r'[0-9]').hasMatch(contrasena)) pts++;
    if (RegExp(r'[!@#\$&*~%^()_+\-=\[\]{}|;:",.<>?/]').hasMatch(contrasena)) pts++;
    return pts;
  }

  Color get _color {
    switch (_fuerza) {
      case 1: return AppColores.error;
      case 2: return AppColores.advertencia;
      case 3: return const Color(0xFF84CC16);
      case 4: return AppColores.exito;
      default: return AppColores.grisMedio;
    }
  }

  String get _texto {
    switch (_fuerza) {
      case 1: return 'Débil';
      case 2: return 'Regular';
      case 3: return 'Buena';
      case 4: return 'Muy segura';
      default: return 'Seguridad';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < _fuerza ? _color : colorBorde(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (contrasena.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ],
    );
  }
}
