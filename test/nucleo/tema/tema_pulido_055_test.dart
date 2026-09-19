import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';

void main() {
  for (final entrada in {'claro': AppTema.temaClaro(), 'oscuro': AppTema.temaOscuro()}.entries) {
    test('tema ${entrada.key}: snackbars flotantes con esquinas redondeadas', () {
      final st = entrada.value.snackBarTheme;
      expect(st.behavior, SnackBarBehavior.floating);
      expect(st.shape, isA<RoundedRectangleBorder>());
    });
  }
}
