import 'package:flutter/material.dart';
import '../../../compartido/modelos/usuario.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import '../../../compartido/widgets/entrada_etiquetas.dart';
import '../../../compartido/widgets/resenas.dart';

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
    final tt = Theme.of(context).textTheme;
    final ubicacion = usuario.ciudad.isNotEmpty
        ? '${usuario.ciudad}, ${usuario.departamento}'
        : (usuario.departamento.isNotEmpty ? usuario.departamento : usuario.pais);

    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil', style: tt.titulo),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppEspaciado.lg),
        children: [
          // Cabecera
          Container(
            padding: const EdgeInsets.all(AppEspaciado.xl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColores.principal, AppColores.azulProfesional],
              ),
              borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: Text(usuario.iniciales,
                      style: tt.tituloGrande.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: AppEspaciado.md),
                Text(usuario.nombreCompleto,
                    textAlign: TextAlign.center,
                    style: tt.titulo.copyWith(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: AppEspaciado.xl),

          // Promedio estético
          _tarjeta(superficie, borde,
              ResumenCalificacion(
                  valor: usuario.calificacionPromedio,
                  total: usuario.totalCalificaciones)),
          const SizedBox(height: AppEspaciado.xl),

          if (usuario.presentacion.isNotEmpty) ...[
            _titulo('Sobre mí', textoPrincipal, tt),
            const SizedBox(height: AppEspaciado.sm),
            Text(usuario.presentacion, style: tt.cuerpo.copyWith(color: textoSec)),
            const SizedBox(height: AppEspaciado.xl),
          ],

          // Habilidades
          _titulo('Habilidades', textoPrincipal, tt),
          const SizedBox(height: AppEspaciado.md),
          ChipsHabilidades(habilidades: usuario.habilidades),
          const SizedBox(height: AppEspaciado.xl),

          // Estadísticas
          _tarjeta(
            superficie,
            borde,
            Column(
              children: [
                _fila(Icons.emoji_events_outlined, 'Trabajos completados',
                    '${usuario.trabajosCompletados}', textoPrincipal, textoSec, borde, tt),
                _fila(Icons.work_outline_rounded, 'Experiencias',
                    '${usuario.experiencia.length}', textoPrincipal, textoSec, borde, tt),
                _fila(Icons.school_outlined, 'Estudios',
                    '${usuario.estudios.length}', textoPrincipal, textoSec, borde, tt),
                if (ubicacion.isNotEmpty)
                  _fila(Icons.location_on_outlined, 'Ubicación', ubicacion,
                      textoPrincipal, textoSec, borde, tt, ultimo: true),
              ],
            ),
          ),

          if (usuario.experiencia.isNotEmpty) ...[
            const SizedBox(height: AppEspaciado.xl),
            _titulo('Experiencia', textoPrincipal, tt),
            const SizedBox(height: AppEspaciado.sm),
            ...usuario.experiencia.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppEspaciado.sm),
                  child: Text('• ${e.puesto} — ${e.empresa}',
                      style: tt.cuerpoChico.copyWith(color: textoSec)),
                )),
          ],

          const SizedBox(height: AppEspaciado.xl),
          _titulo('Reseñas', textoPrincipal, tt),
          const SizedBox(height: AppEspaciado.md),
          SeccionResenas(uid: usuario.uid),
          const SizedBox(height: AppEspaciado.xl),
        ],
      ),
    );
  }

  Widget _titulo(String texto, Color color, TextTheme tt) =>
      Text(texto, style: tt.subtitulo.copyWith(color: color, fontWeight: FontWeight.w800));

  Widget _tarjeta(Color superficie, Color borde, Widget hijo) => Container(
        padding: const EdgeInsets.all(AppEspaciado.lg),
        decoration: BoxDecoration(
          color: superficie,
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          border: Border.all(color: borde, width: 1),
        ),
        child: hijo,
      );

  Widget _fila(IconData icono, String titulo, String valor, Color principal,
      Color sec, Color borde, TextTheme tt, {bool ultimo = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppEspaciado.md),
          child: Row(
            children: [
              Icon(icono, color: AppColores.azulProfesional, size: 20),
              const SizedBox(width: AppEspaciado.md),
              Text(titulo, style: tt.cuerpoChico.copyWith(color: sec)),
              const Spacer(),
              Text(valor,
                  style:
                      tt.cuerpoChico.copyWith(color: principal, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        if (!ultimo) Divider(height: 1, color: borde),
      ],
    );
  }
}
