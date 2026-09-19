import 'package:flutter/material.dart';
import '../../../../compartido/modelos/usuario.dart';
import '../../../../nucleo/espaciado/app_espaciado.dart';
import '../../../../nucleo/tema/app_colores.dart';
import '../../../../nucleo/tipografia/app_tipografia.dart';

/// Tarjeta de bienvenida en la cabecera del feed de "Trabajos".
///
/// Extraída de `trabajos_tab.dart` en la tarea 027 B-2b. Solo presentación.
///
/// **El degradado tiene 3 paradas, no 2 (tarea 039).** El dueño reportó
/// "banding"/escalones de color en el emulador sobre el `LinearGradient`
/// diagonal `principal → azulProfesional`. Investigado de verdad (no
/// asumido): capturando la pantalla real del emulador
/// (`adb exec-out screencap`) y muestreando píxeles se confirmó que el canal
/// rojo solo tiene 8 valores enteros posibles entre esos dos colores
/// (`0x0D` a `0x15`) repartidos en ~830 px de ancho — cada escalón de 1
/// unidad de R cubre ~104 px, ancho de sobra para que el ojo lo note, y sin
/// ningún ruido de dithering entre muestras (secuencia estrictamente
/// monótona, no oscilante). Revisando el motor (Impeller,
/// `linear_gradient_contents.cc`): un degradado diagonal de 2 colores no
/// entra por el "fast path" (ese exige eje horizontal/vertical), así que cae
/// en `RenderSSBO` (con dithering, `IPOrderedDither8x8`) si el backend de
/// GPU soporta SSBO, o si no en `RenderUniform` — y
/// `linear_gradient_uniform_fill.frag` **no aplica dithering en absoluto**.
/// Este emulador cae en esa segunda rama (de ahí el defecto solo ahí, no
/// necesariamente en hardware real con Vulkan/Metal). Añadir más paradas
/// sobre la misma línea recta no cambia nada (misma interpolación, mismos
/// valores); la parada intermedia usa [AppColores.azulClaro] (ya declarado,
/// no es un color nuevo) que se sale un poco de esa línea recta, así que
/// cada canal recorre su rango en dos tramos más cortos en vez de uno largo
/// — el escalón más ancho del rojo baja de ~104 px a ~46 px (verificado
/// recapturando el emulador tras el cambio). Mismo criterio en
/// `cabecera_perfil.dart` (mismo degradado exacto).
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
          // 3 paradas, no 2: ver el porqué en el docstring de la clase.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColores.principal,
              AppColores.azulClaro,
              AppColores.azulProfesional,
            ],
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
