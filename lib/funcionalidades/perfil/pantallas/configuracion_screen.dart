import 'package:flutter/material.dart';
import '../../../compartido/modelos/usuario.dart';
import 'package:provider/provider.dart';
import '../../autenticacion/datos/auth_service.dart';
import '../../../compartido/widgets/boton_destructivo.dart';
import '../../../compartido/widgets/boton_secundario.dart';
import '../../../compartido/widgets/boton_texto.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tema/notificador_tema.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import 'editar_perfil_screen.dart';

/// Pantalla de configuración: tema, cuenta y opciones.
class ConfiguracionScreen extends StatelessWidget {
  final Usuario usuario;
  const ConfiguracionScreen({super.key, required this.usuario});

  void _proximamente(BuildContext context) {
    mostrarSnackBar(context, 'Función disponible próximamente');
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    // Se lee antes del diálogo: `context` no debe usarse tras un `await`.
    final auth = context.read<AuthService>();
    final tt = Theme.of(context).textTheme;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
        title: Text('¿Cerrar sesión?',
            style: tt.subtitulo.copyWith(color: colorTextoFuerte(ctx))),
        content: Text('Se cerrará tu sesión actual.',
            style: tt.cuerpo.copyWith(color: colorTextoSuave(ctx))),
        actions: [
          BotonTexto(
            texto: 'Cancelar',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          BotonDestructivo(
            texto: 'Salir',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await auth.cerrarSesion();
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    // Se lee antes del diálogo: `context` no debe usarse tras un `await`.
    final auth = context.read<AuthService>();
    final tt = Theme.of(context).textTheme;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
        title: Text('¿Dar de baja tu cuenta?',
            style: tt.subtitulo.copyWith(color: colorTextoFuerte(ctx))),
        // El texto anterior prometía un borrado permanente. El backend hace
        // una baja lógica (`activo = false`) para no destruir el historial de
        // trabajos, pagos y calificaciones de las otras personas implicadas.
        // Verificado: después ya no se puede iniciar sesión.
        content: Text(
            'Tu cuenta se desactivará y no podrás volver a iniciar sesión. '
            'Tu historial de trabajos y pagos se conserva, porque también es '
            'el historial de las personas con las que trabajaste.',
            style: tt.cuerpo.copyWith(color: colorTextoSuave(ctx))),
        actions: [
          BotonTexto(
            texto: 'Cancelar',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          BotonDestructivo(
            texto: 'Dar de baja',
            onPressed: () => Navigator.pop(ctx, true),
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
    final error = await auth.darDeBajaCuenta();
    if (!context.mounted) return;
    Navigator.pop(context); // cierra el loader
    if (error != null) {
      mostrarSnackBar(context, error, esError: true);
      return;
    }
    // Cuenta dada de baja y sesión cerrada: `PantallaInicial` vuelve al login
    // en cuanto se sale de las pantallas apiladas.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración', style: Theme.of(context).textTheme.titulo),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppEspaciado.lg),
        children: [
          _seccion(context, 'Apariencia'),
          ValueListenableBuilder<bool>(
            valueListenable: notificadorTema,
            builder: (_, oscuro, _) => _tarjeta(
              context,
              child: SwitchListTile(
                value: oscuro,
                onChanged: (v) => notificadorTema.value = v,
                activeThumbColor: AppColores.acento,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppEspaciado.md),
                // Ícono informativo de la fila (no fondo/borde/spinner):
                // mismo contraste corregido que el resto (tarea 051).
                secondary: Icon(
                    oscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: colorAcentoTexto(context)),
                title: Text('Modo oscuro',
                    style: Theme.of(context).textTheme.cuerpo.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorTextoFuerte(context))),
                subtitle: Text(oscuro ? 'Activado' : 'Desactivado',
                    style: Theme.of(context)
                        .textTheme
                        .cuerpoChico
                        .copyWith(color: colorTextoSuave(context))),
              ),
            ),
          ),
          const SizedBox(height: AppEspaciado.xl),

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
                // Firebase enviaba el correo de verificación por su cuenta. El
                // backend propio no tiene ese endpoint todavía, así que la
                // opción se queda avisando en vez de prometer un correo que
                // nadie manda.
                _opcion(context, Icons.mark_email_read_outlined,
                    'Verificar correo', () async {
                  final aviso = await context.read<AuthService>().enviarVerificacionCorreo();
                  if (context.mounted && aviso != null) {
                    mostrarSnackBar(context, aviso);
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
          const SizedBox(height: AppEspaciado.xl),

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
          const SizedBox(height: AppEspaciado.xl),

          BotonSecundario(
            texto: 'Cerrar sesión',
            icono: Icons.logout_rounded,
            color: AppColores.error,
            onPressed: () => _cerrarSesion(context),
          ),
          const SizedBox(height: AppEspaciado.md),
          BotonTexto(
            texto: 'Eliminar mi cuenta',
            icono: Icons.delete_forever_rounded,
            color: AppColores.error,
            onPressed: () => _eliminarCuenta(context),
          ),
          // 40 no cae en la escala (tope `xxl`=32): se deja en `xxl`, el rol
          // más cercano disponible, mismo criterio que 035 usó para el 28 sin
          // rol exacto por arriba.
          const SizedBox(height: AppEspaciado.xxl),
        ],
      ),
    );
  }

  Widget _seccion(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.only(
            left: AppEspaciado.xs, bottom: AppEspaciado.md),
        child: Text(texto,
            style: Theme.of(context).textTheme.cuerpoChico.copyWith(
                fontWeight: FontWeight.w800,
                color: colorTextoSuave(context),
                letterSpacing: 0.3)),
      );

  Widget _tarjeta(BuildContext context, {required Widget child}) => Container(
        decoration: BoxDecoration(
          color: colorSuperficie(context),
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
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
            style: Theme.of(context).textTheme.cuerpo.copyWith(
                fontWeight: FontWeight.w600, color: colorTextoFuerte(context))),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: AppColores.grisMedio),
      );

  Widget _divisor(BuildContext context) => Divider(
      height: 1,
      color: colorBorde(context),
      indent: AppEspaciado.lg,
      endIndent: AppEspaciado.lg);
}
