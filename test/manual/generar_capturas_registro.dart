// Generador de capturas de los 8 pasos de los registros (5 trabajador + 3
// empleador), en claro y oscuro, para el reporte de la tarea 033
// (ADR-0016). NO es un test de regresión: no hace ningún `expect`, solo
// renderiza cada widget de paso con datos de ejemplo y guarda un PNG real
// (vía `RenderRepaintBoundary.toImage`) en `docs/agent-reports/capturas/`.
//
// Por qué un widget test y no el emulador: hay una sesión ajena viva en el
// único emulador disponible (`emulator-5554`, ver
// `docs/agent-reports/033-*.md`) y las instrucciones de la tarea piden no
// instalar nada encima ni levantar un segundo emulador si se puede evitar.
// Los 8 pasos ya están extraídos a widgets sin estado propio (ADR-0014,
// tarea 033), así que renderizarlos aislados con datos de ejemplo prueba
// exactamente lo que hay que probar: que los tokens de ADR-0016 se ven bien
// en los dos temas.
//
// No se nombra `*_test.dart` a propósito: `flutter test` (sin argumentos)
// solo descubre `test/**_test.dart`, así que esto NO se ejecuta en la suite
// normal. Se invoca a mano:
//   flutter test test/manual/generar_capturas_registro.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:trabajito/nucleo/tema/app_tema.dart';
import 'package:trabajito/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_cuenta_trabajador.dart';
import 'package:trabajito/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_cv_trabajador.dart';
import 'package:trabajito/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_datos_personales_trabajador.dart';
import 'package:trabajito/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_estudios_trabajador.dart';
import 'package:trabajito/funcionalidades/autenticacion/pantallas/widgets/registro_trabajador/paso_experiencia_trabajador.dart';
import 'package:trabajito/funcionalidades/autenticacion/pantallas/widgets/registro_empleador/paso_contacto_empleador.dart';
import 'package:trabajito/funcionalidades/autenticacion/pantallas/widgets/registro_empleador/paso_cuenta_empleador.dart';
import 'package:trabajito/funcionalidades/autenticacion/pantallas/widgets/registro_empleador/paso_info_empresa_empleador.dart';

const _carpeta = 'docs/agent-reports/capturas';

