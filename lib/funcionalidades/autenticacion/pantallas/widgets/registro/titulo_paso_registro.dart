import 'package:flutter/material.dart';
import '../../../../../nucleo/tema/colores_por_tema.dart';
import '../../../../../nucleo/tipografia/app_tipografia.dart';

/// Título de un paso de registro ("Crea tu cuenta", "Datos Personales"...).
///
/// Antes cada pantalla de registro tenía su propio `_titulo()` con un
/// `TextStyle(fontSize: 24, fontWeight: w800, letterSpacing: -0.5)` literal
/// idéntico en `registro_trabajador_screen.dart` y
/// `registro_empleador_screen.dart` — se comparte aquí en vez de duplicarlo
/// dos veces al aplicar los tokens de ADR-0016 (tarea 033).
///
/// **Mapeo de rol (mismo criterio de la tarea 032):** este título funciona
/// como el renglón "hero" de cada paso (es lo único grande de la pantalla,
/// junto al indicador de pasos) — igual que "Bienvenido a Trabajito" en
/// login o "¡Hola!" en bienvenida, así que usa [AppTipografia.tituloGrande]
/// (28/w800/-0.5), no [AppTipografia.titulo]. El `letterSpacing: -0.5`
/// coincide exacto con el que ya tenía este texto.
class TituloPasoRegistro extends StatelessWidget {
  final String texto;
  const TituloPasoRegistro(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: Theme.of(context)
          .textTheme
          .tituloGrande
          .copyWith(color: colorTextoFuerte(context)),
    );
  }
}
