import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../nucleo/tema/colores_por_tema.dart';

/// Campo de texto de la app: etiqueta flotante, icono opcional y el ojo de
/// "ver contrasena" cuando [CustomTextField.esContrasena].
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
