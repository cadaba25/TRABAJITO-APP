import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/logo_trabajito.dart';
import 'bienvenida_registro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _correoCtrl    = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _cargando = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    final error = await _authService.iniciarSesion(
      correo: _correoCtrl.text,
      contrasena: _contrasenaCtrl.text,
    );
    if (!mounted) return;
    setState(() => _cargando = false);
    if (error != null) mostrarSnackBar(context, error, esError: true);
  }

  Future<void> _recuperarContrasena() async {
    final ctrl = TextEditingController(text: _correoCtrl.text.trim());
    final correo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recuperar contraseña',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo electrónico'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (correo == null || correo.isEmpty) return;
    final error = await _authService.enviarResetPassword(correo);
    if (!mounted) return;
    mostrarSnackBar(
        context,
        error ?? 'Te enviamos un correo para restablecer tu contraseña',
        esError: error != null);
  }

  void _irARegistro() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BienvenidaRegistroScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: notificadorTema,
                      builder: (_, oscuro, __) => IconButton(
                        onPressed: () =>
                            notificadorTema.value = !notificadorTema.value,
                        icon: Icon(
                            oscuro
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: colorTextoSuave(context)),
                        tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _construirLogo(context),
                  const SizedBox(height: 40),
                  Text(
                    AppTextos.bienvenido,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: colorTextoFuerte(context),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTextos.subtituloLogin,
                    style: TextStyle(color: colorTextoSuave(context)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        CustomTextField(
                          controller: _correoCtrl,
                          label: AppTextos.correo,
                          hint: 'ejemplo@correo.com',
                          iconoInicio: Icons.email_outlined,
                          tipoTeclado: TextInputType.emailAddress,
                          validador: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return MensajesError.campoObligatorio;
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(v.trim())) {
                              return MensajesError.correoInvalido;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _contrasenaCtrl,
                          label: AppTextos.contrasena,
                          iconoInicio: Icons.lock_outline,
                          esContrasena: true,
                          accionTeclado: TextInputAction.done,
                          alTerminar: (_) => _iniciarSesion(),
                          validador: (v) {
                            if (v == null || v.isEmpty) {
                              return MensajesError.campoObligatorio;
                            }
                            if (v.length < 6) return MensajesError.contrasenaMuyCorta;
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _cargando ? null : _recuperarContrasena,
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32)),
                            child: const Text('¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                    color: AppColores.acento, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargando ? null : _iniciarSesion,
                          child: _cargando
                              ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text(AppTextos.iniciarSesion),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _cargando ? null : _irARegistro,
                          child: const Text(AppTextos.crearCuenta),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(AppTextos.noTieneCuenta,
                                style: TextStyle(color: colorTextoSuave(context))),
                            GestureDetector(
                              onTap: _irARegistro,
                              child: const Text(
                                AppTextos.registrate,
                                style: TextStyle(
                                    color: AppColores.acento,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirLogo(BuildContext context) {
    return Column(
      children: [
        const LogoInsignia(size: 84),
        const SizedBox(height: 16),
        LogoTextoSolo(altura: 30, color: colorTextoFuerte(context)),
        const SizedBox(height: 6),
        Text(
          AppTextos.tagline,
          style: TextStyle(fontSize: 12, color: colorTextoSuave(context)),
        ),
      ],
    );
  }
}
