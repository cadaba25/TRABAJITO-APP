// Tarea 027 B-2b: `InfoPersonalPerfil` salió de `perfil_tab.dart`. Ramas de
// presentación: empleador (Empresa/Actividad) vs. trabajador
// (Profesional/Habilidades) y el CV sin cargar, que NO se pinta a cero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/compartido/modelos/usuario.dart';
import 'package:trabajito/funcionalidades/perfil/pantallas/widgets/info_personal_perfil.dart';
import 'package:trabajito/nucleo/textos/app_textos.dart';

Usuario desde(Map<String, dynamic> extra) => Usuario.desdeJson({
      'id': 'u1',
      'correo': 'x@trabajito.test',
      'nombres': 'Ana',
      'apellidos': 'Pérez',
      'rol': 'TRABAJADOR',
      ...extra,
    });

Future<void> montar(WidgetTester tester, Usuario u) async {
  await tester.binding.setSurfaceSize(const Size(1000, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ListView(children: [
        InfoPersonalPerfil(
            usuario: u, recargando: false, onReintentar: () {}),
      ]),
    ),
  ));
}

void main() {
  testWidgets('trabajador con CV: secciones Profesional y Habilidades',
      (tester) async {
    await montar(
        tester,
        desde({
          'habilidades': ['Plomería'],
          'experiencia': const <Map<String, dynamic>>[],
          'estudios': const <Map<String, dynamic>>[],
        }));

    expect(find.text('Profesional'), findsOneWidget);
    expect(find.text('Habilidades'), findsOneWidget);
    expect(find.text('Experiencias'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Empresa'), findsNothing);
  });

  testWidgets('trabajador sin CV cargado: aviso y sin contadores a cero',
      (tester) async {
    await montar(
        tester,
        desde({
          'habilidades': null,
          'experiencia': null,
          'estudios': null,
        }));

    expect(find.text('Experiencias'), findsNothing);
    expect(find.text(AppTextos.cvSinCargar), findsOneWidget);
  });

  testWidgets('empleador empresa: secciones Empresa y Actividad', (tester) async {
    await montar(
        tester,
        desde({
          'rol': 'EMPLEADOR',
          'tipoEmpleador': 'empresa',
          'nombreEmpresa': 'Constructora Sula',
          'sectorEmpresa': 'Construcción',
        }));

    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Sector'), findsOneWidget);
    expect(find.text('Trabajos publicados'), findsOneWidget);
    expect(find.text('Constructora Sula'), findsOneWidget);
    expect(find.text('Profesional'), findsNothing);
    expect(find.text('Habilidades'), findsNothing);
  });
}
