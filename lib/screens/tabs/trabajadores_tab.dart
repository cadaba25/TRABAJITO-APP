import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../utils/constantes.dart';

/// Pestaña "Trabajadores": lista de profesionales registrados.
class TrabajadoresTab extends StatefulWidget {
  const TrabajadoresTab({super.key});

  @override
  State<TrabajadoresTab> createState() => _TrabajadoresTabState();
}

class _TrabajadoresTabState extends State<TrabajadoresTab> {
  final _authService = AuthService();

  void _proximamente() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Función disponible próximamente'),
        backgroundColor: AppColores.principal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Habilidad o estudio principal para mostrar como subtítulo.
  String _especialidad(Usuario u) {
    if (u.experiencia.isNotEmpty) {
      final e = u.experiencia.first;
      if (e.puesto.isNotEmpty) return e.puesto;
      if (e.habilidades.isNotEmpty) return e.habilidades;
    }
    if (u.estudios.isNotEmpty && u.estudios.first.nivel.isNotEmpty) {
      return u.estudios.first.nivel;
    }
    return 'Profesional';
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Usuario>>(
      stream: _authService.streamTrabajadores(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColores.acento));
        }
        // Solo trabajadores con registro completo, ordenados por nombre.
        final trabajadores = (snapshot.data ?? [])
            .where((u) => u.registroCompleto)
            .toList()
          ..sort((a, b) =>
              a.nombreCompleto.toLowerCase().compareTo(b.nombreCompleto.toLowerCase()));

        if (trabajadores.isEmpty) {
          return _estadoVacio(oscuro);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: trabajadores.length,
          itemBuilder: (context, i) => _tarjeta(trabajadores[i], oscuro),
        );
      },
    );
  }

  Widget _tarjeta(Usuario u, bool oscuro) {
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final ubicacion = u.ciudad.isNotEmpty
        ? '${u.ciudad}, ${u.departamento}'
        : (u.departamento.isNotEmpty ? u.departamento : u.pais);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColores.acento.withOpacity(0.15),
            child: Text(
              u.iniciales,
              style: const TextStyle(
                  color: AppColores.acento,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.nombreCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: textoPrincipal,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _especialidad(u),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColores.acento,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: textoSec),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        ubicacion.isEmpty ? 'Honduras' : ubicacion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textoSec, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _proximamente,
            icon: const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColores.grisMedio),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio(bool oscuro) {
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 56, color: AppColores.grisMedio),
          const SizedBox(height: 14),
          Text(
            'Aún no hay trabajadores registrados.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textoSec, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
