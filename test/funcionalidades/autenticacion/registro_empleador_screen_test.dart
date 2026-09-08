// Primer test de una pantalla que **no tenía ninguno**, y la prueba de que la
// inyección de dependencias de la tarea 027 (ADR-0014) sirve para algo.
//
// Hasta ahora `RegistroEmpleadorScreen` era intestable: la pantalla se
// fabricaba su servicio dentro (`final _authService = AuthService();`), así que
// para probarla había que levantar la capa HTTP entera y adivinar por las
// peticiones qué había hecho. Con `context.read<AuthService>()` basta un doble
// registrado con `provider`, y las afirmaciones son directas: *qué* se le pidió
// al servicio y *con qué datos*.
//
// Lo que se fija aquí no es cosmético. El registro de empleador es de los
// sitios con más lógica de guardado del proyecto y hasta hoy solo se había
// probado a mano (ver el snapshot del repo):
//
//  1. el paso 1 hace **dos** llamadas y en este orden — `registrar` crea la
//     cuenta y abre la sesión, y solo después `actualizarCampos` guarda lo que
//     `RegistroRequest` no admite (los campos de empresa);
//  2. si el registro falla, **no se manda el `PUT` de perfil**: seguiría a una
//     cuenta que no existe, y el usuario se queda en el paso 1 con su error;
//  3. sin aceptar los términos no se llama al servidor.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:trabajito/funcionalidades/autenticacion/datos/auth_service.dart';
import 'package:trabajito/funcionalidades/autenticacion/pantallas/registro_empleador_screen.dart';
import 'package:trabajito/models/usuario.dart';
import 'package:trabajito/nucleo/dominio/roles.dart';
import 'package:trabajito/nucleo/inyeccion/proveedores.dart';
import 'package:trabajito/nucleo/sesion/sesion_usuario.dart';
import 'package:trabajito/services/api/almacen_sesion.dart';
import 'package:trabajito/services/api/api_client.dart';
import 'package:trabajito/widgets/custom_textfield.dart';

import '../../api/ayudas_api.dart';

/// Doble de [AuthService] que **no habla con nadie**: anota lo que le piden y
/// devuelve lo que el test le diga.
///
/// Hereda del servicio de verdad en vez de implementar una interfaz porque no
/// hay ninguna: `AuthService` es una clase concreta y las pantallas dependen de
/// ella. Sobreescribir los dos métodos que usa el paso 1 basta, y de paso el
/// test se rompería si alguien cambiara sus firmas.
///
/// El `ApiClient` que recibe es de mentira **por seguridad, no por uso**: si
/// una futura versión de la pantalla llamara a un tercer método sin doblar,
/// aquí no se abre ningún socket ni se toca el almacén seguro del dispositivo,
/// que es donde vive el refresh token de verdad.
class AuthServiceFalso extends AuthService {
  AuthServiceFalso({this.errorAlRegistrar, this.errorAlActualizar})
      : super(
          cliente: ApiClient(
            clienteHttp: MockClient(
              (_) async => respuestaError(
                  500, 'ningún test de esta pantalla debería salir a la red'),
            ),
            almacen: AlmacenSesionEnMemoria(),
            urlBase: urlBaseDePrueba,
          ),
          sesion: SesionUsuario(),
        );

  /// Si no es `null`, `registrar` falla con este mensaje.
  final String? errorAlRegistrar;

  /// Si no es `null`, `actualizarCampos` falla con este mensaje.
  final String? errorAlActualizar;

  final List<Usuario> registros = [];
  final List<String> contrasenas = [];
  final List<Map<String, dynamic>> actualizaciones = [];

  /// Orden real de las llamadas, para poder afirmar sobre la secuencia y no
  /// solo sobre los contadores.
  final List<String> llamadas = [];

  @override
  Future<String?> registrar({
    required Usuario datos,
    required String contrasena,
  }) async {
    llamadas.add('registrar');
    registros.add(datos);
    contrasenas.add(contrasena);
    return errorAlRegistrar;
  }

  @override
  Future<String?> actualizarCampos(Map<String, dynamic> campos) async {
    llamadas.add('actualizarCampos');
    actualizaciones.add(campos);
    return errorAlActualizar;
  }
}

/// Localiza un [CustomTextField] por su etiqueta. Por índice sería frágil: el
/// paso 1 enseña cuatro campos más si el empleador es una empresa.
Finder campo(String etiqueta) => find.byWidgetPredicate(
      (w) => w is CustomTextField && w.label == etiqueta,
      description: 'CustomTextField con etiqueta "$etiqueta"',
    );

