/// Reglas que **el servidor impone** y que el formulario debe pedir igual.
///
/// No son preferencias de la app: son las validaciones reales del backend
/// (ADR-0010 para la contraseña, ADR-0011 para la edad). Si el formulario
/// pide menos, el usuario rellena los 5 pasos del registro para que el
/// servidor le responda 400 al final, que es exactamente la experiencia que
/// hay que evitar.
///
/// Verificadas contra el servidor el 2026-08-27 (tarea 020).
class ReglasCuenta {
  /// Mínimo del backend. Firebase pedía 6; el backend propio pide 10.
  static const int contrasenaMinima = 10;

  /// Máximo del backend: BCrypt trunca en 72 bytes, así que aceptar más daría
  /// una falsa sensación de fortaleza.
  static const int contrasenaMaxima = 72;

  /// Edad mínima. Antes solo la comprobaba la pantalla; ahora también el
  /// servidor, que responde 400 si no se cumple.
  static const int edadMinima = 18;
}
