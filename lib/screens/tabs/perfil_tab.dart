import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../utils/constantes.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/entrada_etiquetas.dart';
import '../../widgets/estrellas.dart';
import '../../widgets/resenas.dart';
import '../cartera_screen.dart';
import '../configuracion_screen.dart';
import '../mis_postulaciones_screen.dart';
import '../mis_publicaciones_screen.dart';

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
/// 3. "Deslizar para actualizar" llama a `AuthService.recargarPerfil()`, para
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
  final _authService = AuthService();
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
    final error = await _authService.recargarPerfil();
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
    final esEmpresa = esEmpleador && usuario.tipoEmpleador == 'empresa';
    final ubicacion = usuario.ciudad.isNotEmpty
        ? '${usuario.ciudad}, ${usuario.departamento}'
        : (usuario.departamento.isNotEmpty ? usuario.departamento : usuario.pais);

    return RefreshIndicator(
      color: AppColores.acento,
      onRefresh: _recargar,
      child: ListView(
        // El aviso hay que poder arrastrarlo aunque el contenido quepa en la
        // pantalla; si no, no habría forma de reintentar deslizando.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          if (widget.datosSinConfirmar) ...[
            _avisoSinConexion(context),
            const SizedBox(height: 12),
          ],

          // ── Cabecera con avatar y botón de configuración ──────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColores.principal, AppColores.azulProfesional],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => _abrirConfiguracion(context),
                    icon:
                        const Icon(Icons.settings_outlined, color: Colors.white),
                    tooltip: 'Configuración',
                  ),
                ),
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: Text(
                    usuario.iniciales,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  usuario.nombreVisible,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColores.dorado.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    esEmpleador ? 'EMPLEADOR' : 'TRABAJADOR',
                    style: const TextStyle(
                        color: AppColores.dorado,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                Estrellas(
                  valor: usuario.calificacionPromedio,
                  total: usuario.totalCalificaciones,
                  colorTexto: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Acceso rápido según rol ───────────────────────────
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => esEmpleador
                    ? MisPublicacionesScreen(usuario: usuario)
                    : MisPostulacionesScreen(usuario: usuario),
              ),
            ),
            icon: Icon(
                esEmpleador ? Icons.assignment_outlined : Icons.send_outlined),
            label: Text(esEmpleador ? 'Mis publicaciones' : 'Mis postulaciones'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CarteraScreen(usuario: usuario)),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Cartera'),
          ),
          const SizedBox(height: 20),

          // ── Información personal ──────────────────────────────
          _seccion(context, 'Información'),
          _tarjeta(context, [
            if (esEmpresa) ...[
              _fila(context, Icons.business_outlined, 'Empresa',
                  usuario.nombreEmpresa),
              _fila(context, Icons.person_outline, 'Contacto',
                  usuario.nombreCompleto),
            ] else
              _fila(context, Icons.person_outline, 'Nombre',
                  usuario.nombreCompleto),
            if (usuario.dni.isNotEmpty)
              _fila(context, Icons.badge_outlined, 'DNI', usuario.dni),
            _fila(context, Icons.email_outlined, 'Correo', usuario.correo),
            if (usuario.telefono.isNotEmpty)
              _fila(context, Icons.phone_outlined, 'Teléfono', usuario.telefono),
            if (ubicacion.isNotEmpty)
              _fila(context, Icons.location_on_outlined, 'Ubicación', ubicacion),
          ]),

          // ── Información específica por rol ─────────────────────
          if (esEmpleador) ...[
            if (usuario.sectorEmpresa.isNotEmpty) ...[
              const SizedBox(height: 20),
              _seccion(context, 'Empresa'),
              _tarjeta(context, [
                _fila(context, Icons.category_outlined, 'Sector',
                    usuario.sectorEmpresa),
                if (usuario.tamanoEmpresa.isNotEmpty)
                  _fila(context, Icons.groups_outlined, 'Tamaño',
                      usuario.tamanoEmpresa),
                if (usuario.sitioWeb.isNotEmpty)
                  _fila(context, Icons.language_outlined, 'Sitio web',
                      usuario.sitioWeb),
              ]),
            ],
            const SizedBox(height: 20),
            _seccion(context, 'Actividad'),
            _tarjeta(context, [
              _fila(context, Icons.post_add_outlined, 'Trabajos publicados',
                  '${usuario.trabajosPublicados}'),
              _fila(context, Icons.verified_outlined, 'Pagos confirmados',
                  '${usuario.pagosConfirmados}'),
            ]),
          ],

          if (!esEmpleador) ...[
            const SizedBox(height: 20),
            _seccion(context, 'Profesional'),
            _tarjeta(context, [
              _fila(context, Icons.emoji_events_outlined, 'Trabajos realizados',
                  '${usuario.trabajosCompletados}'),
              _fila(
                  context,
                  Icons.star_outline_rounded,
                  'Calificación',
                  usuario.totalCalificaciones == 0
                      ? 'Sin calificaciones'
                      : '${usuario.calificacionPromedio.toStringAsFixed(1)} ★'),
              _fila(context, Icons.schedule_outlined, 'Tiempo promedio',
                  'Próximamente'),
              _fila(context, Icons.bolt_outlined, 'Respuesta', 'Próximamente'),
              // Contar experiencias y estudios de una respuesta que no los
              // trae daría `0`, y un `0` aquí se lee como "no tengo ninguno".
              // Ver `Usuario.cvCargado`.
              if (usuario.cvCargado) ...[
                _fila(context, Icons.work_outline_rounded, 'Experiencias',
                    '${usuario.experiencia.length}'),
                _fila(context, Icons.school_outlined, 'Estudios',
                    '${usuario.estudios.length}'),
              ],
            ]),
            const SizedBox(height: 20),
            _seccion(context, 'Habilidades'),
            if (usuario.cvCargado)
              ChipsHabilidades(habilidades: usuario.habilidades)
            else
              _avisoCvSinCargar(context),
          ],

          // ── Reputación (reseñas recibidas) ────────────────────
          const SizedBox(height: 20),
          _seccion(context, 'Reputación'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: oscuro ? AppColores.superficieOscura : AppColores.blanco,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: oscuro ? AppColores.bordeOscuro : AppColores.grisClaro,
                  width: 1),
            ),
            child: ResumenCalificacion(
                valor: usuario.calificacionPromedio,
                total: usuario.totalCalificaciones),
          ),
          const SizedBox(height: 12),
          SeccionResenas(uid: usuario.uid),

          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _abrirConfiguracion(context),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Configuración'),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Trabajito · v0.1.0',
                style: TextStyle(color: textoSec, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Aviso de que lo que se ve puede no ser lo que hay en el servidor.
  ///
  /// Va arriba del todo y con tono de advertencia, no de error: la sesión
  /// funciona, lo único que pasa es que estos datos son los de la última
  /// visita.
  Widget _avisoSinConexion(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColores.advertencia.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColores.advertencia.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 20, color: AppColores.advertencia),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTextos.datosDeTuUltimaVisita,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorTextoFuerte(context))),
                const SizedBox(height: 2),
                Text(AppTextos.datosSinConfirmarDetalle,
                    style:
                        TextStyle(fontSize: 12, color: colorTextoSuave(context))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _botonReintentar(),
        ],
      ),
    );
  }

  /// El CV no vino en esta lectura. Decirlo y, sobre todo, decir que **no se
  /// ha borrado**: es exactamente lo que el usuario teme al ver su perfil a
  /// cero.
  Widget _avisoCvSinCargar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSuperficie(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorde(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 20, color: AppColores.grisMedio),
              const SizedBox(width: 10),
              Expanded(
                child: Text(AppTextos.cvSinCargar,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorTextoFuerte(context))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(AppTextos.cvSinCargarDetalle,
              style: TextStyle(fontSize: 12, color: colorTextoSuave(context))),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _botonReintentar(conTexto: true),
          ),
        ],
      ),
    );
  }

  /// Mientras hay una recarga en marcha se enseña la rueda en el sitio del
  /// botón: así se ve que la app está haciendo algo y no se puede pedir dos
  /// veces a la vez.
  Widget _botonReintentar({bool conTexto = false}) {
    if (_recargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColores.acento),
        ),
      );
    }
    if (conTexto) {
      return OutlinedButton.icon(
        onPressed: _recargar,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Reintentar'),
      );
    }
    return IconButton(
      onPressed: _recargar,
      icon: const Icon(Icons.refresh_rounded, color: AppColores.advertencia),
      tooltip: 'Actualizar',
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _seccion(BuildContext context, String texto) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(texto,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: oscuro ? AppColores.grisMedio : AppColores.grisTexto,
              letterSpacing: 0.3)),
    );
  }

  Widget _tarjeta(BuildContext context, List<Widget> hijos) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final conDivisores = <Widget>[];
    for (var i = 0; i < hijos.length; i++) {
      conDivisores.add(hijos[i]);
      if (i < hijos.length - 1) {
        conDivisores
            .add(Divider(height: 1, color: borde, indent: 16, endIndent: 16));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde, width: 1),
      ),
      child: Column(children: conDivisores),
    );
  }

  Widget _fila(
      BuildContext context, IconData icono, String titulo, String valor) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, color: AppColores.azulProfesional, size: 20),
          const SizedBox(width: 12),
          Text(titulo,
              style: TextStyle(
                  color: textoSec, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(valor,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: textoPrincipal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
