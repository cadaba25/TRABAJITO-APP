import 'package:flutter/material.dart';
import '../utils/constantes.dart';

/// Símbolo de marca (monograma martillo + desarmador), teñible.
class LogoSimbolo extends StatelessWidget {
  final double size;
  final Color? color;
  const LogoSimbolo({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/simbolo_trabajito.png',
      height: size,
      width: size,
      color: color,
      colorBlendMode: color != null ? BlendMode.srcIn : null,
      fit: BoxFit.contain,
    );
  }
}

/// Insignia tipo ícono de aplicación: símbolo blanco sobre azul marino.
class LogoInsignia extends StatelessWidget {
  final double size;
  const LogoInsignia({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColores.principal,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      alignment: Alignment.center,
      child: LogoSimbolo(size: size * 0.58, color: AppColores.blanco),
    );
  }
}

/// Solo la palabra "Trabajito" (Sora) con la "t" dorada.
class LogoTextoSolo extends StatelessWidget {
  final double altura;
  final Color? color;
  const LogoTextoSolo({super.key, this.altura = 26, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColores.textoOscuro
            : AppColores.principal);
    return RichText(
      text: TextSpan(
        style: TextStyle(fontFamily: 'Sora',
          fontSize: altura,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: c,
        ),
        children: const [
          TextSpan(text: 'Trabaji'),
          TextSpan(text: 't', style: TextStyle(color: AppColores.dorado)),
          TextSpan(text: 'o'),
        ],
      ),
    );
  }
}

/// Logotipo horizontal: insignia + palabra "Trabajito" (Sora) con punto dorado.
class LogoTrabajito extends StatelessWidget {
  final double altura;
  final Color? colorTexto;
  const LogoTrabajito({super.key, this.altura = 40, this.colorTexto});

  @override
  Widget build(BuildContext context) {
    final color = colorTexto ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColores.textoOscuro
            : AppColores.principal);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoInsignia(size: altura),
        SizedBox(width: altura * 0.28),
        RichText(
          text: TextSpan(
            style: TextStyle(fontFamily: 'Sora',
              fontSize: altura * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: color,
            ),
            children: [
              const TextSpan(text: 'Trabaji'),
              const TextSpan(
                  text: 't',
                  style: TextStyle(color: AppColores.dorado)),
              const TextSpan(text: 'o'),
            ],
          ),
        ),
      ],
    );
  }
}
