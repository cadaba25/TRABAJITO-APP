import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constantes.dart';

// ─────────────────────────────────────────────────────────────
// HELPERS DE COLOR SEGÚN EL TEMA
// ─────────────────────────────────────────────────────────────
bool _esOscuro(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

Color colorTextoFuerte(BuildContext c) =>
    _esOscuro(c) ? AppColores.textoOscuro : AppColores.azulOscuro;
Color colorTextoSuave(BuildContext c) =>
    _esOscuro(c) ? AppColores.grisMedio : AppColores.grisTexto;
Color colorSuperficie(BuildContext c) =>
    _esOscuro(c) ? AppColores.superficieOscura : AppColores.blanco;
Color colorBorde(BuildContext c) =>
    _esOscuro(c) ? AppColores.bordeOscuro : AppColores.grisClaro;

// ─────────────────────────────────────────────────────────────
// CAMPO DE TEXTO PERSONALIZADO
// ─────────────────────────────────────────────────────────────
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? iconoInicio;
  final String? Function(String?)? validador;
  final bool esContrasena;
  final TextInputType tipoTeclado;
  final List<TextInputFormatter>? formateadores;
  final TextInputAction accionTeclado;
  final void Function(String)? alTerminar;
  final int maxLines;
  final int? maxLength;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.iconoInicio,
    this.validador,
    this.esContrasena = false,
    this.tipoTeclado = TextInputType.text,
    this.formateadores,
    this.accionTeclado = TextInputAction.next,
    this.alTerminar,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _mostrar = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.esContrasena && !_mostrar,
      keyboardType: widget.tipoTeclado,
      inputFormatters: widget.formateadores,
      textInputAction: widget.accionTeclado,
      onFieldSubmitted: widget.alTerminar,
      validator: widget.validador,
      maxLines: widget.esContrasena ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      style: TextStyle(
        color: colorTextoFuerte(context),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.iconoInicio != null
            ? Icon(widget.iconoInicio, color: colorTextoSuave(context), size: 20)
            : null,
        suffixIcon: widget.esContrasena
            ? IconButton(
                icon: Icon(
                  _mostrar ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: colorTextoSuave(context),
                  size: 20,
                ),
                onPressed: () => setState(() => _mostrar = !_mostrar),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INDICADOR DE PROGRESO DE PASOS
// ─────────────────────────────────────────────────────────────
class IndicadorPasos extends StatelessWidget {
  final int pasoActual;  // 1-based
  final int totalPasos;

  const IndicadorPasos({
    super.key,
    required this.pasoActual,
    required this.totalPasos,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paso $pasoActual/$totalPasos',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorTextoSuave(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(totalPasos, (i) {
            final completado = i < pasoActual;
            final activo = i == pasoActual - 1;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < totalPasos - 1 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: completado || activo
                      ? AppColores.acento
                      : colorBorde(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTONES SI / NO
// ─────────────────────────────────────────────────────────────
class BotonesSiNo extends StatelessWidget {
  final bool? valorActual;
  final void Function(bool) alCambiar;
  final String pregunta;

  const BotonesSiNo({
    super.key,
    required this.valorActual,
    required this.alCambiar,
    required this.pregunta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pregunta,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorTextoFuerte(context),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _boton(context, true, 'Sí'),
            const SizedBox(width: 12),
            _boton(context, false, 'No'),
          ],
        ),
      ],
    );
  }

  Widget _boton(BuildContext context, bool valor, String texto) {
    final seleccionado = valorActual == valor;
    return GestureDetector(
      onTap: () => alCambiar(valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? AppColores.acento : colorSuperficie(context),
          border: Border.all(
            color: seleccionado ? AppColores.acento : AppColores.grisMedio,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (seleccionado) ...[
              const Icon(Icons.check, color: Colors.white, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              texto,
              style: TextStyle(
                color: seleccionado ? Colors.white : colorTextoFuerte(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DROPDOWN PERSONALIZADO
// ─────────────────────────────────────────────────────────────
class CustomDropdown extends StatelessWidget {
  final String label;
  final String? valor;
  final List<String> opciones;
  final void Function(String?) alCambiar;
  final String? Function(String?)? validador;
  final IconData? icono;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.valor,
    required this.opciones,
    required this.alCambiar,
    this.validador,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: valor,
      validator: validador,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icono != null
            ? Icon(icono, color: colorTextoSuave(context), size: 20)
            : null,
      ),
      items: opciones.map((op) => DropdownMenuItem(
        value: op,
        child: Text(op,
            style: TextStyle(fontSize: 14, color: colorTextoFuerte(context))),
      )).toList(),
      onChanged: alCambiar,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorTextoSuave(context)),
      dropdownColor: colorSuperficie(context),
      isExpanded: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INDICADOR DE FUERZA DE CONTRASEÑA
// ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
// SNACKBAR HELPER
// ─────────────────────────────────────────────────────────────
void mostrarSnackBar(BuildContext context, String mensaje, {bool esError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            esError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(mensaje)),
        ],
      ),
      backgroundColor: esError ? AppColores.error : AppColores.exito,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: esError ? 4 : 3),
    ),
  );
}
