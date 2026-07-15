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
  late final TextEditingController _presentacionCtrl;
  late final List<String> _habilidades;
  bool _cargando = false;

  bool get _esEmpleador => widget.usuario.esEmpleador;

  @override
  void initState() {
    super.initState();
    _telefonoCtrl = TextEditingController(text: widget.usuario.telefono);
    _sitioWebCtrl = TextEditingController(text: widget.usuario.sitioWeb);
    _presentacionCtrl = TextEditingController(
        text: _esEmpleador
            ? widget.usuario.descripcionEmpresa
            : widget.usuario.presentacion);
    _habilidades = List<String>.from(widget.usuario.habilidades);
  }

  @override
  void dispose() {
    _telefonoCtrl.dispose();
    _sitioWebCtrl.dispose();
    _presentacionCtrl.dispose();
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
      campos['descripcionEmpresa'] = _presentacionCtrl.text.trim();
    } else {
      campos['habilidades'] = _habilidades;
      campos['presentacion'] = _presentacionCtrl.text.trim();
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

  Future<void> _cambiarContrasena() async {
    final ctrl = TextEditingController();
    final ctrl2 = TextEditingController();
    final nueva = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cambiar contraseña',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final a = ctrl.text.trim();
              if (a.length < 6) return;
              if (a != ctrl2.text.trim()) return;
              Navigator.pop(ctx, a);
            },
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (nueva == null) return;
    final err = await _auth.cambiarContrasena(nueva);
    if (!mounted) return;
    mostrarSnackBar(context, err ?? 'Contraseña actualizada', esError: err != null);
  }

  void _proximamente(String que) =>
      mostrarSnackBar(context, '$que estará disponible pronto');

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
              // Foto de perfil (requiere Firebase Storage — próximamente)
              Center(
                child: GestureDetector(
                  onTap: () => _proximamente('El cambio de foto'),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColores.acento.withOpacity(0.15),
                        child: Text(widget.usuario.iniciales,
                            style: const TextStyle(
                                color: AppColores.acento,
                                fontSize: 30,
                                fontWeight: FontWeight.w800)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: AppColores.acento, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              CustomTextField(
                controller: _telefonoCtrl,
                label: 'Teléfono',
                iconoInicio: Icons.phone_outlined,
                tipoTeclado: TextInputType.phone,
                formateadores: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _presentacionCtrl,
                label: _esEmpleador
                    ? 'Descripción de la empresa'
                    : 'Presentación / sobre mí',
                hint: _esEmpleador
                    ? 'A qué se dedica tu empresa...'
                    : 'Cuéntales a los contratistas por qué elegirte...',
                maxLines: 4,
                maxLength: 500,
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
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _proximamente('La actualización de CV'),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Cambiar CV'),
                ),
                const SizedBox(height: 12),
              ],

              OutlinedButton.icon(
                onPressed: _cambiarContrasena,
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Cambiar contraseña'),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _cargando ? null : _guardar,
                child: _cargando
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Guardar cambios'),
              ),
              const SizedBox(height: 8),
              Text(
                'La foto de perfil y el CV requieren almacenamiento (Firebase '
                'Storage), que se habilitará más adelante.',
                style: TextStyle(
                    fontSize: 11, color: colorTextoSuave(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
