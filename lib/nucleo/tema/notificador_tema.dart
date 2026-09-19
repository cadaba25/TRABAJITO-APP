import 'package:flutter/foundation.dart';

/// Notificador global del modo de tema (false = claro, true = oscuro).
///
/// **Esto no es una constante: es estado compartido de toda la app**, y por eso
/// vive en su propio archivo en vez de escondido entre los colores. Lo escriben
/// el interruptor de `ConfiguracionScreen`, el botón de tema de `InicioScreen`
/// y el de `LoginScreen`; lo escucha `TrabajitApp` para elegir entre
/// `AppTema.temaClaro()` y `AppTema.temaOscuro()`.
///
/// No se registra en `provider` a propósito: es un `ValueNotifier` único, sin
/// dependencias, que ya funciona y no necesita sustituirse en ningún test. Si
/// algún día hay que persistirlo o burlarlo, ese es el momento de inyectarlo.
final ValueNotifier<bool> notificadorTema = ValueNotifier<bool>(false);
