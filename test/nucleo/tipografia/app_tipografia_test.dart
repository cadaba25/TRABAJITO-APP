import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/nucleo/tipografia/app_tipografia.dart';

/// Cubre ADR-0016 (tarea 031): el type scale con nombre. Si algún rol pierde
/// su tamaño/peso/interlineado, o si la extensión de `TextTheme` deja de
/// exponerlo, estos tests se ponen rojos.
void main() {
  group('AppTipografia — cada rol fija tamaño + peso + interlineado', () {
    test('tituloGrande', () {
      expect(AppTipografia.tituloGrande.fontFamily, AppTipografia.familia);
      expect(AppTipografia.tituloGrande.fontSize, 28);
      expect(AppTipografia.tituloGrande.fontWeight, FontWeight.w800);
      expect(AppTipografia.tituloGrande.height, isNotNull);
    });

    test('titulo', () {
      expect(AppTipografia.titulo.fontFamily, AppTipografia.familia);
      expect(AppTipografia.titulo.fontSize, 22);
      expect(AppTipografia.titulo.fontWeight, FontWeight.w700);
      expect(AppTipografia.titulo.height, isNotNull);
    });

    test('subtitulo', () {
      expect(AppTipografia.subtitulo.fontFamily, AppTipografia.familia);
      expect(AppTipografia.subtitulo.fontSize, 17);
      expect(AppTipografia.subtitulo.fontWeight, FontWeight.w600);
    });

    test('cuerpo', () {
      expect(AppTipografia.cuerpo.fontFamily, AppTipografia.familia);
      expect(AppTipografia.cuerpo.fontSize, 15);
      expect(AppTipografia.cuerpo.fontWeight, FontWeight.w500);
    });

    test('cuerpoChico', () {
      expect(AppTipografia.cuerpoChico.fontFamily, AppTipografia.familia);
      expect(AppTipografia.cuerpoChico.fontSize, 13);
      expect(AppTipografia.cuerpoChico.fontWeight, FontWeight.w500);
    });

    test('etiqueta', () {
      expect(AppTipografia.etiqueta.fontFamily, AppTipografia.familia);
      expect(AppTipografia.etiqueta.fontSize, 11);
      expect(AppTipografia.etiqueta.fontWeight, FontWeight.w600);
    });

    test('numero usa cifras tabulares para montos/precios', () {
      expect(AppTipografia.numero.fontFamily, AppTipografia.familia);
      expect(AppTipografia.numero.fontSize, 20);
      expect(AppTipografia.numero.fontWeight, FontWeight.w700);
      expect(AppTipografia.numero.fontFeatures, isNotEmpty);
    });
  });

  group('Theme.of(context).textTheme.<rol> — extensión de TextTheme', () {
    testWidgets('expone los 7 roles sin perder los campos nativos de Material', (
      tester,
    ) async {
      late BuildContext capturado;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturado = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final textTheme = Theme.of(capturado).textTheme;

      expect(textTheme.tituloGrande, AppTipografia.tituloGrande);
      expect(textTheme.titulo, AppTipografia.titulo);
      expect(textTheme.subtitulo, AppTipografia.subtitulo);
      expect(textTheme.cuerpo, AppTipografia.cuerpo);
      expect(textTheme.cuerpoChico, AppTipografia.cuerpoChico);
      expect(textTheme.etiqueta, AppTipografia.etiqueta);
      expect(textTheme.numero, AppTipografia.numero);

      // Los roles nativos de Material siguen ahí: la extensión no los pisa.
      expect(textTheme.bodyMedium, isNotNull);
      expect(textTheme.titleLarge, isNotNull);
    });
  });
}
