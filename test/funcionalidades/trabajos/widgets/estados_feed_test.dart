// Tarea 027 B-2b: los estados del feed (`EstadoErrorFeed`, `EstadoVacioFeed`)
// salieron de `trabajos_tab.dart` sin ningún test que los cubriera. Lo que hay
// que fijar es que NO se confunda "no pude leer" con "no hay nada" —la mejora
// concreta de la migración a HTTP frente a Firestore (reporte 026)— y que el
// vacío hable distinto al empleador y al trabajador.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/nucleo/api/api_excepciones.dart';
import 'package:trabajito/nucleo/textos/mensajes_error.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/estados_feed.dart';

Future<void> montar(WidgetTester tester, Widget hijo) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: hijo)),
  ));
}

void main() {
  testWidgets('EstadoErrorFeed enseña el mensaje del backend y "reintentar"',
      (tester) async {
    await montar(
      tester,
      const EstadoErrorFeed(
        error: ErrorHttp('El servidor está en mantenimiento', estado: 503),
        oscuro: false,
      ),
    );

    expect(find.text('El servidor está en mantenimiento'), findsOneWidget);
    expect(find.textContaining('reintentar'), findsOneWidget);
    // Nunca debe caer en el texto del estado vacío.
    expect(find.textContaining('Aún no hay'), findsNothing);
  });

  testWidgets('EstadoErrorFeed con un error genérico usa el texto por defecto',
      (tester) async {
    await montar(
      tester,
      const EstadoErrorFeed(error: 'algo raro', oscuro: false),
    );

    expect(find.text(MensajesError.errorGeneral), findsOneWidget);
  });

  testWidgets('EstadoVacioFeed le habla distinto al empleador y al trabajador',
      (tester) async {
    await montar(tester,
        const EstadoVacioFeed(oscuro: false, esEmpleador: true));
    expect(find.textContaining('Publica el primer trabajo'), findsOneWidget);

    await montar(tester,
        const EstadoVacioFeed(oscuro: false, esEmpleador: false));
    expect(find.textContaining('Vuelve pronto'), findsOneWidget);
    expect(find.textContaining('Publica el primer trabajo'), findsNothing);
  });
}