Future<void> _capturar(
  WidgetTester tester, {
  required String nombre,
  required Widget paso,
  required bool oscuro,
}) async {
  final boundaryKey = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(420, 2400));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTema.temaClaro(),
      darkTheme: AppTema.temaOscuro(),
      themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
      home: RepaintBoundary(
        key: boundaryKey,
        child: Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: paso,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final imagen = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final sufijo = oscuro ? 'oscuro' : 'claro';
    final archivo = File('$_carpeta/033-$nombre-$sufijo.png');
    archivo.parent.createSync(recursive: true);
    archivo.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  // Sin esto, `flutter test` no carga ninguna fuente personalizada y pinta
  // el texto como bloques opacos (el sustituto de prueba de Flutter): las
  // capturas servirían para ver espaciado/color/contraste, pero no para leer
  // una sola palabra. Se carga `Sora` de verdad desde `assets/fonts/Sora.ttf`
  // para que el PNG final sea legible, igual que en un dispositivo real.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final cargador = FontLoader('Sora')
      ..addFont(rootBundle.load('assets/fonts/Sora.ttf'));
    await cargador.load();
  });

  testWidgets('captura los 8 pasos de los dos registros en claro y oscuro',
      (tester) async {
    // ── Trabajador ──────────────────────────────────────────
    final nombresCtrl = TextEditingController(text: 'Marta');
    final apellidosCtrl = TextEditingController(text: 'Contratista');
    final dniCtrl = TextEditingController(text: '0801199912345');
    final correoCtrl = TextEditingController(text: 'marta@trabajito.test');
    final contrasenaCtrl = TextEditingController(text: 'ClaveLarga2026');
    final confirmarCtrl = TextEditingController(text: 'ClaveLarga2026');
    final diaCtrl = TextEditingController(text: '15');
    final mesCtrl = TextEditingController(text: '03');
    final anioCtrl = TextEditingController(text: '1995');
    final telefonoCtrl = TextEditingController(text: '98765432');
    final telEmergCtrl = TextEditingController(text: '98765433');
    final cpCtrl = TextEditingController(text: '11101');
    final empresaCtrl = TextEditingController(text: 'Constructora Sula');
    final puestoCtrl = TextEditingController(text: 'Electricista');
    final habilidadesCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    final fInicioExpCtrl = TextEditingController(text: '01/2022');
    final fFinExpCtrl = TextEditingController();
    final centroCtrl = TextEditingController(text: 'INFOP');
    final fInicioEstCtrl = TextEditingController(text: '01/2015');
    final fFinEstCtrl = TextEditingController(text: '12/2018');

    final pasosTrabajador = <String, Widget Function()>{
      'trabajador-1-cuenta': () => PasoCuentaTrabajador(
            formKey: GlobalKey<FormState>(),
            nombresCtrl: nombresCtrl,
            apellidosCtrl: apellidosCtrl,
            dniCtrl: dniCtrl,
            correoCtrl: correoCtrl,
            contrasenaCtrl: contrasenaCtrl,
            confirmarCtrl: confirmarCtrl,
            terminosAceptados: true,
            alCambiarTerminos: (_) {},
            cargando: false,
            onAvanzar: () {},
          ),
      'trabajador-2-datos-personales': () => PasoDatosPersonalesTrabajador(
            formKey: GlobalKey<FormState>(),
            diaCtrl: diaCtrl,
            mesCtrl: mesCtrl,
            anioCtrl: anioCtrl,
            telefonoCtrl: telefonoCtrl,
            telEmergCtrl: telEmergCtrl,
            cpCtrl: cpCtrl,
            genero: 'Femenino',
            alCambiarGenero: (_) {},
            departamento: 'Francisco Morazán',
            alCambiarDepartamento: (_) {},
            ciudad: 'Tegucigalpa',
            alCambiarCiudad: (_) {},
            cargando: false,
            onAvanzar: () {},
          ),
      'trabajador-3-cv': () => PasoCvTrabajador(onAvanzar: () {}),
      'trabajador-4-experiencia': () => PasoExperienciaTrabajador(
            formKey: GlobalKey<FormState>(),
            habilidades: const ['Electricidad', 'Plomería'],
            trabajaActualmente: true,
            alCambiarTrabajaActualmente: (_) {},
            hasTrabajado: null,
            alCambiarHasTrabajado: (_) {},
            empresaCtrl: empresaCtrl,
            puestoCtrl: puestoCtrl,
            habilidadesCtrl: habilidadesCtrl,
            descripcionCtrl: descripcionCtrl,
            fInicioExpCtrl: fInicioExpCtrl,
            fFinExpCtrl: fFinExpCtrl,
            cargando: false,
            onAvanzar: () {},
          ),
      'trabajador-5-estudios': () => PasoEstudiosTrabajador(
            formKey: GlobalKey<FormState>(),
            tieneEstudios: true,
            alCambiarTieneEstudios: (_) {},
            nivelEstudio: 'Técnico',
            alCambiarNivel: (_) {},
            centroCtrl: centroCtrl,
            fInicioEstCtrl: fInicioEstCtrl,
            fFinEstCtrl: fFinEstCtrl,
            cursandoActualmente: false,
            alCambiarCursando: (_) {},
            cargando: false,
            onFinalizar: () {},
          ),
    };

    // ── Empleador ───────────────────────────────────────────
    final nombreEmpresaCtrl = TextEditingController(text: 'Constructora Sula');
    final rtnCtrl = TextEditingController(text: '08011985123456');
    final cargoCtrl = TextEditingController(text: 'Gerente');
    final sitioWebCtrl = TextEditingController(text: 'www.constructorasula.hn');
    final descripcionEmpresaCtrl = TextEditingController();

    final pasosEmpleador = <String, Widget Function()>{
      'empleador-1-cuenta': () => PasoCuentaEmpleador(
            formKey: GlobalKey<FormState>(),
            esEmpresa: true,
            alCambiarTipo: (_) {},
            nombreEmpresaCtrl: nombreEmpresaCtrl,
            rtnCtrl: rtnCtrl,
            cargoCtrl: cargoCtrl,
            nombresCtrl: nombresCtrl,
            apellidosCtrl: apellidosCtrl,
            dniCtrl: dniCtrl,
            correoCtrl: correoCtrl,
            contrasenaCtrl: contrasenaCtrl,
            confirmarCtrl: confirmarCtrl,
            terminosAceptados: true,
            alCambiarTerminos: (_) {},
            cargando: false,
            onAvanzar: () {},
          ),
      'empleador-2-contacto': () => PasoContactoEmpleador(
            formKey: GlobalKey<FormState>(),
            esEmpresa: true,
            diaCtrl: diaCtrl,
            mesCtrl: mesCtrl,
            anioCtrl: anioCtrl,
            telefonoCtrl: telefonoCtrl,
            telAltCtrl: telEmergCtrl,
            cpCtrl: cpCtrl,
            departamento: 'Cortés',
            alCambiarDepartamento: (_) {},
            ciudad: 'San Pedro Sula',
            alCambiarCiudad: (_) {},
            cargando: false,
            onAvanzar: () {},
          ),
      'empleador-3-info-empresa': () => PasoInfoEmpresaEmpleador(
            formKey: GlobalKey<FormState>(),
            sectorEmpresa: 'Construcción y remodelación',
            alCambiarSector: (_) {},
            tamanoEmpresa: '11 - 50 empleados',
            alCambiarTamano: (_) {},
            sitioWebCtrl: sitioWebCtrl,
            descripcionCtrl: descripcionEmpresaCtrl,
            cargando: false,
            onFinalizar: () {},
          ),
    };

    for (final oscuro in [false, true]) {
      for (final entrada in pasosTrabajador.entries) {
        await _capturar(tester, nombre: entrada.key, paso: entrada.value(), oscuro: oscuro);
      }
      for (final entrada in pasosEmpleador.entries) {
        await _capturar(tester, nombre: entrada.key, paso: entrada.value(), oscuro: oscuro);
      }
    }
  });
}
