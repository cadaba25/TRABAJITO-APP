import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../utils/constantes.dart';
import '../widgets/entrada_etiquetas.dart';
import '../widgets/resenas.dart';

/// Perfil de solo lectura de un trabajador (visto por el contratador).
class DetalleTrabajadorScreen extends StatelessWidget {
  final Usuario usuario;
  const DetalleTrabajadorScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final superficie = oscuro ? AppColores.superficieOscura : AppColores.blanco;
    final borde = oscuro ? AppColores.bordeOscuro : AppColores.grisClaro;
    final textoPrincipal = oscuro ? AppColores.textoOscuro : AppColores.texto;
    final textoSec = oscuro ? AppColores.grisMedio : AppColores.grisTexto;
    final ubicacion = usuario.ciudad.isNotEmpty
        ? '${usuario.ciudad}, ${usuario.departamento}'
        : (usuario.departamento.isNotEmpty ? usuario.departamento : usuario.pais);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cabecera
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
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  child: Text(usuario.iniciales,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 12),
                Text(usuario.nombreCompleto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Promedio estético
          _tarjeta(superficie, borde,
              ResumenCalificacion(
                  valor: usuario.calificacionPromedio,
                  total: usuario.totalCalificaciones)),
          const SizedBox(height: 20),

          if (usuario.presentacion.isNotEmpty) ...[
            _titulo('Sobre mí', textoPrincipal),
            const SizedBox(height: 8),
            Text(usuario.presentacion,
                style: TextStyle(color: textoSec, fontSize: 14, height: 1.5)),
            const SizedBox(height: 20),
          ],

          // Habilidades
          _titulo('Habilidades', textoPrincipal),
          const SizedBox(height: 10),
          ChipsHabilidades(habilidades: usuario.habilidades),
          const SizedBox(height: 20),

          // Estadísticas
          _tarjeta(
            superficie,
            borde,
            Column(
              children: [
                _fila(Icons.emoji_events_outlined, 'Trabajos completados',
                    '${usuario.trabajosCompletados}', textoPrincipal, textoSec, borde),
                _fila(Icons.work_outline_rounded, 'Experiencias',
                    '${usuario.experiencia.length}', textoPrincipal, textoSec, borde),
                _fila(Icons.school_outlined, 'Estudios',
                    '${usuario.estudios.length}', textoPrincipal, textoSec, borde),
                if (ubicacion.isNotEmpty)
                  _fila(Icons.location_on_outlined, 'Ubicación', ubicacion,
                      textoPrincipal, textoSec, borde, ultimo: true),
              ],
            ),
          ),

          if (usuario.experiencia.isNotEmpty) ...[
            const SizedBox(height: 20),
            _titulo('Experiencia', textoPrincipal),
            const SizedBox(height: 8),
            ...usuario.experiencia.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${e.puesto} — ${e.empresa}',
                      style: TextStyle(color: textoSec, fontSize: 13)),
                )),
          ],

          const SizedBox(height: 20),
          _titulo('Reseñas', textoPrincipal),
          const SizedBox(height: 10),
          SeccionResenas(uid: usuario.uid),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _titulo(String texto, Color color) => Text(texto,
      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800));

  Widget _tarjeta(Color superficie, Color borde, Widget hijo) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borde, width: 1),
        ),
        child: hijo,
      );

  Widget _fila(IconData icono, String titulo, String valor, Color principal,
      Color sec, Color borde, {bool ultimo = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icono, color: AppColores.azulProfesional, size: 20),
              const SizedBox(width: 12),
              Text(titulo,
                  style: TextStyle(
                      color: sec, fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(valor,
                  style: TextStyle(
                      color: principal, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        if (!ultimo) Divider(height: 1, color: borde),
      ],
    );
  }
}
