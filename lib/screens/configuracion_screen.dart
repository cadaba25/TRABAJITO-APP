import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import '../widgets/custom_textfield.dart';
import 'editar_perfil_screen.dart';

/// Pantalla de configuración: tema, cuenta y opciones.
class ConfiguracionScreen extends StatelessWidget {
  final Usuario usuario;
  const ConfiguracionScreen({super.key, required this.usuario});

  void _proximamente(BuildContext context) {
    mostrarSnackBar(context, 'Función disponible próximamente');
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Se cerrará tu sesión actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.error,
              minimumSize: const Size(100, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await AuthService().cerrarSesion();
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar tu cuenta?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Se borrarán tu perfil y tus datos de forma permanente. '
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.error,
              minimumSize: const Size(100, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    // Indicador de carga bloqueante.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColores.acento)),
    );
    final error = await AuthService().eliminarCuenta();
    if (!context.mounted) return;
    Navigator.pop(context); // cierra el loader
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    // Cuenta eliminada: el stream de auth vuelve al login; salimos de ajustes.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _seccion(context, 'Apariencia'),
          ValueListenableBuilder<bool>(
            valueListenable: notificadorTema,
            builder: (_, oscuro, __) => _tarjeta(
              context,
              child: SwitchListTile(
                value: oscuro,
                onChanged: (v) => notificadorTema.value = v,
                activeColor: AppColores.acento,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                secondary: Icon(
                    oscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: AppColores.acento),
                title: Text('Modo oscuro',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorTextoFuerte(context))),
                subtitle: Text(oscuro ? 'Activado' : 'Desactivado',
                    style: TextStyle(color: colorTextoSuave(context), fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _seccion(context, 'Cuenta'),
          _tarjeta(
            context,
            child: Column(
              children: [
                _opcion(context, Icons.edit_outlined, 'Editar perfil',
                    () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  EditarPerfilScreen(usuario: usuario)),
                        )),
                _divisor(context),
                _opcion(context, Icons.mark_email_read_outlined,
                    'Verificar correo', () async {
                  final err = await AuthService().enviarVerificacionCorreo();
                  if (context.mounted) {
                    mostrarSnackBar(
                        context,
                        err ?? 'Te enviamos un correo de verificación',
                        esError: err != null);
                  }
                }),
                _divisor(context),
                _opcion(context, Icons.notifications_none_rounded, 'Notificaciones',
                    () => _proximamente(context)),
                _divisor(context),
                _opcion(context, Icons.lock_outline_rounded, 'Privacidad y seguridad',
                    () => _proximamente(context)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _seccion(context, 'Soporte'),
          _tarjeta(
            context,
            child: Column(
              children: [
                _opcion(context, Icons.help_outline_rounded, 'Centro de ayuda',
                    () => _proximamente(context)),
                _divisor(context),
                _opcion(context, Icons.info_outline_rounded, 'Acerca de Trabajito',
                    () => _proximamente(context)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColores.error,
              side: const BorderSide(color: AppColores.error, width: 1.5),
            ),
            onPressed: () => _cerrarSesion(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColores.error),
            onPressed: () => _eliminarCuenta(context),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Eliminar mi cuenta'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _seccion(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(texto,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colorTextoSuave(context),
                letterSpacing: 0.3)),
      );

  Widget _tarjeta(BuildContext context, {required Widget child}) => Container(
        decoration: BoxDecoration(
          color: colorSuperficie(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorBorde(context), width: 1),
        ),
        child: child,
      );

  Widget _opcion(BuildContext context, IconData icono, String texto,
          VoidCallback onTap) =>
      ListTile(
        onTap: onTap,
        leading: Icon(icono, color: AppColores.azulProfesional, size: 22),
        title: Text(texto,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: colorTextoFuerte(context))),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: AppColores.grisMedio),
      );

  Widget _divisor(BuildContext context) =>
      Divider(height: 1, color: colorBorde(context), indent: 16, endIndent: 16);
}
