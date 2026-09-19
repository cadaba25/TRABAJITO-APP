// Cobertura mínima de los cinco diálogos extraídos de
// `detalle_trabajo_screen.dart` en la tarea 035 (ADR-0016). No existía
// ningún test de estos diálogos antes de extraerlos (estaban embebidos en
// una pantalla sin tests de widget); se añade aquí porque ahora viven en su
// propio archivo y "cambios importantes requieren tests" (regla 8 de
// CLAUDE.md). Mismo patrón que otros diálogos/hojas de la app
// (`postularse_sheet.dart`, `hoja_filtros_trabajos.dart`): sin
// `pumpAndSettle` innecesario, un `MaterialApp` mínimo con un botón que abre
// el diálogo bajo prueba.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/dialogo_agregar_evidencia.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/dialogo_cancelar_contratacion.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/dialogo_confirmacion.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/dialogo_reclamar_problema.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/widgets/dialogo_solicitar_correccion.dart';

/// Monta un botón que, al pulsarlo, abre [abrir] y guarda lo que devuelve en
/// [resultado].
Widget _arnes<T>(Future<T?> Function(BuildContext) abrir, ValueNotifier<Object?> resultado) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            resultado.value = await abrir(context);
          },
          child: const Text('abrir'),
        ),
      ),
    ),
  );
}

void main() {
  group('mostrarDialogoConfirmacion', () {
    testWidgets('"Sí" devuelve true y "No" devuelve false', (tester) async {
      final resultado = ValueNotifier<Object?>(null);
      await tester.pumpWidget(_arnes(
          (c) => mostrarDialogoConfirmacion(c,
              titulo: '¿Rechazar este trabajo?', mensaje: 'mensaje'),
          resultado));

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('¿Rechazar este trabajo?'), findsOneWidget);
      await tester.tap(find.text('Sí'));
      await tester.pumpAndSettle();
      expect(resultado.value, true);

      resultado.value = null;
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(resultado.value, false);
    });
  });

  group('mostrarDialogoSolicitarCorreccion', () {
    testWidgets('Enviar devuelve el texto escrito; Cancelar devuelve null',
        (tester) async {
      final resultado = ValueNotifier<Object?>('sin usar');
      await tester.pumpWidget(_arnes(mostrarDialogoSolicitarCorreccion, resultado));

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Falta pintar el marco');
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(resultado.value, 'Falta pintar el marco');

      resultado.value = 'sin usar';
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(resultado.value, null);
    });
  });

  group('mostrarDialogoReclamarProblema', () {
    testWidgets('Enviar devuelve (motivo, descripcion); Cancelar devuelve null',
        (tester) async {
      final resultado = ValueNotifier<Object?>('sin usar');
      await tester.pumpWidget(_arnes(mostrarDialogoReclamarProblema, resultado));

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'No responde');
      await tester.enterText(campos.at(1), 'Lleva 3 días sin contestar');
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(resultado.value, ('No responde', 'Lleva 3 días sin contestar'));

      resultado.value = 'sin usar';
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(resultado.value, null);
    });

    testWidgets('permite enviar con el motivo vacío (la validación es de quien llama)',
        (tester) async {
      final resultado = ValueNotifier<Object?>('sin usar');
      await tester.pumpWidget(_arnes(mostrarDialogoReclamarProblema, resultado));

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(resultado.value, ('', ''));
    });
  });

  group('mostrarDialogoCancelarContratacion', () {
    testWidgets('las tres opciones devuelven true/false/null', (tester) async {
      final resultado = ValueNotifier<Object?>('sin usar');
      Future<bool?> abrir(BuildContext c) => mostrarDialogoCancelarContratacion(c,
          nombreTrabajador: 'Carlos Demo', hayEscrow: true);
      await tester.pumpWidget(_arnes(abrir, resultado));

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Carlos Demo'), findsOneWidget);
      expect(find.textContaining('reembolsa entero'), findsOneWidget);
      await tester.tap(find.text('Volver a publicarlo'));
      await tester.pumpAndSettle();
      expect(resultado.value, true);

      resultado.value = 'sin usar';
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrarlo'));
      await tester.pumpAndSettle();
      expect(resultado.value, false);

      resultado.value = 'sin usar';
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mejor no'));
      await tester.pumpAndSettle();
      expect(resultado.value, null);
    });

    testWidgets('sin escrow no menciona el reembolso', (tester) async {
      final resultado = ValueNotifier<Object?>(null);
      Future<bool?> abrir(BuildContext c) => mostrarDialogoCancelarContratacion(c,
          nombreTrabajador: 'Carlos Demo', hayEscrow: false);
      await tester.pumpWidget(_arnes(abrir, resultado));

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('reembolsa entero'), findsNothing);
    });
  });

  group('mostrarDialogoAgregarEvidencia', () {
    testWidgets('Publicar devuelve el texto; Cancelar devuelve null', (tester) async {
      final resultado = ValueNotifier<Object?>('sin usar');
      await tester.pumpWidget(_arnes(mostrarDialogoAgregarEvidencia, resultado));

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ya nivelé el terreno');
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(resultado.value, 'Ya nivelé el terreno');

      resultado.value = 'sin usar';
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(resultado.value, null);
    });
  });
}
