import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../utils/constantes.dart';
import '../../widgets/estrellas.dart';
import '../configuracion_screen.dart';
import '../mis_postulaciones_screen.dart';
import '../mis_publicaciones_screen.dart';

/// Pestaña "Perfil": visualización del perfil del usuario.
class PerfilTab extends StatelessWidget {
  final Usuario usuario;
  const PerfilTab({super.key, required this.usuario});

  void _abrirConfiguracion(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final esEmpleador = usuario.esEmpleador;
    final esEmpresa = esEmpleador && usuario.tipoEmpleador == 'empresa';
    final ubicacion = usuario.ciudad.isNotEmpty
        ? '${usuario.ciudad}, ${usuario.departamento}'
        : (usuario.departamento.isNotEmpty ? usuario.departamento : usuario.pais);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
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
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: 'Configuración',
                ),
              ),
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.white.withOpacity(0.18),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColores.dorado.withOpacity(0.20),
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
          icon: Icon(esEmpleador
              ? Icons.assignment_outlined
              : Icons.send_outlined),
          label: Text(esEmpleador ? 'Mis publicaciones' : 'Mis postulaciones'),
        ),
        const SizedBox(height: 20),

        // ── Información personal ──────────────────────────────
        _seccion(context, 'Información'),
        _tarjeta(context, [
          if (esEmpresa) ...[
            _fila(context, Icons.business_outlined, 'Empresa', usuario.nombreEmpresa),
            _fila(context, Icons.person_outline, 'Contacto', usuario.nombreCompleto),
          ] else
            _fila(context, Icons.person_outline, 'Nombre', usuario.nombreCompleto),
          if (usuario.dni.isNotEmpty)
            _fila(context, Icons.badge_outlined, 'DNI', usuario.dni),
          _fila(context, Icons.email_outlined, 'Correo', usuario.correo),
          if (usuario.telefono.isNotEmpty)
            _fila(context, Icons.phone_outlined, 'Teléfono', usuario.telefono),
          if (ubicacion.isNotEmpty)
            _fila(context, Icons.location_on_outlined, 'Ubicación', ubicacion),
        ]),

        // ── Información específica por rol ─────────────────────
        if (esEmpleador && usuario.sectorEmpresa.isNotEmpty) ...[
          const SizedBox(height: 20),
          _seccion(context, 'Empresa'),
          _tarjeta(context, [
            _fila(context, Icons.category_outlined, 'Sector', usuario.sectorEmpresa),
            if (usuario.tamanoEmpresa.isNotEmpty)
              _fila(context, Icons.groups_outlined, 'Tamaño', usuario.tamanoEmpresa),
            if (usuario.sitioWeb.isNotEmpty)
              _fila(context, Icons.language_outlined, 'Sitio web', usuario.sitioWeb),
          ]),
        ],

        if (!esEmpleador) ...[
          const SizedBox(height: 20),
          _seccion(context, 'Profesional'),
          _tarjeta(context, [
            _fila(context, Icons.emoji_events_outlined, 'Trabajos completados',
                '${usuario.trabajosCompletados}'),
            _fila(context, Icons.work_outline_rounded, 'Experiencias',
                '${usuario.experiencia.length}'),
            _fila(context, Icons.school_outlined, 'Estudios',
                '${usuario.estudios.length}'),
          ]),
        ],

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
        conDivisores.add(Divider(height: 1, color: borde, indent: 16, endIndent: 16));
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

  Widget _fila(BuildContext context, IconData icono, String titulo, String valor) {
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
