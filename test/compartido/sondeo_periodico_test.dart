// Tarea 053: SondeoPeriodico (ADR-0018). Timer cancelable, sin solapes y
// pausado cuando la app pasa a segundo plano.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/sondeo/sondeo_periodico.dart';

void main() {
  testWidgets('repite cada intervalo y detener cancela el Timer',
      (tester) async {
    var tics = 0;
    final s = SondeoPeriodico(
        cada: const Duration(seconds: 3), tarea: () async => tics++)
      ..iniciar();
    expect(s.corriendo, isTrue);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(tics, 2);

    s.detener();
    expect(s.corriendo, isFalse);
    await tester.pump(const Duration(seconds: 30));
    expect(tics, 2);
  });

  testWidgets('no solapa: un tic se salta si el anterior sigue en vuelo',
      (tester) async {
    var entradas = 0;
    final lento = Completer<void>();
    final s = SondeoPeriodico(
      cada: const Duration(seconds: 1),
      tarea: () {
        entradas++;
        return lento.future;
      },
    )..iniciar();

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(entradas, 1);

    lento.complete();
    await tester.pump(const Duration(seconds: 1));
    expect(entradas, 2);
    s.detener();
  });

  testWidgets('en segundo plano se pausa y al volver ejecuta al instante',
      (tester) async {
    var tics = 0;
    final s = SondeoPeriodico(
        cada: const Duration(seconds: 3), tarea: () async => tics++)
      ..iniciar();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(s.corriendo, isFalse);
    await tester.pump(const Duration(seconds: 30));
    expect(tics, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(s.corriendo, isTrue);
    expect(tics, 1); // tic inmediato al volver

    await tester.pump(const Duration(seconds: 3));
    expect(tics, 2);
    s.detener();
  });

  testWidgets('un tic que lanza no mata el sondeo', (tester) async {
    var tics = 0;
    final s = SondeoPeriodico(
      cada: const Duration(seconds: 1),
      tarea: () async {
        tics++;
        throw StateError('boom');
      },
    )..iniciar();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tics, 2);
    s.detener();
  });
}
