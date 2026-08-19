// El test de arranque real de la app (que decide entre LoginScreen e
// InicioScreen según el estado de auth) vive en
// `test/pantalla_inicial_test.dart`, junto con la explicación de por qué se
// necesita mockear el `FirebaseAuthPlatform` para poder probarlo sin
// Firebase real.
//
// Este archivo, originalmente el smoke test por defecto del template de
// Flutter (referenciaba una clase `MyApp` que nunca existió en este
// proyecto), se deja como una comprobación mínima e independiente: que el
// paquete de la app se llama `trabajito` y que `TrabajitApp` (la clase raíz
// real, en lib/main.dart) es importable y es un `StatelessWidget`. No monta
// el widget aquí para no duplicar el setup de mocks de Firebase.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trabajito/main.dart';

void main() {
  test('TrabajitApp es la clase raíz de la app y es un StatelessWidget', () {
    const app = TrabajitApp();
    expect(app, isA<StatelessWidget>());
  });
}
