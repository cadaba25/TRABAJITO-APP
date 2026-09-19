// Tarea 027 B-2b: `FormularioEditarPerfil` salió de `editar_perfil_screen.dart`.
// La rama de presentación no trivial es empleador vs. trabajador: el empleador
// ve "Sitio web" y "Descripción de la empresa"; el trabajador ve las
// habilidades y el botón de CV. El resto (guardado, carga del perfil) lo cubre
// `editar_perfil_screen_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/funcionalidades/perfil/pantallas/widgets/formulario_editar_perfil.dart';

Future<void> montar(WidgetTester tester,
    {required bool esEmpleador, bool cargando = false}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FormularioEditarPerfil(
        iniciales: 'AB',
        esEmpleador: esEmpleador,
        cargando: cargando,
        telefonoCtrl: TextEditingController(),
        sitioWebCtrl: TextEditingController(),
        presentacionCtrl: TextEditingController(),
        habilidades: ['Plomería'],
        onGuardar: () {},
        onCambiarContrasena: () {},
        onProximamente: (_) {},
      ),
    ),
  ));
}

void main() {
  testWidgets('trabajador: habilidades y CV, sin sitio web', (tester) async {
    await montar(tester, esEmpleador: false);

    expect(find.text('Habilidades'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('Cambiar CV'), findsOneWidget);
    expect(find.text('Sitio web (opcional)'), findsNothing);
    expect(find.text('Presentación / sobre mí'), findsOneWidget);
  });

  testWidgets('empleador: sitio web y descripción de empresa, sin habilidades',
      (tester) async {
    await montar(tester, esEmpleador: true);

    expect(find.text('Sitio web (opcional)'), findsOneWidget);
    expect(find.text('Descripción de la empresa'), findsOneWidget);
    expect(find.text('Habilidades'), findsNothing);
    expect(find.text('Cambiar CV'), findsNothing);
  });

  testWidgets('mientras carga, "Guardar cambios" queda desactivado',
      (tester) async {
    await montar(tester, esEmpleador: false, cargando: true);

    final boton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).first,
    );
    expect(boton.onPressed, isNull);
  });
}
