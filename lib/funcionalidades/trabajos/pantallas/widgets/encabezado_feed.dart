import 'package:flutter/material.dart';
import '../../../../compartido/modelos/usuario.dart';
import '../../../../nucleo/tema/app_colores.dart';

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColores.principal, AppColores.azulProfesional],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Text(
                usuario.iniciales,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800),
                  ),
                  Text(
                    esEmpleador
                        ? 'Publica un trabajo y recibe propuestas'
                        : 'Descubre nuevas oportunidades',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12),
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
