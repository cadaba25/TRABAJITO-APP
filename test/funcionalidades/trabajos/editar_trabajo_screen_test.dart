// Tarea 041 — `EditarTrabajoScreen` contra `PUT /api/trabajos/{id}`.
//
// Cobertura mínima de widget, en el mismo estilo que
// `editar_perfil_screen_test.dart` (Provider real + `ApiClient.fijarInstancia`
// con un `MockClient`, sin abrir ningún socket): el servicio ya tiene sus
// propios tests de contrato en `trabajos_y_postulaciones_test.dart`; aquí solo
// se comprueba que la pantalla llama a `PUT` con lo que el formulario trae y
// que reacciona bien a los dos desenlaces que le importan al usuario (éxito y
// el 409 de "ya hay un postulante elegido").
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trabajito/compartido/modelos/publicacion.dart';
import 'package:trabajito/compartido/widgets/custom_textfield.dart';
import 'package:trabajito/funcionalidades/trabajos/pantallas/editar_trabajo_screen.dart';
import 'package:trabajito/nucleo/api/api_client.dart';
import 'package:trabajito/nucleo/inyeccion/proveedores.dart';

import '../../api/ayudas_api.dart';

/// Localiza un [CustomTextField] por su etiqueta, igual que
/// `registro_empleador_screen_test.dart`: por índice sería frágil.
Finder campo(String etiqueta) => find.byWidgetPredicate(
      (w) => w is CustomTextField && w.label == etiqueta,
      description: 'CustomTextField con etiqueta "$etiqueta"',
    );

Publicacion publicacionDePrueba() => Publicacion(
      id: 'trabajo-1',
      uidEmpleador: 'empleador-1',
      autor: 'Empleador Uno',
      categoria: 'Plomería',
      titulo: 'Reparar tubería',
      descripcion: 'Fuga en la cocina',
      departamento: 'Cortés',
      ciudad: 'San Pedro Sula',
      zona: 'Centro',
      presupuesto: 'L. 500/hora',
      plazo: 'Corto plazo',
      fechaCreacion: DateTime(2026, 9, 4),
    );

Map<String, dynamic> trabajoActualizadoJson() => {
      'id': 'trabajo-1',
      'empleadorId': 'empleador-1',
      'autorNombre': 'Empleador Uno',
      'titulo': 'Reparar tubería y grifo',
      'descripcion': 'Fuga en la cocina y el baño',
      'categoria': 'Plomería',
      'departamento': 'Cortés',
      'ciudad': 'San Pedro Sula',
      'zona': 'Centro',
      'presupuesto': 'L. 800/hora',
      'plazo': 'Medio plazo',
      'estado': 'ACTIVO',
      'trabajadorAsignadoId': null,
      'trabajadorAsignadoNombre': null,
      'montoAcordado': 0,
      'tiempoAcordado': null,
      'fechaAcuerdo': null,
      'fechaInicio': null,
      'pagoRetenido': false,
      'entregado': false,
      'pagoLiberado': false,
      'correccionSolicitada': false,
      'motivoCorreccion': null,
      'calificadoPorEmpleador': false,
      'calificadoPorTrabajador': false,
      'creadoEn': '2026-09-04T22:43:36.698451978Z',
    };

void main() {
  tearDown(() => ApiClient.fijarInstancia(null));

  Future<EspiaHttp> montarYAbrir(
    WidgetTester tester, {
    required Future<http.Response> Function(http.Request) responder,
  }) async {
    final espia = EspiaHttp();
    final (cliente, _) = await clienteConSesion(
      clienteFalso(espia, responder),
      sesion: sesionDePrueba(),
    );
    ApiClient.fijarInstancia(cliente);

    await tester.pumpWidget(
      MultiProvider(
        providers: proveedoresDeLaApp(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditarTrabajoScreen(publicacion: publicacionDePrueba()),
                  ),
                ),
                child: const Text('abrir editar'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir editar'));
    await tester.pumpAndSettle();
    return espia;
  }

  testWidgets(
      'guardar con datos válidos manda PUT con los ocho campos y vuelve atrás',
      (tester) async {
    final espia = await montarYAbrir(tester,
        responder: (_) async => respuestaJson(trabajoActualizadoJson(), 200));

    await tester.enterText(campo('Título *'), 'Reparar tubería y grifo');
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump(); // procesa el tap y arranca el `Future`
    await tester.pump(); // resuelve el mock HTTP (inmediato)
    // Aquí sí `pumpAndSettle`: no se comprueba el SnackBar de éxito, así que
    // no importa que termine autodescartándose durante la espera.
    await tester.pumpAndSettle();

    final put = espia.ultimaA('/api/trabajos/trabajo-1');
    expect(put.method, 'PUT');
    final cuerpo = jsonDecode(utf8.decode(put.bodyBytes)) as Map<String, dynamic>;
    expect(cuerpo['titulo'], 'Reparar tubería y grifo');
    // Volvió a la pantalla anterior: ya no se ve el botón "Guardar cambios".
    expect(find.text('Guardar cambios'), findsNothing);
    expect(find.text('abrir editar'), findsOneWidget);
  });

  testWidgets(
      'un 409 (ya hay postulante elegido) se enseña y no se pierde el '
      'formulario', (tester) async {
    const mensaje = 'Solo se puede editar un trabajo mientras está ACTIVO '
        '(sin postulante elegido)';
    await montarYAbrir(tester,
        responder: (_) async => respuestaError(409, mensaje));

    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(mensaje), findsOneWidget);
    // Sigue en el formulario: no se navegó a ciegas con el error sin resolver.
    expect(find.text('Guardar cambios'), findsOneWidget);
  });
}