/// Monta la pantalla con el servicio doblado, tal y como la monta la app: bajo
/// la raíz de composición.
Future<void> montarRegistro(WidgetTester tester, AuthServiceFalso falso) async {
  // El formulario del paso 1 es más alto que una pantalla normal y vive en un
  // `SingleChildScrollView`. `enterText` funciona igual con lo que queda fuera
  // de vista, pero `tap` no: exige que el widget sea alcanzable por el test de
  // impacto. Con un lienzo alto se evita tener que ir desplazando a mano.
  await tester.binding.setSurfaceSize(const Size(1000, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: proveedoresDeLaApp(auth: falso),
      child: const MaterialApp(home: RegistroEmpleadorScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Rellena el paso 1 con datos válidos de un empleador **persona** (el caso por
/// defecto) y acepta los términos.
Future<void> rellenarPaso1(WidgetTester tester) async {
  await tester.enterText(campo('Nombres *'), 'Marta');
  await tester.enterText(campo('Apellidos *'), 'Contratista');
  await tester.enterText(campo('DNI *'), '0801199912345');
  await tester.enterText(campo('Correo electrónico *'), 'marta@trabajito.test');
  await tester.enterText(campo('Contraseña *'), 'ClaveLarga2026');
  await tester.enterText(campo('Confirmar contraseña *'), 'ClaveLarga2026');
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'el paso 1 registra con el servicio inyectado y luego guarda el tipo de '
    'empleador, en ese orden',
    (tester) async {
      final falso = AuthServiceFalso();
      await montarRegistro(tester, falso);
      await rellenarPaso1(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      // 1. Se creó la cuenta con lo que el usuario escribió.
      expect(falso.registros, hasLength(1));
      final enviado = falso.registros.single;
      expect(enviado.correo, 'marta@trabajito.test');
      expect(enviado.nombres, 'Marta');
      expect(enviado.apellidos, 'Contratista');
      expect(enviado.dni, '0801199912345');
      expect(enviado.rol, ValoresDefecto.rolEmpleador,
          reason: 'esta pantalla solo puede crear empleadores');
      expect(enviado.uid, '',
          reason: 'el uid lo asigna el servidor, no la pantalla');
      expect(falso.contrasenas.single, 'ClaveLarga2026');

      // 2. Y solo DESPUÉS se guardó lo que el registro del backend no admite.
      expect(falso.llamadas, ['registrar', 'actualizarCampos'],
          reason: 'el PUT de perfil necesita la sesión que abre el registro');
      expect(falso.actualizaciones.single, {
        'tipoEmpleador': 'persona',
        'nombreEmpresa': '',
        'rtn': '',
        'cargoContacto': '',
      });

      // 3. Y se avanzó de paso.
      expect(find.text('Datos de contacto'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Crear cuenta'), findsNothing);
    },
  );

  testWidgets(
    'si el registro falla no se manda el perfil y el usuario se queda en el '
    'paso 1 con el mensaje del servidor',
    (tester) async {
      const mensaje = 'Este correo ya está registrado.';
      final falso = AuthServiceFalso(errorAlRegistrar: mensaje);
      await montarRegistro(tester, falso);
      await rellenarPaso1(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
      await tester.pump(); // lanza la petición
      await tester.pump(const Duration(milliseconds: 300)); // aparece el aviso

      expect(falso.llamadas, ['registrar'],
          reason: 'actualizar el perfil de una cuenta que no se creó le '
              'guardaría los datos a otra persona o daría un 401');
      expect(find.text(mensaje), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Crear cuenta'), findsOneWidget,
          reason: 'sin cuenta no se avanza de paso');
      expect(find.text('Datos de contacto'), findsNothing);
    },
  );

  testWidgets(
    'sin aceptar los términos no se llama al servidor',
    (tester) async {
      final falso = AuthServiceFalso();
      await montarRegistro(tester, falso);
      await rellenarPaso1(tester);
      // Se desmarca la casilla que `rellenarPaso1` había marcado.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(falso.llamadas, isEmpty);
      expect(find.text('Debes aceptar los términos y condiciones'),
          findsOneWidget);
    },
  );

  testWidgets(
    'elegir "Empresa" manda el nombre, el RTN y el cargo de contacto',
    (tester) async {
      final falso = AuthServiceFalso();
      await montarRegistro(tester, falso);

      await tester.tap(find.text('Empresa'));
      await tester.pumpAndSettle();

      await tester.enterText(
          campo('Nombre de la empresa *'), 'Constructora Sula');
      await tester.enterText(campo('RTN (opcional)'), '08011985123456');
      await tester.enterText(
          campo('Cargo en la empresa (opcional)'), 'Gerente');
      await rellenarPaso1(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(falso.actualizaciones.single, {
        'tipoEmpleador': 'empresa',
        'nombreEmpresa': 'Constructora Sula',
        'rtn': '08011985123456',
        'cargoContacto': 'Gerente',
      });
    },
  );
}
