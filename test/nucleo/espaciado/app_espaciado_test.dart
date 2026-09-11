import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/nucleo/espaciado/app_espaciado.dart';

/// Cubre ADR-0016 (tarea 031): la escala de espaciado y los roles de radio.
/// Fija los valores exactos para que un cambio accidental (p. ej. alguien
/// "ajustando a ojo" un valor) se note aquí antes que en una pantalla.
void main() {
  group('AppEspaciado', () {
    test('escala con nombre en progresión creciente', () {
      expect(AppEspaciado.xs, 4);
      expect(AppEspaciado.sm, 8);
      expect(AppEspaciado.md, 12);
      expect(AppEspaciado.lg, 16);
      expect(AppEspaciado.xl, 24);
      expect(AppEspaciado.xxl, 32);

      expect(AppEspaciado.xs, lessThan(AppEspaciado.sm));
      expect(AppEspaciado.sm, lessThan(AppEspaciado.md));
      expect(AppEspaciado.md, lessThan(AppEspaciado.lg));
      expect(AppEspaciado.lg, lessThan(AppEspaciado.xl));
      expect(AppEspaciado.xl, lessThan(AppEspaciado.xxl));
    });
  });

  group('AppRadios', () {
    test('los 3 roles consolidan los 10 valores sueltos de la auditoría', () {
      expect(AppRadios.campo, 12);
      expect(AppRadios.tarjeta, 16);
      expect(AppRadios.chip, 20);
    });
  });
}
