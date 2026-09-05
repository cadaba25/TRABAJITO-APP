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

  /// La misma instancia de lista durante toda la vida de la pantalla:
  /// `EntradaEtiquetas` la modifica en el sitio.
  final List<String> _habilidades = [];

  /// El perfil con el que trabaja el formulario. Puede NO ser el que llegó por
  /// parámetro: ver [_cargarPerfilCompleto].
  late Usuario _usuario;

  bool _cargando = false;
  bool _pidiendoPerfil = false;
  bool _perfilNoDisponible = false;

  bool get _esEmpleador => _usuario.esEmpleador;

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
    _telefonoCtrl = TextEditingController();
    _sitioWebCtrl = TextEditingController();
    _presentacionCtrl = TextEditingController();
    _rellenarDesde(_usuario);
    // Editar un perfil que no viene de una lectura completa destruye datos:
    // ver [_cargarPerfilCompleto].
    if (!_usuario.cvCargado) {
      _pidiendoPerfil = true;
      _cargarPerfilCompleto();
    }
  }

  void _rellenarDesde(Usuario u) {
    _telefonoCtrl.text = u.telefono;
    _sitioWebCtrl.text = u.sitioWeb;
    _presentacionCtrl.text =
        u.esEmpleador ? u.descripcionEmpresa : u.presentacion;
    _habilidades
      ..clear()
      ..addAll(u.habilidades);
  }

  /// Pide el perfil entero antes de dejar editar nada.
  ///
  /// **Por qué existe** (hallazgo de la tarea 022, reproducido en el
  /// emulador). El perfil que se guarda en el dispositivo junto a la sesión es
  /// el que devolvió el login, y ese **no trae el CV** (`habilidades`,
  /// `experiencia` y `estudios` llegan `null`) y puede estar viejo en todo lo
  /// demás. Cuando la app arranca sin conexión, `restaurarSesion()` entra con
  /// ese perfil a medias (`cvCargado == false`). Si desde ahí se abría este
  /// formulario:
  ///
  /// - Los campos de texto salían vacíos y `PUT /api/usuarios/me` los mandaba
  ///   vacíos: se **borraba la presentación** (o la descripción de la empresa)
  ///   que sí estaba guardada en el servidor.
  /// - Las habilidades que el usuario escribiera se **descartaban en
  ///   silencio** —la barrera de `cvCargado` impedía mandarlas, que era lo
  ///   correcto— y aun así se decía "Perfil actualizado".
  ///
  /// La barrera protegía el CV pero no el resto, y encima mentía. Con esto, o
  /// se edita el perfil de verdad o no se edita nada.
  Future<void> _cargarPerfilCompleto() async {
    final completo = await _auth.obtenerUsuarioActual();
    if (!mounted) return;
    setState(() {
      _pidiendoPerfil = false;
      if (completo != null && completo.cvCargado) {
        _usuario = completo;
        _rellenarDesde(completo);
        _perfilNoDisponible = false;
      } else {
        // Sin conexión (o el servidor falló): no hay forma de editar sin
        // arriesgarse a pisar datos buenos con lo que hay en la mano.
        _perfilNoDisponible = true;
      }
    });
  }

  void _reintentarPerfil() {
    setState(() {
      _pidiendoPerfil = true;
      _perfilNoDisponible = false;
    });
    _cargarPerfilCompleto();
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
    // Cinturón: el formulario no se dibuja sin perfil completo, pero mandar
    // este cuerpo con un perfil a medias borra datos del usuario.
    if (!_usuario.cvCargado) return;
    setState(() => _cargando = true);
    final campos = <String, dynamic>{
      'telefono': _telefonoCtrl.text.trim(),
    };
    if (_esEmpleador) {
      campos['sitioWeb'] = _sitioWebCtrl.text.trim();
      campos['descripcionEmpresa'] = _presentacionCtrl.text.trim();
    } else {
      campos['presentacion'] = _presentacionCtrl.text.trim();
    }
    var err = await _auth.actualizarCampos(campos);

    // Las habilidades van por su propia ruta y son un **reemplazo de la lista
    // entera**: mandarlas cuando no se han cargado de verdad borraría el CV
    // del usuario. `cvCargado` distingue "no tiene habilidades" de "esta
    // respuesta no las traía" (el login y el registro las mandan `null`).
    if (err == null && !_esEmpleador) {
      err = await _auth.reemplazarHabilidades(_habilidades);
    }

    if (!mounted) return;
    setState(() => _cargando = false);
    if (err != null) {
      mostrarSnackBar(context, err, esError: true);
      return;
    }
    // Deja la sesión con las habilidades ya guardadas (la respuesta de
    // `PUT /me` es anterior a escribirlas).
    if (!_esEmpleador) {
      await _auth.recargarPerfil();
      if (!mounted) return;
    }
    mostrarSnackBar(context, 'Perfil actualizado');
    Navigator.pop(context);
  }

  /// El backend no tiene todavía endpoint para cambiar la contraseña (tarea
  /// 017, abierta). Con Firebase lo daba hecho `updatePassword`. Se enseña un
  /// aviso honesto en vez de un formulario que no guardaría nada.
  Future<void> _cambiarContrasena() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cambiar contraseña',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(MensajesError.sinCambioContrasena),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
      body: _pidiendoPerfil
          ? const Center(
              child: CircularProgressIndicator(color: AppColores.acento))
          : _perfilNoDisponible
              ? _sinPerfilCompleto(context)
              : _formulario(context),
    );
  }

  /// Se llegó aquí con un perfil a medias y no se pudo completar (casi siempre,
  /// sin conexión). Enseñar el formulario sería peor que no enseñarlo: el
  /// usuario guardaría campos vacíos encima de datos buenos.
  Widget _sinPerfilCompleto(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColores.grisMedio),
            const SizedBox(height: 14),
            Text(
              'No pudimos cargar tu perfil completo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colorTextoFuerte(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'Para no borrar sin querer lo que ya tienes guardado, la edición '
              'se abre solo con tu perfil al día. Revisa tu conexión e '
              'inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorTextoSuave(context)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _reintentarPerfil,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    return SafeArea(
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
                        child: Text(_usuario.iniciales,
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
    );
  }
}
