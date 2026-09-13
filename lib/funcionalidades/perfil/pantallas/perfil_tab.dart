import 'package:flutter/material.dart';
import '../../../compartido/modelos/usuario.dart';
import 'package:provider/provider.dart';
import '../datos/perfil_service.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import '../../../compartido/widgets/mostrar_snackbar.dart';
import '../../../compartido/widgets/resenas.dart';
import '../../../screens/cartera_screen.dart';
import 'configuracion_screen.dart';
import '../../postulaciones/pantallas/mis_postulaciones_screen.dart';
import '../../trabajos/pantallas/mis_publicaciones_screen.dart';
import 'widgets/accesos_rapidos_perfil.dart';
import 'widgets/avisos_perfil.dart';
import 'widgets/cabecera_perfil.dart';
import 'widgets/info_personal_perfil.dart';
import 'widgets/piezas_perfil.dart';

/// Pestaña "Perfil": visualización del perfil del usuario.
///
/// **Por qué esta pantalla tiene estado desde la tarea 023.** El perfil que
/// enseña no siempre viene de una lectura fresca del servidor: cuando la app
/// arranca sin conexión, `AuthService.restaurarSesion()` entra con el perfil
/// que se guardó junto a la sesión (el del login), que **no trae el CV** y
/// puede estar viejo en todo lo demás. Antes eso se pintaba tal cual
/// —`Experiencias 0`, `Estudios 0`, "Sin habilidades registradas"— y el
/// usuario lo leía como *"la app me borró el CV"*, que es falso y alarmante.
///
/// Aquí se hacen tres cosas, y las tres son la misma idea: no prometer datos
/// que no se tienen.
///
/// 1. Si el perfil no se pudo confirmar contra el servidor
///    (`EstadoSesion.avisoSinConexion`, que llega por [datosSinConfirmar]), se
///    dice arriba del todo, con su botón de reintentar.
/// 2. Si el CV no viene en esta lectura ([Usuario.cvCargado] a `false`), no se
///    pintan sus secciones a cero: se dice que no se pudieron cargar y que
///    **no se ha borrado nada**.
/// 3. "Deslizar para actualizar" llama a `PerfilService.recargarPerfil()`, para
///    que al volver la conexión el usuario arregle esto sin reiniciar la app
///    (antes solo se arreglaba cerrando y abriendo, o editando el perfil).
///
/// Carga puntual + deslizar para actualizar es la decisión del `tech-lead`
/// para la fase 2 (ver tarea 018): nada de streams ni de sondeo.
class PerfilTab extends StatefulWidget {
  final Usuario usuario;

  /// `true` cuando la sesión se restauró del dispositivo y **no se pudo
  /// confirmar** contra el servidor. Lo pone `InicioScreen` desde
  /// `EstadoSesion.avisoSinConexion`.
  final bool datosSinConfirmar;

  const PerfilTab({
    super.key,
    required this.usuario,
    this.datosSinConfirmar = false,
  });

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  /// Inyectado por `provider` (ADR-0014). Se resuelve en el primer uso, que
  /// es siempre desde un manejador de evento o un post-frame callback.
  late final PerfilService _perfilService = context.read<PerfilService>();
  bool _recargando = false;

  @override
  void initState() {
    super.initState();
    // Un único intento al abrir la pestaña, y solo si ya se sabe que lo que
    // hay en la mano está incompleto o sin confirmar. No es sondeo: no se
    // repite, no hay temporizador, y con conexión no llega a pasar nunca
    // (login y registro ya piden el perfil entero).
    if (_datosDudosos) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recargar(silencioso: true);
      });
    }
  }

  /// El perfil que se está enseñando puede no ser el que hay en el servidor.
  bool get _datosDudosos =>
      widget.datosSinConfirmar || !widget.usuario.cvCargado;

  /// Vuelve a pedir el perfil propio. Al publicarlo en la sesión,
  /// `avisoSinConexion` vuelve a `false` y el CV llega completo, así que los
  /// avisos desaparecen solos.
  ///
  /// [silencioso] evita el `SnackBar` de error en el intento automático: si no
  /// hay conexión, el aviso que ya está en pantalla lo explica mejor que un
  /// mensaje que aparece sin que el usuario haya pedido nada.
  Future<void> _recargar({bool silencioso = false}) async {
    if (_recargando) return;
    setState(() => _recargando = true);
    final error = await _perfilService.recargarPerfil();
    if (!mounted) return;
    setState(() => _recargando = false);
    if (error != null && !silencioso) {
      mostrarSnackBar(context, error, esError: true);
    }
  }

  void _abrirConfiguracion(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ConfiguracionScreen(usuario: widget.usuario)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final esEmpleador = usuario.esEmpleador;
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      color: AppColores.acento,
      onRefresh: _recargar,
      child: ListView(
        // El aviso hay que poder arrastrarlo aunque el contenido quepa en la
        // pantalla; si no, no habría forma de reintentar deslizando.
        physics: const AlwaysScrollableScrollPhysics(),
        // El 90 (espacio para no quedar bajo el `BottomNavigationBar`) se deja
        // literal: no forma parte del rango medido por la auditoría de la 031
        // (2 a 40) y no es un hueco entre elementos, es una reserva de
        // espacio para otro widget — mismo criterio que dejó intactos los
        // tamaños de componente (spinners, iconos) en 032-036.
        padding: const EdgeInsets.fromLTRB(
            AppEspaciado.lg, AppEspaciado.lg, AppEspaciado.lg, 90),
        children: [
          if (widget.datosSinConfirmar) ...[
            AvisoSinConexionPerfil(
                recargando: _recargando, onReintentar: _recargar),
            const SizedBox(height: AppEspaciado.md),
          ],

          CabeceraPerfil(
            usuario: usuario,
            esEmpleador: esEmpleador,
            onConfiguracion: () => _abrirConfiguracion(context),
          ),
          const SizedBox(height: AppEspaciado.lg),

          AccesosRapidosPerfil(
            esEmpleador: esEmpleador,
            onMisTrabajos: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => esEmpleador
                    ? MisPublicacionesScreen(usuario: usuario)
                    : MisPostulacionesScreen(usuario: usuario),
              ),
            ),
            onCartera: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CarteraScreen(usuario: usuario)),
            ),
          ),
          const SizedBox(height: AppEspaciado.xl),

          InfoPersonalPerfil(
            usuario: usuario,
            recargando: _recargando,
            onReintentar: _recargar,
          ),

          // ── Reputación (reseñas recibidas) ────────────────────
          const SizedBox(height: AppEspaciado.xl),
          const SeccionPerfil('Reputación'),
          Container(
            padding: const EdgeInsets.all(AppEspaciado.lg),
            decoration: BoxDecoration(
              color: oscuro ? AppColores.superficieOscura : AppColores.blanco,
              borderRadius: BorderRadius.circular(AppRadios.tarjeta),
              border: Border.all(
                  color: oscuro ? AppColores.bordeOscuro : AppColores.grisClaro,
                  width: 1),
            ),
            child: ResumenCalificacion(
                valor: usuario.calificacionPromedio,
                total: usuario.totalCalificaciones),
          ),
          const SizedBox(height: AppEspaciado.md),
          SeccionResenas(uid: usuario.uid),

          const SizedBox(height: AppEspaciado.xl),
          OutlinedButton.icon(
            onPressed: () => _abrirConfiguracion(context),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Configuración'),
          ),
          const SizedBox(height: AppEspaciado.sm),
          Center(
            child: Text('Trabajito · v0.1.0',
                style: tt.etiqueta.copyWith(color: textoSec, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
