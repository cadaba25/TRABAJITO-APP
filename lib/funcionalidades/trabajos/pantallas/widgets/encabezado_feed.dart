import 'package:flutter/material.dart';
import '../../../../compartido/modelos/usuario.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Tarjeta de bienvenida en la cabecera del feed de "Trabajos".
///
/// Extraída de `trabajos_tab.dart` en la tarea 027 B-2b. Solo presentación.
class EncabezadoFeed extends StatelessWidget {
  final Usuario usuario;
  final bool esEmpleador;

  const EncabezadoFeed({
    super.key,
    required this.usuario,
    required this.esEmpleador,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = usuario.nombreVisible;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.lg),
      child: Container(
        padding: const EdgeInsets.all(AppEspaciado.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColores.principal, AppColores.azulProfesional],
          ),
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Text(usuario.iniciales,
                  style:
                      tt.cuerpoChico.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: AppEspaciado.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.subtitulo.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    esEmpleador
                        ? 'Publica un trabajo y recibe propuestas'
                        : 'Descubre nuevas oportunidades',
                    style: tt.etiqueta.copyWith(
                        color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
