import 'package:flutter/material.dart';
import '../../../../compartido/modelos/usuario.dart';
import '../../../../compartido/widgets/entrada_etiquetas.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import 'avisos_perfil.dart';
import 'piezas_perfil.dart';

/// Bloque "Información" de la pestaña "Perfil" más las secciones específicas de
/// cada rol (Empresa/Actividad para el empleador; Profesional/Habilidades para
/// el trabajador). Extraído de `perfil_tab.dart` en la tarea 027 B-2b.
///
/// Solo presentación: [recargando] y [onReintentar] son para el aviso de CV sin
/// cargar, cuya lógica de recarga vive en el `State` de la pestaña.
class InfoPersonalPerfil extends StatelessWidget {
  final Usuario usuario;
  final bool recargando;
  final VoidCallback onReintentar;

  const InfoPersonalPerfil({
    super.key,
    required this.usuario,
    required this.recargando,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    final esEmpleador = u.esEmpleador;
    final esEmpresa = esEmpleador && u.tipoEmpleador == 'empresa';
    final ubicacion = u.ciudad.isNotEmpty
        ? '${u.ciudad}, ${u.departamento}'
        : (u.departamento.isNotEmpty ? u.departamento : u.pais);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SeccionPerfil('Información'),
        TarjetaPerfil(hijos: [
          if (esEmpresa) ...[
            FilaPerfil(Icons.business_outlined, 'Empresa', u.nombreEmpresa),
            FilaPerfil(Icons.person_outline, 'Contacto', u.nombreCompleto),
          ] else
            FilaPerfil(Icons.person_outline, 'Nombre', u.nombreCompleto),
          if (u.dni.isNotEmpty)
            FilaPerfil(Icons.badge_outlined, 'DNI', u.dni),
          FilaPerfil(Icons.email_outlined, 'Correo', u.correo),
          if (u.telefono.isNotEmpty)
            FilaPerfil(Icons.phone_outlined, 'Teléfono', u.telefono),
          if (ubicacion.isNotEmpty)
            FilaPerfil(Icons.location_on_outlined, 'Ubicación', ubicacion),
        ]),

        if (esEmpleador) ...[
          if (u.sectorEmpresa.isNotEmpty) ...[
            const SizedBox(height: AppEspaciado.xl),
            const SeccionPerfil('Empresa'),
            TarjetaPerfil(hijos: [
              FilaPerfil(
                  Icons.category_outlined, 'Sector', u.sectorEmpresa),
              if (u.tamanoEmpresa.isNotEmpty)
                FilaPerfil(
                    Icons.groups_outlined, 'Tamaño', u.tamanoEmpresa),
              if (u.sitioWeb.isNotEmpty)
                FilaPerfil(Icons.language_outlined, 'Sitio web', u.sitioWeb),
            ]),
          ],
          const SizedBox(height: AppEspaciado.xl),
          const SeccionPerfil('Actividad'),
          TarjetaPerfil(hijos: [
            FilaPerfil(Icons.post_add_outlined, 'Trabajos publicados',
                '${u.trabajosPublicados}'),
            FilaPerfil(Icons.verified_outlined, 'Pagos confirmados',
                '${u.pagosConfirmados}'),
          ]),
        ],

        if (!esEmpleador) ...[
          const SizedBox(height: AppEspaciado.xl),
          const SeccionPerfil('Profesional'),
          TarjetaPerfil(hijos: [
            FilaPerfil(Icons.emoji_events_outlined, 'Trabajos realizados',
                '${u.trabajosCompletados}'),
            FilaPerfil(
                Icons.star_outline_rounded,
                'Calificación',
                u.totalCalificaciones == 0
                    ? 'Sin calificaciones'
                    : '${u.calificacionPromedio.toStringAsFixed(1)} ★'),
            FilaPerfil(Icons.schedule_outlined, 'Tiempo promedio',
                'Próximamente'),
            FilaPerfil(Icons.bolt_outlined, 'Respuesta', 'Próximamente'),
            // Contar experiencias y estudios de una respuesta que no los trae
            // daría `0`, y un `0` aquí se lee como "no tengo ninguno".
            // Ver `Usuario.cvCargado`.
            if (u.cvCargado) ...[
              FilaPerfil(Icons.work_outline_rounded, 'Experiencias',
                  '${u.experiencia.length}'),
              FilaPerfil(
                  Icons.school_outlined, 'Estudios', '${u.estudios.length}'),
            ],
          ]),
          const SizedBox(height: AppEspaciado.xl),
          const SeccionPerfil('Habilidades'),
          if (u.cvCargado)
            ChipsHabilidades(habilidades: u.habilidades)
          else
            AvisoCvSinCargar(
                recargando: recargando, onReintentar: onReintentar),
        ],
      ],
    );
  }
}
