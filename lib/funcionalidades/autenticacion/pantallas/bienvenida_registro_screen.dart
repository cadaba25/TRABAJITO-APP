import 'package:flutter/material.dart';
import '../../../compartido/widgets/boton_icono.dart';
import '../../../compartido/widgets/boton_texto.dart';
import '../../../compartido/widgets/pulsa_con_escala.dart';
import '../../../nucleo/tema/app_colores.dart';
import '../../../nucleo/tema/colores_por_tema.dart';
import '../../../compartido/widgets/logo_trabajito.dart';
import '../../../nucleo/tipografia/app_tipografia.dart';
import '../../../nucleo/espaciado/app_espaciado.dart';
import 'registro_trabajador_screen.dart';
import 'registro_empleador_screen.dart';

/// Pantalla de bienvenida al registro
/// El usuario elige si busca trabajo o quiere contratar
class BienvenidaRegistroScreen extends StatelessWidget {
  const BienvenidaRegistroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BotonIcono(
          icono: Icons.arrow_back_ios_new_rounded,
          color: colorTextoFuerte(context),
          tooltip: 'Atrás',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppEspaciado.lg),

              // ── LOGO ───────────────────────────────────
              LogoTrabajito(altura: 36, colorTexto: colorTextoFuerte(context)),

              const SizedBox(height: AppEspaciado.xxl),

              // ── TÍTULO ─────────────────────────────────
              // Mismo criterio que `login_screen`: el renglón principal
              // ("hero") de una pantalla de autenticación usa `tituloGrande`
              // y el renglón de apoyo usa `titulo` — así el "¡Hola!" de aquí
              // y el "Bienvenido" de login quedan al mismo nivel de
              // jerarquía (tarea 032).
              Text(
                '¡Hola!',
                // Contraste: dorado como texto sobre superficie clara
                // necesita `colorAcentoTexto` (ADR-0016, tarea 051).
                style: Theme.of(context)
                    .textTheme
                    .tituloGrande
                    .copyWith(color: colorAcentoTexto(context)),
              ),
              const SizedBox(height: AppEspaciado.xs),
              Text(
                '¿Qué te trae a Trabajito?',
                style: Theme.of(context)
                    .textTheme
                    .titulo
                    .copyWith(color: colorTextoFuerte(context)),
              ),

              const SizedBox(height: AppEspaciado.xxl),

              // ── OPCIÓN: BUSCO TRABAJO ──────────────────
              _TarjetaOpcion(
                titulo: 'Busco trabajo',
                descripcion:
                    'Te ayudamos a encontrar las oportunidades que mejor se ajusten a tu perfil y objetivos.',
                icono: Icons.search_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroTrabajadorScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppEspaciado.lg),

              // ── OPCIÓN: BUSCO CONTRATAR ────────────────
              _TarjetaOpcion(
                titulo: 'Busco contratar',
                descripcion:
                    'Te ayudamos a conectar con los mejores profesionales de Honduras de acuerdo a tus necesidades.',
                icono: Icons.business_center_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroEmpleadorScreen(),
                    ),
                  );
                },
              ),

              const Spacer(),

              // ── PIE ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿Ya tienes una cuenta? ',
                      style: Theme.of(context)
                          .textTheme
                          .cuerpo
                          .copyWith(color: colorTextoSuave(context))),
                  BotonTexto(
                    texto: 'Inicia sesión',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppEspaciado.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaOpcion extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final VoidCallback onTap;
  final bool proximamente;

  const _TarjetaOpcion({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.onTap,
    this.proximamente = false,
  });

  @override
  Widget build(BuildContext context) {
    // Feedback al tacto (tarea 055): escala 0.97 al presionar.
    return PulsaConEscala(
      onTap: onTap,
      child: Container(
        // 20 no cae exacto en la escala de `AppEspaciado` (16/24 son los
        // vecinos más cercanos); se redondea a `lg` para no ensanchar la
        // tarjeta respecto al resto de la pantalla (tarea 032).
        padding: const EdgeInsets.all(AppEspaciado.lg),
        decoration: BoxDecoration(
          color: colorSuperficie(context),
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          border: Border.all(
            color: proximamente ? colorBorde(context) : AppColores.acento,
            width: 1.5,
          ),
          boxShadow: proximamente
              ? []
              : [
                  BoxShadow(
                    color: AppColores.acento.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: proximamente
                    ? colorBorde(context)
                    : AppColores.acento.withValues(alpha: 0.12),
                // Insignia de icono, no un campo/tarjeta/chip real: se
                // redondea al rol más cercano (`campo`, 12) en vez de dejar
                // el 10 suelto (mismo criterio que el checkbox de `AppTema`
                // en la tarea 031 — no todo literal necesita un rol nuevo).
                borderRadius: BorderRadius.circular(AppRadios.campo),
              ),
              child: Icon(
                icono,
                // Ícono informativo sobre el fondo con tinte dorado: mismo
                // contraste corregido que el resto (tarea 051).
                color: proximamente ? AppColores.grisMedio : colorAcentoTexto(context),
                size: 22,
              ),
            ),
            const SizedBox(width: AppEspaciado.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        titulo,
                        // Cabecera de tarjeta: exactamente el uso previsto
                        // de `subtitulo` en la tarea 031.
                        style: Theme.of(context).textTheme.subtitulo.copyWith(
                              color: proximamente
                                  ? AppColores.grisMedio
                                  : colorTextoFuerte(context),
                            ),
                      ),
                      if (proximamente) ...[
                        const SizedBox(width: AppEspaciado.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppEspaciado.sm,
                              vertical: AppEspaciado.xs),
                          decoration: BoxDecoration(
                            color: AppColores.grisClaro,
                            // Badge diminuto nativo, no un chip/pastilla
                            // (`AppRadios.chip` es para formas casi/del todo
                            // redondeadas): se deja literal, igual que el
                            // checkbox de `AppTema` (tarea 031).
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Pronto',
                            style: Theme.of(context)
                                .textTheme
                                .etiqueta
                                .copyWith(color: AppColores.grisMedio),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppEspaciado.xs),
                  Text(
                    descripcion,
                    style: Theme.of(context).textTheme.cuerpoChico.copyWith(
                          color: proximamente
                              ? AppColores.grisMedio
                              : colorTextoSuave(context),
                        ),
                  ),
                ],
              ),
            ),
            if (!proximamente)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: colorAcentoTexto(context)),
          ],
        ),
      ),
    );
  }
}
