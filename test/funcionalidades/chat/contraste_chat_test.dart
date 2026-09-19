import 'dart:math' as m;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/widgets/boton_primario.dart';
import 'package:trabajito/funcionalidades/chat/datos/chat.dart';
import 'package:trabajito/funcionalidades/chat/widgets/burbuja_mensaje.dart';
import 'package:trabajito/funcionalidades/chat/widgets/panel_negociacion.dart';
import 'package:trabajito/nucleo/tema/app_colores.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';
import 'package:trabajito/nucleo/tema/colores_por_tema.dart';

// Tarea 061: contraste WCAG AA (>= 4.5:1) en los sitios donde había texto
// blanco sobre dorado o texto dorado sobre claro.
double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : m.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contraste(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _app(ThemeData tema, Widget hijo) =>
    MaterialApp(theme: tema, home: Scaffold(body: Center(child: hijo)));

void main() {
  final temas = {'claro': AppTema.temaClaro(), 'oscuro': AppTema.temaOscuro()};
  for (final e in temas.entries) {
    group('tema ${e.key}', () {
      testWidgets('burbuja propia: texto oscuro sobre dorado >= 4.5',
          (t) async {
        await t.pumpWidget(_app(
            e.value,
            BurbujaMensaje(
                mensaje:
                    Mensaje(texto: 'hola', deUid: 'yo', fecha: DateTime(2026)),
                miUid: 'yo')));
        final txt = t.widget<Text>(find.text('hola'));
        final caja = t.widget<Container>(find
            .ancestor(of: find.text('hola'), matching: find.byType(Container))
            .first);
        final fondo = (caja.decoration as BoxDecoration).color!;
        expect(fondo, AppColores.acento);
        expect(contraste(txt.style!.color!, fondo), greaterThanOrEqualTo(4.5));
      });

      testWidgets('Contraproponer: texto colorAcentoTexto >= 4.5', (t) async {
        final chat = Chat(
          id: '1',
          idPublicacion: 'p',
          uidEmpleador: 'e',
          uidTrabajador: 'yo',
          fechaUltimoMensaje: DateTime(2026),
          pagoMonto: 100,
          pagoPropuestoPor: 'otro',
        );
        late BuildContext ctx;
        await t.pumpWidget(_app(
            e.value,
            Builder(builder: (c) {
              ctx = c;
              return PanelNegociacion(
                chat: chat,
                miUid: 'yo',
                esTrabajador: true,
                onProponerPago: () {},
                onAceptarPago: () {},
                onProponerTiempo: () {},
                onAceptarTiempo: () {},
              );
            })));
        final txt = t.widget<Text>(find.text('Contraproponer'));
        expect(txt.style!.color, colorAcentoTexto(ctx));
        final superficie = e.key == 'oscuro'
            ? AppColores.superficieOscura
            : AppColores.blanco;
        final fondo = Color.alphaBlend(
            AppColores.acento.withValues(alpha: 0.15), superficie);
        expect(contraste(txt.style!.color!, fondo), greaterThanOrEqualTo(4.5));
      });

      testWidgets('BotonPrimario dorado con colorTexto oscuro >= 4.5',
          (t) async {
        await t.pumpWidget(_app(
            e.value,
            BotonPrimario(
              texto: 'Calificar al trabajador',
              color: AppColores.dorado,
              colorTexto: AppColores.principal,
              onPressed: () {},
            )));
        final boton = t.widget<ElevatedButton>(find.byType(ElevatedButton));
        final fg = boton.style!.foregroundColor!.resolve(const {})!;
        final bg = boton.style!.backgroundColor!.resolve(const {})!;
        expect(bg, AppColores.dorado);
        expect(contraste(fg, bg), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
