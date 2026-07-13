import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/entrada_etiquetas.dart';

/// Permite al usuario editar sus datos después del registro.
class EditarPerfilScreen extends StatefulWidget {
  final Usuario usuario;
  const EditarPerfilScreen({super.key, required this.usuario});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _auth = AuthService();
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _sitioWebCtrl;
  late final TextEditingController _descripcionCtrl;
  late final List<String> _habilidades;
  bool _cargando = false;

  bool get _esEmpleador => widget.usuario.esEmpleador;

  @override
  void initState() {
    super.initState();
    _telefonoCtrl = TextEditingController(text: widget.usuario.telefono);
    _sitioWebCtrl = TextEditingController(text: widget.usuario.sitioWeb);
    _descripcionCtrl =
        TextEditingController(text: widget.usuario.descripcionEmpresa);
    _habilidades = List<String>.from(widget.usuario.habilidades);
  }

  @override
  void dispose() {
    _telefonoCtrl.dispose();
    _sitioWebCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    final campos = <String, dynamic>{
      'telefono': _telefonoCtrl.text.trim(),
    };
    if (_esEmpleador) {
      campos['sitioWeb'] = _sitioWebCtrl.text.trim();
      campos['descripcionEmpresa'] = _descripcionCtrl.text.trim();
    } else {
      campos['habilidades'] = _habilidades;
    }
    final err = await _auth.actualizarCampos(campos);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (err != null) {
      mostrarSnackBar(context, err, esError: true);
      return;
    }
    mostrarSnackBar(context, 'Perfil actualizado');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _telefonoCtrl,
                label: 'Teléfono',
                iconoInicio: Icons.phone_outlined,
                tipoTeclado: TextInputType.phone,
                formateadores: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),

              if (_esEmpleador) ...[
                CustomTextField(
                  controller: _sitioWebCtrl,
                  label: 'Sitio web (opcional)',
                  hint: 'www.empresa.com',
                  iconoInicio: Icons.language_outlined,
                  tipoTeclado: TextInputType.url,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _descripcionCtrl,
                  label: 'Descripción (opcional)',
                  maxLines: 4,
                  maxLength: 500,
                ),
              ] else ...[
                Text('Habilidades',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorTextoFuerte(context))),
                const SizedBox(height: 10),
                EntradaEtiquetas(
                  etiquetas: _habilidades,
                  sugerencias: DatosHonduras.habilidadesSugeridas,
                ),
              ],

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _cargando ? null : _guardar,
                child: _cargando
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
